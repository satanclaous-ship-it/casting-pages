/* ══════════════════════════════════════════════════════════════
   30분 기록 — push scheduler (Cloudflare Worker)

   A Cron Trigger wakes this every minute, looks at each stored
   subscription's own schedule in its own timezone, and sends a Web
   Push for any block boundary that just landed. That's the layer
   that survives the browser being fully closed — including iOS,
   where an installed PWA (16.4+) gets a real system notification.

   Endpoints
     GET  /vapid        → { publicKey }
     POST /subscribe    → store a PushSubscription + its schedule
     POST /unsubscribe  → drop it
     POST /test         → send one push right now

   Crypto is RFC 8291 (aes128gcm) + RFC 8292 (VAPID), done with
   WebCrypto only — no dependencies.
   ══════════════════════════════════════════════════════════════ */

const enc = new TextEncoder();

/* ── base64url ─────────────────────────────────────────────── */
const b64uDecode = (s) => {
  const b = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
};
const b64uEncode = (buf) => {
  let s = '';
  for (const b of new Uint8Array(buf)) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const cat = (...arrs) => {
  const out = new Uint8Array(arrs.reduce((a, b) => a + b.length, 0));
  let o = 0;
  for (const a of arrs) { out.set(a, o); o += a.length; }
  return out;
};

/* ── VAPID (RFC 8292) ──────────────────────────────────────── */

async function vapidHeader(endpoint, env) {
  const aud = new URL(endpoint).origin;
  const header = b64uEncode(enc.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const body = b64uEncode(enc.encode(JSON.stringify({
    aud,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: env.VAPID_SUBJECT || 'mailto:admin@example.com',
  })));
  const signingInput = enc.encode(`${header}.${body}`);

  // The private key is the raw 32-byte d value; rebuild a JWK around it.
  const pub = b64uDecode(env.VAPID_PUBLIC_KEY);   // 65 bytes, uncompressed 0x04||X||Y
  const jwk = {
    kty: 'EC', crv: 'P-256', ext: true,
    d: env.VAPID_PRIVATE_KEY,
    x: b64uEncode(pub.slice(1, 33)),
    y: b64uEncode(pub.slice(33, 65)),
  };
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, signingInput);
  return `vapid t=${header}.${body}.${b64uEncode(sig)}, k=${env.VAPID_PUBLIC_KEY}`;
}

/* ── payload encryption (RFC 8291, aes128gcm) ──────────────── */

async function hkdf(ikm, salt, info, len) {
  const key = await crypto.subtle.importKey('raw', ikm, 'HKDF', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt, info }, key, len * 8);
  return new Uint8Array(bits);
}

async function encryptPayload(text, uaPublicB64, authB64) {
  const uaPublic = b64uDecode(uaPublicB64);   // 65 bytes
  const authSecret = b64uDecode(authB64);     // 16 bytes

  // ephemeral sender keypair, fresh for every message
  const as = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const asPublic = new Uint8Array(await crypto.subtle.exportKey('raw', as.publicKey));

  const uaKey = await crypto.subtle.importKey('raw', uaPublic, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, as.privateKey, 256));

  // IKM = HKDF(ecdh, salt=auth_secret, info="WebPush: info\0"||ua_pub||as_pub)
  const keyInfo = cat(enc.encode('WebPush: info'), new Uint8Array([0]), uaPublic, asPublic);
  const ikm = await hkdf(ecdh, authSecret, keyInfo, 32);

  const salt = crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(ikm, salt, cat(enc.encode('Content-Encoding: aes128gcm'), new Uint8Array([0])), 16);
  const nonce = await hkdf(ikm, salt, cat(enc.encode('Content-Encoding: nonce'), new Uint8Array([0])), 12);

  const aesKey = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  // 0x02 is the last-record padding delimiter
  const plaintext = cat(enc.encode(text), new Uint8Array([2]));
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, aesKey, plaintext));

  // header: salt(16) | record_size(4, BE) | idlen(1) | as_public(65)
  const rs = new Uint8Array(4);
  new DataView(rs.buffer).setUint32(0, 4096);
  return cat(salt, rs, new Uint8Array([asPublic.length]), asPublic, ct);
}

async function sendPush(sub, payload, env) {
  const body = await encryptPayload(payload, sub.keys.p256dh, sub.keys.auth);
  const res = await fetch(sub.endpoint, {
    method: 'POST',
    headers: {
      'Content-Encoding': 'aes128gcm',
      'Content-Type': 'application/octet-stream',
      'Content-Length': String(body.length),
      TTL: '900',
      Urgency: 'high',
      Authorization: await vapidHeader(sub.endpoint, env),
    },
    body,
  });
  return res;
}

/* ── schedule logic ────────────────────────────────────────── */

const parseHM = (s) => { const [h, m] = String(s || '0:0').split(':').map(Number); return (h || 0) * 60 + (m || 0); };
const pad = (n) => String(n).padStart(2, '0');
const hhmm = (m) => { const x = ((m % 1440) + 1440) % 1440; return `${pad(Math.floor(x / 60))}:${pad(x % 60)}`; };

/** What (if anything) this subscription is owed at `nowUtcMin`. */
function dueFor(rec, nowUtcMin, utcDow) {
  const tz = Number(rec.tzOffset || 0);
  const localTotal = nowUtcMin + tz;
  const localMin = ((localTotal % 1440) + 1440) % 1440;
  const dayShift = Math.floor(localTotal / 1440);
  const dow = (((utcDow + dayShift) % 7) + 7) % 7;

  if (rec.weekend === false && (dow === 0 || dow === 6)) return null;

  if (localMin === parseHM(rec.reviewAt || '21:30')) {
    return { title: '🌙 하루 리뷰', body: '오늘 어디에 시간을 썼는지 5분만 돌아보기', action: 'review', slot: '' };
  }

  const iv = Number(rec.interval || 30);
  const s = parseHM(rec.dayStart || '08:00');
  let e = parseHM(rec.dayEnd || '23:00');
  if (e <= s) e += 1440;
  // pings ring at each block's END — you log the block that just finished
  for (let m = s; m + iv <= e + 0.001; m += iv) {
    const ring = ((m + iv) % 1440 + 1440) % 1440;
    if (ring === localMin) {
      return {
        title: `⏱ ${hhmm(m)}–${hhmm(m + iv)}`,
        body: '뭐 했어? 에너지·집중력·아이디어 기록하기',
        action: 'log',
        slot: String(m),
      };
    }
  }
  return null;
}

/* ── HTTP ──────────────────────────────────────────────────── */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'content-type',
};
const json = (o, status = 200) => new Response(JSON.stringify(o), {
  status, headers: { 'content-type': 'application/json', ...CORS },
});
const subKey = async (endpoint) => {
  const h = await crypto.subtle.digest('SHA-256', enc.encode(endpoint));
  return 'sub:' + b64uEncode(h).slice(0, 32);
};

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

    if (url.pathname === '/vapid') {
      return json({ publicKey: env.VAPID_PUBLIC_KEY });
    }

    if (url.pathname === '/subscribe' && req.method === 'POST') {
      const b = await req.json();
      if (!b?.subscription?.endpoint) return json({ error: 'no subscription' }, 400);
      const rec = {
        subscription: b.subscription,
        interval: b.interval ?? 30,
        dayStart: b.dayStart ?? '08:00',
        dayEnd: b.dayEnd ?? '23:00',
        reviewAt: b.reviewAt ?? '21:30',
        weekend: b.weekend !== false,
        tzOffset: b.tzOffset ?? 0,
        updatedAt: Date.now(),
      };
      await env.SUBS.put(await subKey(b.subscription.endpoint), JSON.stringify(rec));
      return json({ ok: true });
    }

    if (url.pathname === '/unsubscribe' && req.method === 'POST') {
      const b = await req.json();
      if (!b?.endpoint) return json({ error: 'no endpoint' }, 400);
      await env.SUBS.delete(await subKey(b.endpoint));
      return json({ ok: true });
    }

    if (url.pathname === '/test' && req.method === 'POST') {
      const b = await req.json();
      const raw = await env.SUBS.get(await subKey(b.endpoint || ''));
      if (!raw) return json({ error: 'unknown subscription' }, 404);
      const rec = JSON.parse(raw);
      const res = await sendPush(rec.subscription,
        JSON.stringify({ title: '⏱ 테스트 알람', body: '서버 푸시가 살아 있어요', action: 'log', slot: '' }), env);
      return json({ ok: res.ok, status: res.status });
    }

    return json({ name: '30min-tracker push scheduler', endpoints: ['/vapid', '/subscribe', '/unsubscribe', '/test'] });
  },

  async scheduled(event, env, ctx) {
    const now = new Date(event.scheduledTime);
    const nowUtcMin = now.getUTCHours() * 60 + now.getUTCMinutes();
    const dow = now.getUTCDay();

    let cursor;
    do {
      const page = await env.SUBS.list({ prefix: 'sub:', cursor });
      cursor = page.list_complete ? null : page.cursor;
      for (const k of page.keys) {
        const raw = await env.SUBS.get(k.name);
        if (!raw) continue;
        const rec = JSON.parse(raw);
        const due = dueFor(rec, nowUtcMin, dow);
        if (!due) continue;
        ctx.waitUntil((async () => {
          const res = await sendPush(rec.subscription, JSON.stringify(due), env);
          // 404/410 mean the browser threw the subscription away
          if (res.status === 404 || res.status === 410) await env.SUBS.delete(k.name);
        })());
      }
    } while (cursor);
  },
};
