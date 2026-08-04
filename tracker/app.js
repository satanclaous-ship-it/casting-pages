/* ══════════════════════════════════════════════════════════════
   30분 기록 — 시간·에너지 가계부
   Everything lives in localStorage; nothing leaves the device
   unless a push server is explicitly configured.
   ══════════════════════════════════════════════════════════════ */
'use strict';

/* ── 1. 상수 ───────────────────────────────────────────────── */

const CATS = [
  { k: 'deep',    n: '몰입 작업', v: '--c1' },
  { k: 'shallow', n: '잡무 처리', v: '--c2' },
  { k: 'comm',    n: '회의·소통', v: '--c3' },
  { k: 'learn',   n: '학습·인풋', v: '--c4' },
  { k: 'health',  n: '운동·건강', v: '--c5' },
  { k: 'rest',    n: '휴식·회복', v: '--c6' },
  { k: 'social',  n: '관계·사교', v: '--c7' },
  { k: 'waste',   n: '낭비·산만', v: '--c8' },
];
const CAT = Object.fromEntries(CATS.map((c) => [c.k, c]));

const ENERGY = ['방전', '낮음', '보통', '좋음', '최상'];
const FOCUS  = ['산만', '얕음', '보통', '깊음', '몰입'];
const IMPACT = ['낮음', '보통', '높음'];

const IDEA_STATUS = [
  { k: 'inbox',   n: '수집함',     d: '아직 분류 안 함' },
  { k: 'content', n: '콘텐츠감',   d: '글·영상으로 뽑을 것' },
  { k: 'bank',    n: '아이디어뱅크', d: '더 키워볼 것' },
  { k: 'vault',   n: '창고',       d: '일단 보관' },
  { k: 'dropped', n: '버림',       d: '' },
];

const DEFAULTS = {
  interval: 30,
  dayStart: '08:00',
  dayEnd: '23:00',
  reviewAt: '21:30',
  sound: true,
  weekend: true,
  pushUrl: '',
  theme: 'dark',
};

/* ── 2. 저장소 ─────────────────────────────────────────────── */

const K = { entries: 't30.entries', ideas: 't30.ideas', set: 't30.settings', rev: 't30.reviews', meta: 't30.meta' };

function load(key, fb) {
  try { const r = localStorage.getItem(key); return r ? JSON.parse(r) : structuredClone(fb); }
  catch { return structuredClone(fb); }
}
function save(key, val) {
  try { localStorage.setItem(key, JSON.stringify(val)); return true; }
  catch (e) { toast('저장 공간이 가득 찼어요. 설정에서 내보내기 후 정리해 주세요.'); return false; }
}

const DB = {
  entries: load(K.entries, {}),   // { 'YYYY-MM-DD': { '<minuteOffset>': entry } }
  ideas:   load(K.ideas, []),
  reviews: load(K.rev, {}),
  set:     Object.assign({}, DEFAULTS, load(K.set, {})),
};

const saveEntries = () => save(K.entries, DB.entries);
const saveIdeas   = () => save(K.ideas, DB.ideas);
const saveReviews = () => save(K.rev, DB.reviews);
const saveSet     = () => save(K.set, DB.set);

const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36);

/* ── 3. 시간 · 블록 계산 ───────────────────────────────────── */

const pad = (n) => String(n).padStart(2, '0');
const hhmm = (mins) => { const m = ((mins % 1440) + 1440) % 1440; return `${pad(Math.floor(m / 60))}:${pad(m % 60)}`; };
const parseHM = (s) => { const [h, m] = String(s || '0:0').split(':').map(Number); return (h || 0) * 60 + (m || 0); };
const dateKey = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const keyToDate = (k) => { const [y, m, d] = k.split('-').map(Number); return new Date(y, m - 1, d); };
const addDays = (k, n) => { const d = keyToDate(k); d.setDate(d.getDate() + n); return dateKey(d); };

/** The waking window. When it wraps past midnight, the small hours still
 *  belong to the day that started them — so a 2am block lands on yesterday. */
function span() {
  const s = parseHM(DB.set.dayStart);
  let e = parseHM(DB.set.dayEnd);
  const wraps = e <= s;
  if (wraps) e += 1440;
  return { s, e, wraps };
}

/** Minute offset from the logical day's midnight (can exceed 1440). */
function offsetOf(d = new Date()) {
  const { e, wraps } = span();
  const m = d.getHours() * 60 + d.getMinutes();
  return wraps && m < e - 1440 ? m + 1440 : m;
}
function logicalDay(d = new Date()) {
  const { e, wraps } = span();
  const m = d.getHours() * 60 + d.getMinutes();
  if (wraps && m < e - 1440) return addDays(dateKey(d), -1);
  return dateKey(d);
}
/** All block offsets for a logical day, e.g. [480, 510, 540, …]. */
function slotsOf() {
  const { s, e } = span();
  const iv = DB.set.interval;
  const out = [];
  for (let m = s; m + iv <= e + 0.001; m += iv) out.push(m);
  return out;
}
/** The block that contains `d`, clamped into the waking window. */
function currentSlot(d = new Date()) {
  const all = slotsOf();
  if (!all.length) return 0;
  const off = offsetOf(d);
  if (off < all[0]) return all[0];
  const last = all[all.length - 1];
  if (off >= last) return last;
  const iv = DB.set.interval;
  return all[0] + Math.floor((off - all[0]) / iv) * iv;
}
const isWeekend = (dk) => [0, 6].includes(keyToDate(dk).getDay());

const getEntry = (dk, off) => (DB.entries[dk] || {})[String(off)] || null;
function putEntry(dk, off, patch) {
  DB.entries[dk] = DB.entries[dk] || {};
  const prev = DB.entries[dk][String(off)] || {};
  DB.entries[dk][String(off)] = Object.assign({ createdAt: Date.now() }, prev, patch, { updatedAt: Date.now() });
  saveEntries();
}
const dayEntries = (dk) => Object.entries(DB.entries[dk] || {})
  .map(([off, e]) => Object.assign({ off: Number(off) }, e))
  .filter((e) => !e.skipped && e.act)
  .sort((a, b) => a.off - b.off);

/* ── 4. DOM 유틸 ───────────────────────────────────────────── */

const $  = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

let toastT;
function toast(msg, ms = 2200) {
  const el = $('#toast');
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(toastT);
  toastT = setTimeout(() => { el.hidden = true; }, ms);
}

function download(name, mime, text) {
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const a = document.createElement('a');
  a.href = url; a.download = name;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

/* ── 5. 알람 엔진 ──────────────────────────────────────────── */
/* Three independent layers, strongest first:
   L1 Notification Triggers — the OS fires it with the app fully closed.
   L2 Wall-clock ticker + SW notification — whenever a tab is alive.
   L3 .ics calendar alarms — OS-native, browser-independent (the iOS answer).
   L4 Web Push, if a Cloudflare Worker is configured.                       */

const Alarm = {
  reg: null,
  lastFired: null,
  audio: null,

  async init() {
    if ('serviceWorker' in navigator) {
      try {
        this.reg = await navigator.serviceWorker.register('./sw.js');
        navigator.serviceWorker.addEventListener('message', (e) => {
          if (e.data && e.data.type === 'open') routeAction(e.data.action, e.data.slot);
        });
      } catch { /* file:// or blocked — layers 2/3 still work */ }
    }
    this.tick();
    setInterval(() => this.tick(), 15000);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) this.tick(); });
    window.addEventListener('focus', () => this.tick());
    this.schedule();
  },

  get supportsTriggers() {
    return 'Notification' in window && 'showTrigger' in Notification.prototype;
  },

  due(now = new Date()) {
    const { s, e } = span();
    const off = offsetOf(now);
    if (off < s || off > e) return null;
    const dk = logicalDay(now);
    if (!DB.set.weekend && isWeekend(dk)) return null;
    const iv = DB.set.interval;
    // A block's alarm rings when the block *ends* — you log what just happened.
    const all = slotsOf();
    for (const sl of all) {
      const ring = sl + iv;
      if (off >= ring && off < ring + 2) return { dk, slot: sl };
    }
    return null;
  },

  tick() {
    updateClock();
    const now = new Date();
    const d = this.due(now);
    if (d) {
      const tag = `${d.dk}#${d.slot}`;
      if (this.lastFired !== tag && !getEntry(d.dk, d.slot)) {
        this.lastFired = tag;
        this.fire(`⏱ ${hhmm(d.slot)}–${hhmm(d.slot + DB.set.interval)}`, '뭐 했어? 에너지·집중력·아이디어 기록하기', d.slot);
      }
    }
    // evening review nudge, once per day
    const meta = load(K.meta, {});
    const dk = logicalDay(now);
    const rOff = parseHM(DB.set.reviewAt);
    if (offsetOf(now) >= rOff && offsetOf(now) < rOff + 3 && meta.reviewed !== dk) {
      meta.reviewed = dk; save(K.meta, meta);
      this.fire('🌙 하루 리뷰', '오늘 어디에 시간을 썼는지 5분만 돌아보기', null, 'review');
    }
    if (currentView === 'log') renderLog(false);
  },

  fire(title, body, slot, act = 'log') {
    if (DB.set.sound) this.chime();
    flashTitle(title);
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    const payload = { type: 'notify', title, body, slot: slot == null ? '' : String(slot), act, tag: `t30-${act}` };
    if (this.reg && this.reg.active) this.reg.active.postMessage(payload);
    else try { new Notification(title, { body, icon: './icon-192.png' }); } catch {}
  },

  /** Layer 1: hand the whole day's remaining pings to the OS scheduler. */
  async schedule() {
    if (!this.reg || !this.supportsTriggers || Notification.permission !== 'granted') return;
    try {
      for (const n of await this.reg.getNotifications({ includeTriggered: true })) {
        if ((n.tag || '').startsWith('t30-sched-')) n.close();
      }
      const now = Date.now();
      const iv = DB.set.interval;
      let n = 0;
      for (let dayAhead = 0; dayAhead < 3 && n < 40; dayAhead++) {
        const base = new Date(); base.setHours(0, 0, 0, 0); base.setDate(base.getDate() + dayAhead);
        const dk = dateKey(base);
        if (!DB.set.weekend && isWeekend(dk)) continue;
        for (const sl of slotsOf()) {
          const at = base.getTime() + (sl + iv) * 60000;
          if (at <= now + 60000 || n >= 40) continue;
          await this.reg.showNotification(`⏱ ${hhmm(sl)}–${hhmm(sl + iv)}`, {
            body: '뭐 했어? 에너지·집중력·아이디어 기록하기',
            tag: `t30-sched-${dk}-${sl}`,
            icon: './icon-192.png',
            badge: './icon-192.png',
            data: { slot: String(sl), action: 'log' },
            showTrigger: new window.TimestampTrigger(at),
          });
          n++;
        }
      }
    } catch { /* trigger API unavailable — layers 2–4 cover it */ }
  },

  chime() {
    try {
      const A = window.AudioContext || window.webkitAudioContext;
      if (!A) return;
      this.audio = this.audio || new A();
      if (this.audio.state === 'suspended') this.audio.resume();
      const t = this.audio.currentTime;
      [880, 1320].forEach((f, i) => {
        const o = this.audio.createOscillator(), g = this.audio.createGain();
        o.type = 'sine'; o.frequency.value = f;
        g.gain.setValueAtTime(0, t + i * 0.16);
        g.gain.linearRampToValueAtTime(0.18, t + i * 0.16 + 0.02);
        g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.16 + 0.32);
        o.connect(g); g.connect(this.audio.destination);
        o.start(t + i * 0.16); o.stop(t + i * 0.16 + 0.34);
      });
    } catch {}
  },

  /** Layer 3: one daily-repeating VEVENT per block, each with its own VALARM.
   *  FREQ=DAILY is universally supported; FREQ=MINUTELY is not. */
  ics() {
    const iv = DB.set.interval;
    const now = new Date();
    const stamp = `${now.getUTCFullYear()}${pad(now.getUTCMonth() + 1)}${pad(now.getUTCDate())}T${pad(now.getUTCHours())}${pad(now.getUTCMinutes())}${pad(now.getUTCSeconds())}Z`;
    const base = new Date(); base.setHours(0, 0, 0, 0);
    const ymd = `${base.getFullYear()}${pad(base.getMonth() + 1)}${pad(base.getDate())}`;
    const byday = DB.set.weekend ? '' : ';BYDAY=MO,TU,WE,TH,FR';
    const L = [
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//30min-tracker//KO//', 'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH', 'X-WR-CALNAME:30분 기록 알람', 'X-WR-TIMEZONE:Asia/Seoul',
    ];
    const ev = (mins, summary, desc, tag) => {
      const dayOff = Math.floor(mins / 1440);
      const d2 = new Date(base); d2.setDate(d2.getDate() + dayOff);
      const start = `${d2.getFullYear()}${pad(d2.getMonth() + 1)}${pad(d2.getDate())}T${pad(Math.floor((mins % 1440) / 60))}${pad(mins % 60)}00`;
      L.push(
        'BEGIN:VEVENT',
        `UID:t30-${tag}-${mins}@30min-tracker`,
        `DTSTAMP:${stamp}`,
        `DTSTART:${start}`,          // floating local time — follows you across timezones
        'DURATION:PT5M',
        `RRULE:FREQ=DAILY${byday}`,
        `SUMMARY:${summary}`,
        `DESCRIPTION:${desc}`,
        'TRANSP:TRANSPARENT',
        'BEGIN:VALARM', 'ACTION:DISPLAY', 'TRIGGER:PT0M', `DESCRIPTION:${summary}`, 'END:VALARM',
        'END:VEVENT'
      );
    };
    for (const sl of slotsOf()) {
      ev(sl + iv, `⏱ 30분 기록 — ${hhmm(sl)}~${hhmm(sl + iv)}`, '뭐 했나 · 에너지 · 집중력 · 아이디어', 'ping');
    }
    ev(parseHM(DB.set.reviewAt), '🌙 하루 리뷰', '오늘 어디에 시간을 썼는지 돌아보기', 'review');
    L.push('END:VCALENDAR');
    download('30min-alarms.ics', 'text/calendar;charset=utf-8', L.join('\r\n'));
    toast('내려받은 파일을 열면 캘린더에 알람이 등록돼요');
  },

  /** Layer 4: Web Push through a Cloudflare Worker. */
  async subscribePush() {
    const url = (DB.set.pushUrl || '').replace(/\/+$/, '');
    if (!url) return toast('먼저 Worker 주소를 넣어 주세요');
    if (!this.reg) return toast('서비스 워커를 쓸 수 없어요 (https 필요)');
    if (Notification.permission !== 'granted') {
      if (await Notification.requestPermission() !== 'granted') return toast('알림 권한이 필요해요');
    }
    try {
      const key = (await (await fetch(`${url}/vapid`)).json()).publicKey;
      const sub = await this.reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: b64url(key),
      });
      const r = await fetch(`${url}/subscribe`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          subscription: sub,
          interval: DB.set.interval,
          dayStart: DB.set.dayStart,
          dayEnd: DB.set.dayEnd,
          reviewAt: DB.set.reviewAt,
          weekend: DB.set.weekend,
          tzOffset: -new Date().getTimezoneOffset(),
        }),
      });
      toast(r.ok ? '푸시 구독 완료 — 앱을 꺼도 알람이 와요' : '구독 실패: ' + r.status);
      renderNotifStatus();
    } catch (e) {
      toast('구독 실패: ' + e.message);
    }
  },
};

function b64url(s) {
  const p = '='.repeat((4 - (s.length % 4)) % 4);
  const b = atob((s + p).replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
}

let titleT;
function flashTitle(msg) {
  clearInterval(titleT);
  const orig = '30분 기록';
  let on = true, n = 0;
  titleT = setInterval(() => {
    document.title = on ? `🔔 ${msg}` : orig;
    on = !on;
    if (++n > 20 || !document.hidden) { clearInterval(titleT); document.title = orig; }
  }, 900);
}

function updateClock() {
  const d = new Date();
  $('#clock').textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/* ── 6. 음성 입력 ──────────────────────────────────────────── */

const SR = window.SpeechRecognition || window.webkitSpeechRecognition;

function wireMic(btnSel, targetSel, hintSel) {
  const btn = $(btnSel), target = $(targetSel), hint = hintSel ? $(hintSel) : null;
  if (!btn) return;
  if (!SR) {
    btn.disabled = true;
    btn.title = '이 브라우저는 음성 인식을 지원하지 않아요';
    if (hint) hint.textContent = '음성 인식 미지원 — 키보드 마이크를 쓰세요';
    return;
  }
  let rec = null;
  btn.addEventListener('click', () => {
    if (rec) { rec.stop(); return; }
    rec = new SR();
    rec.lang = 'ko-KR';
    rec.interimResults = true;
    rec.continuous = true;
    const seed = target.value ? target.value.replace(/\s*$/, ' ') : '';
    rec.onstart = () => { btn.dataset.on = '1'; btn.textContent = '⏹ 듣는 중… 탭하면 끝'; };
    rec.onresult = (e) => {
      let txt = '';
      for (let i = 0; i < e.results.length; i++) txt += e.results[i][0].transcript;
      target.value = seed + txt;
      target.dispatchEvent(new Event('input', { bubbles: true }));
    };
    rec.onerror = (e) => {
      if (e.error === 'not-allowed') toast('마이크 권한을 허용해 주세요');
      else if (e.error !== 'aborted' && e.error !== 'no-speech') toast('음성 인식 오류: ' + e.error);
    };
    rec.onend = () => { btn.dataset.on = '0'; btn.textContent = '🎙 음성으로'; rec = null; };
    try { rec.start(); } catch { rec = null; }
  });
}

/* ── 7. 기록 화면 ──────────────────────────────────────────── */

let editSlot = null;   // minute offset being edited
let editDay = null;
const draft = { act: '', cat: '', energy: 0, focus: 0, impact: -1, note: '' };

function buildScale(sel, labels, field) {
  const el = $(sel);
  el.innerHTML = labels.map((l, i) =>
    `<button type="button" data-v="${i + 1}" aria-pressed="false"><b>${i + 1}</b><i>${l}</i></button>`).join('');
  el.addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    draft[field] = Number(b.dataset.v);
    paintScale(sel, draft[field]);
  });
}
const paintScale = (sel, v) => $$(`${sel} button`).forEach((b) => b.setAttribute('aria-pressed', String(Number(b.dataset.v) === v)));

function buildCats() {
  $('#catChips').innerHTML = CATS.map((c) =>
    `<button type="button" class="chip" data-k="${c.k}" aria-pressed="false" style="--dot:var(${c.v})"><span class="dot"></span>${esc(c.n)}</button>`).join('');
  $('#catChips').addEventListener('click', (e) => {
    const b = e.target.closest('.chip'); if (!b) return;
    draft.cat = draft.cat === b.dataset.k ? '' : b.dataset.k;
    paintCats();
  });
}
const paintCats = () => $$('#catChips .chip').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.k === draft.cat)));

/** Activities you actually use, most-recent-and-frequent first. */
function recentActs(limit = 8) {
  const seen = new Map();
  const days = Object.keys(DB.entries).sort().reverse().slice(0, 14);
  for (const dk of days) {
    for (const e of Object.values(DB.entries[dk] || {})) {
      if (!e.act) continue;
      const cur = seen.get(e.act) || { n: 0, cat: e.cat };
      cur.n++; cur.cat = cur.cat || e.cat;
      seen.set(e.act, cur);
    }
  }
  return Array.from(seen.entries()).sort((a, b) => b[1].n - a[1].n).slice(0, limit)
    .map(([act, v]) => ({ act, cat: v.cat }));
}

function loadDraft(dk, off) {
  editDay = dk; editSlot = off;
  const e = getEntry(dk, off);
  draft.act = e?.act || ''; draft.cat = e?.cat || '';
  draft.energy = e?.energy || 0; draft.focus = e?.focus || 0;
  draft.impact = e?.impact ?? -1; draft.note = e?.note || '';
  $('#fAct').value = draft.act;
  $('#fNote').value = draft.note;
  paintCats();
  paintScale('#sEnergy', draft.energy);
  paintScale('#sFocus', draft.focus);
  $$('#sImpact button').forEach((b) => b.setAttribute('aria-pressed', String(Number(b.dataset.v) === draft.impact)));
  renderLog();
}

function renderLog(full = true) {
  const nowSlot = currentSlot();
  const today = logicalDay();
  if (editSlot == null) { editSlot = nowSlot; editDay = today; }
  // changing the interval or the waking window redraws the grid — an
  // editSlot from the old grid would render a block that can't exist
  const grid = slotsOf();
  if (grid.length && !grid.includes(editSlot)) {
    editSlot = grid.reduce((best, s) => (Math.abs(s - editSlot) < Math.abs(best - editSlot) ? s : best), grid[0]);
  }

  const iv = DB.set.interval;
  $('#slotTime').innerHTML = `${hhmm(editSlot)}–${hhmm(editSlot + iv)} <small>${
    editDay === today && editSlot === nowSlot ? '지금 블록'
      : editDay !== today ? esc(editDay)
      : editSlot < nowSlot ? '지난 블록' : '앞으로'
  }</small>`;
  const saved = getEntry(editDay, editSlot);
  $('#saveEntry').textContent = saved && !saved.skipped ? '수정 저장' : '저장';

  // recently used activities
  const rec = recentActs();
  $('#recentWrap').hidden = rec.length === 0;
  if (rec.length) {
    $('#recentChips').innerHTML = rec.map((r) =>
      `<button type="button" class="chip" data-act="${esc(r.act)}" data-cat="${esc(r.cat || '')}" style="--dot:var(${CAT[r.cat]?.v || '--text-muted'})"><span class="dot"></span>${esc(r.act)}</button>`).join('');
  }

  if (!full) return renderToday();
  renderToday();
  renderCatchup();
}

/** Blocks worth going back for.
 *  Backfilling only makes sense from the moment the day actually started —
 *  greeting a fresh install with "you're 25 blocks behind" is just noise, and
 *  nobody reliably remembers past ~2 hours anyway. */
function renderCatchup() {
  const today = logicalDay();
  const now = offsetOf();
  const iv = DB.set.interval;
  const all = slotsOf();
  const past = all.filter((s) => s + iv <= now);
  const logged = past.filter((s) => getEntry(today, s));
  const RECALL = Math.max(2, Math.round(120 / iv));   // ~2h of believable recall

  const from = logged.length ? logged[0] : (past[Math.max(0, past.length - RECALL)] ?? null);
  const missed = from == null ? [] : past.filter((s) => s >= from && !getEntry(today, s));

  const box = $('#catchup');
  if (!missed.length) { box.innerHTML = ''; return; }
  const fresh = !logged.length;
  box.innerHTML = `<div class="insight" style="border-color:color-mix(in srgb,var(--warning) 45%,transparent)">
    <span class="k">⏳</span>
    <div style="flex:1">${fresh
      ? `아직 오늘 기록이 없어요. 방금 지나간 <b>${missed.length}개 블록</b>부터 채워 볼까요?`
      : `밀린 블록 <b>${missed.length}개</b> — 기억나는 만큼만 채워도 그래프는 살아나요.`}
    <div style="margin-top:8px"><button class="btn sm" id="fillOldest">${fresh ? '지금부터 시작하기' : '가장 오래된 것부터 채우기'}</button></div></div></div>`;
  $('#fillOldest').addEventListener('click', () => { loadDraft(today, missed[0]); window.scrollTo({ top: 0, behavior: 'smooth' }); });
}

function renderToday() {
  const dk = logicalDay();
  const iv = DB.set.interval;
  const now = offsetOf();
  const nowSlot = currentSlot();
  const all = slotsOf();
  const done = all.filter((s) => getEntry(dk, s)).length;
  const past = all.filter((s) => s + iv <= now).length;
  $('#todayCoverage').textContent = past ? `${done}/${past} 블록 기록됨` : '아직 시작 전';

  $('#todayList').innerHTML = all.map((s) => {
    const e = getEntry(dk, s);
    const isNow = s === nowSlot;
    const future = s > now;
    let cls = 'tl-item', body, meta = '';
    if (e && e.skipped) {
      cls += ' gap'; body = '<span class="act"><em>건너뜀</em></span>';
    } else if (e) {
      body = `<span class="act">${esc(e.act)}${e.impact === 2 ? '<span class="badge impact">임팩트</span>' : ''}${e.note ? '<span class="badge">노트</span>' : ''}</span>`;
      meta = `E${e.energy || '–'} · F${e.focus || '–'}`;
    } else {
      cls += ' gap';
      body = `<span class="act"><em>${future ? '—' : '비어 있음'}</em></span>`;
    }
    if (isNow) cls += ' now';
    const col = e && e.cat ? `var(${CAT[e.cat].v})` : 'var(--surface-3)';
    return `<button class="${cls}" data-slot="${s}" style="--cat:${col}">
      <span class="t">${hhmm(s)}</span><span class="bar"></span>${body}<span class="meta">${meta}</span></button>`;
  }).join('');
}

/* ── 8. 아이디어 ───────────────────────────────────────────── */

let ideaFilter = 'inbox';
let ideaQuery = '';

function addIdea(text, source = 'quick') {
  const t = (text || '').trim();
  if (!t) return null;
  const now = new Date();
  const idea = {
    id: uid(), text: t, status: 'inbox', source,
    day: logicalDay(now), slot: currentSlot(now), createdAt: Date.now(),
  };
  DB.ideas.unshift(idea);
  saveIdeas();
  return idea;
}

function renderIdeas() {
  const counts = Object.fromEntries(IDEA_STATUS.map((s) => [s.k, 0]));
  DB.ideas.forEach((i) => { counts[i.status] = (counts[i.status] || 0) + 1; });

  $('#ideaFilters').innerHTML = IDEA_STATUS.map((s) =>
    `<button type="button" class="chip" data-k="${s.k}" aria-pressed="${s.k === ideaFilter}">${esc(s.n)} ${counts[s.k] || 0}</button>`).join('');

  const q = ideaQuery.trim().toLowerCase();
  const list = DB.ideas
    .filter((i) => i.status === ideaFilter)
    .filter((i) => !q || i.text.toLowerCase().includes(q));

  if (!list.length) {
    const s = IDEA_STATUS.find((x) => x.k === ideaFilter);
    $('#ideaList').innerHTML = `<div class="empty">${esc(s.n)}에 아직 없어요.${s.d ? `<br><span style="opacity:.75">${esc(s.d)}</span>` : ''}</div>`;
    return;
  }

  $('#ideaList').innerHTML = list.map((i) => {
    const d = new Date(i.createdAt);
    const others = IDEA_STATUS.filter((s) => s.k !== i.status && s.k !== 'inbox');
    return `<div class="idea" data-id="${i.id}">
      <p>${esc(i.text)}</p>
      <div class="when">${esc(i.day)} ${hhmm(i.slot)} · ${pad(d.getHours())}:${pad(d.getMinutes())} 기록${i.source === 'ping' ? ' · 알람 중' : ''}</div>
      <div class="triage">
        ${others.map((s) => `<button class="btn sm ghost" data-to="${s.k}">${esc(s.n)}</button>`).join('')}
        ${i.status !== 'inbox' ? '<button class="btn sm ghost" data-to="inbox">수집함</button>' : ''}
        <button class="btn sm ghost" data-del="1" style="color:var(--text-muted)">삭제</button>
      </div>
    </div>`;
  }).join('');
}

/* ── 9. 차트 ───────────────────────────────────────────────── */
/* Inline SVG inherits CSS custom properties, so fills reference --c1…--c8
   directly and the whole dashboard re-themes with no redraw. */

const W = 720;
const hrs = (blocks) => (blocks * DB.set.interval) / 60;
const fmtH = (h) => (h >= 1 ? `${(Math.round(h * 10) / 10).toFixed(1)}h` : `${Math.round(h * 60)}m`);

function axisTimeTicks(s, e) {
  // one label every 2h, and never so many that they collide on a phone
  const out = [];
  const startH = Math.ceil(s / 60);
  const endH = Math.floor(e / 60);
  const step = endH - startH > 9 ? 2 : 1;
  for (let h = startH; h <= endH; h += step) out.push(h * 60);
  return out;
}
/** Ticks at the plot edges would hang half outside the viewBox and get
 *  clipped, so the outermost labels anchor inward instead of centering. */
function tickAnchor(x, lo, hi) {
  if (x - lo < 20) return 'start';
  if (hi - x < 20) return 'end';
  return 'middle';
}

/** Day timeline — one block per interval, colored by category.
 *  Identity never rides on color alone: legend + hover + table view. */
function chartDayBand(dk) {
  const { s, e } = span();
  const iv = DB.set.interval;
  const all = slotsOf();
  const H = 92, top = 10, bandH = 46, padL = 4, padR = 4;
  const innerW = W - padL - padR;
  const px = (m) => padL + ((m - s) / (e - s)) * innerW;
  const gap = 2;

  let marks = '';
  for (const sl of all) {
    const en = getEntry(dk, sl);
    const x = px(sl), w = Math.max(1, px(sl + iv) - x - gap);
    const filled = en && !en.skipped && en.act;
    // an unlogged block has to be *visible* as a hole, not blend into the card
    const fill = filled ? `var(${CAT[en.cat]?.v || '--text-muted'})` : 'var(--surface-3)';
    const label = filled
      ? `${hhmm(sl)}–${hhmm(sl + iv)}|${en.act}|${CAT[en.cat]?.n || '미분류'} · 에너지 ${en.energy || '–'} · 집중 ${en.focus || '–'}${en.impact === 2 ? ' · 임팩트' : ''}`
      : `${hhmm(sl)}–${hhmm(sl + iv)}|기록 없음|`;
    marks += `<rect class="hit" x="${x}" y="${top}" width="${w}" height="${bandH}" rx="3"
      fill="${fill}" data-tip="${esc(label)}"></rect>`;
    // impact gets a second, non-color channel
    if (filled && en.impact === 2) {
      marks += `<rect x="${x}" y="${top + bandH + 3}" width="${w}" height="3" rx="1.5" fill="var(--good)" pointer-events="none"></rect>`;
    }
  }

  const ticks = axisTimeTicks(s, e).map((m) =>
    `<line x1="${px(m)}" y1="${top + bandH + 9}" x2="${px(m)}" y2="${top + bandH + 13}" stroke="var(--axis)" stroke-width="1"></line>
     <text x="${px(m)}" y="${top + bandH + 26}" fill="var(--text-muted)" font-size="11"
       text-anchor="${tickAnchor(px(m), 0, W)}">${hhmm(m)}</text>`).join('');

  return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="하루 타임라인">
    ${marks}${ticks}
  </svg>`;
}

/** Energy vs focus across the day. Same 1–5 scale, so one axis, two series. */
function chartEnergyFocus(dk) {
  const list = dayEntries(dk).filter((x) => x.energy || x.focus);
  if (list.length < 2) return `<div class="empty">기록이 2개 이상 쌓이면 그려져요</div>`;
  const { s, e } = span();
  const H = 210, top = 14, bot = 40, padL = 26, padR = 46;
  const plotH = H - top - bot, innerW = W - padL - padR;
  const px = (m) => padL + ((m - s) / (e - s)) * innerW;
  const py = (v) => top + plotH - ((v - 1) / 4) * plotH;

  let grid = '';
  for (let v = 1; v <= 5; v++) {
    grid += `<line x1="${padL}" y1="${py(v)}" x2="${W - padR}" y2="${py(v)}" stroke="var(--grid)" stroke-width="1"></line>
      <text x="${padL - 7}" y="${py(v) + 4}" fill="var(--text-muted)" font-size="10" text-anchor="end">${v}</text>`;
  }
  const ticks = axisTimeTicks(s, e).map((m) =>
    `<text x="${px(m)}" y="${H - 18}" fill="var(--text-muted)" font-size="11"
      text-anchor="${tickAnchor(px(m), padL - 14, W)}">${hhmm(m)}</text>`).join('');

  const series = [
    { key: 'energy', name: '에너지', col: 'var(--c1)' },
    { key: 'focus',  name: '집중력', col: 'var(--c2)' },
  ];
  // end-labels only survive if the two series separate at the right edge;
  // stacked-apart labels detach from their lines and read as noise
  const ends = series.map((sr) => {
    const l = list.filter((x) => x[sr.key]);
    return l.length ? py(l[l.length - 1][sr.key]) : null;
  });
  const labelEnds = ends[0] == null || ends[1] == null || Math.abs(ends[0] - ends[1]) >= 15;

  let paths = '';
  for (const sr of series) {
    const pts = list.filter((x) => x[sr.key]).map((x) => [px(x.off + DB.set.interval / 2), py(x[sr.key])]);
    if (!pts.length) continue;
    // marks sit above the hit strips, so they must not swallow the pointer
    paths += `<polyline points="${pts.map((p) => p.join(',')).join(' ')}" fill="none" pointer-events="none"
      stroke="${sr.col}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"></polyline>`;
    // 2px surface ring keeps dots legible where the two lines cross
    paths += pts.map((p) => `<circle cx="${p[0]}" cy="${p[1]}" r="4" fill="${sr.col}" stroke="var(--surface-1)" stroke-width="2" pointer-events="none"></circle>`).join('');
    if (labelEnds) {
      const last = pts[pts.length - 1];
      paths += `<text x="${last[0] + 9}" y="${last[1] + 4}" fill="var(--text-2)" font-size="11" pointer-events="none">${sr.name}</text>`;
    }
  }
  // invisible per-block hit strips — bigger than the 8px dots
  let hits = '';
  for (const x of list) {
    const cx = px(x.off + DB.set.interval / 2);
    hits += `<rect class="hit" x="${cx - 12}" y="${top}" width="24" height="${plotH}" fill="transparent"
      data-tip="${esc(`${hhmm(x.off)}|${x.act}|에너지 ${x.energy || '–'} · 집중 ${x.focus || '–'}`)}"></rect>`;
  }

  return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="에너지와 집중력 추이">
    ${grid}${ticks}${hits}${paths}
  </svg>`;
}

/** Category totals — a bar, not a pie: the comparison is the point. */
function chartCategories(rows) {
  if (!rows.length) return `<div class="empty">아직 기록이 없어요</div>`;
  const barH = 22, gapY = 12, padL = 74, padR = 92, top = 6;
  const H = top + rows.length * (barH + gapY);
  const innerW = W - padL - padR;
  const max = Math.max(...rows.map((r) => r.h));
  return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="분류별 시간">
    ${rows.map((r, i) => {
      const y = top + i * (barH + gapY);
      const w = Math.max(2, (r.h / max) * innerW);
      return `<text x="${padL - 9}" y="${y + barH / 2 + 4}" fill="var(--text-2)" font-size="11.5" text-anchor="end">${esc(r.name)}</text>
        <rect class="hit" x="${padL}" y="${y}" width="${w}" height="${barH}" rx="4" fill="var(${r.v})"
          data-tip="${esc(`${r.name}|${fmtH(r.h)} · ${r.n}블록|${r.pct}%`)}"></rect>
        <text x="${padL + w + 8}" y="${y + barH / 2 + 4}" fill="var(--text-2)" font-size="11.5"
          pointer-events="none" font-variant-numeric="tabular-nums">${fmtH(r.h)} · ${r.pct}%</text>`;
    }).join('')}
  </svg>`;
}

/** Week × hour focus heatmap — sequential single hue, light→dark. */
function chartWeekHeat(days) {
  const { s, e } = span();
  const hourFrom = Math.floor(s / 60), hourTo = Math.ceil(e / 60);
  const cols = hourTo - hourFrom;
  if (cols <= 0) return '';
  const padL = 42, padT = 20, cellH = 24, gap = 2;
  const cellW = (W - padL - 8) / cols;
  const H = padT + days.length * (cellH + gap) + 6;

  // 5 focus levels → the 5-step ordinal ramp, one step each
  const step = (v) => ['--s1', '--s2', '--s3', '--s4', '--s5'][Math.min(4, Math.max(0, Math.round(v) - 1))];

  let cells = '', rowLabels = '';
  days.forEach((dk, r) => {
    const y = padT + r * (cellH + gap);
    const d = keyToDate(dk);
    rowLabels += `<text x="${padL - 8}" y="${y + cellH / 2 + 4}" fill="var(--text-muted)" font-size="10.5" text-anchor="end">${d.getMonth() + 1}/${d.getDate()} ${'일월화수목금토'[d.getDay()]}</text>`;
    for (let c = 0; c < cols; c++) {
      const h = hourFrom + c;
      const inHour = dayEntries(dk).filter((x) => Math.floor(x.off / 60) === h && x.focus);
      const x = padL + c * cellW;
      if (!inHour.length) {
        cells += `<rect x="${x}" y="${y}" width="${cellW - gap}" height="${cellH}" rx="3" fill="var(--surface-3)"></rect>`;
        continue;
      }
      const avg = inHour.reduce((a, b) => a + b.focus, 0) / inHour.length;
      cells += `<rect class="hit" x="${x}" y="${y}" width="${cellW - gap}" height="${cellH}" rx="3" fill="var(${step(avg)})"
        data-tip="${esc(`${d.getMonth() + 1}/${d.getDate()} ${hhmm(h * 60)}대|평균 집중 ${avg.toFixed(1)}|${inHour.map((z) => z.act).join(', ')}`)}"></rect>`;
    }
  });
  let colLabels = '';
  for (let c = 0; c < cols; c += cols > 9 ? 2 : 1) {
    colLabels += `<text x="${padL + c * cellW + (cellW - gap) / 2}" y="${padT - 7}" fill="var(--text-muted)" font-size="10" text-anchor="middle">${(hourFrom + c) % 24}</text>`;
  }
  return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="요일·시간대별 집중력">${colLabels}${rowLabels}${cells}</svg>`;
}

/* tooltip — one shared layer, driven by data-tip on any .hit mark */
function wireTips(root) {
  const tip = $('#tip');
  const show = (el, x, y) => {
    const [t, b, m] = (el.dataset.tip || '').split('|');
    tip.innerHTML = `<b>${esc(b || t)}</b>${b ? `<div class="muted">${esc(t)}</div>` : ''}${m ? `<div>${esc(m)}</div>` : ''}`;
    tip.hidden = false;
    const r = tip.getBoundingClientRect();
    tip.style.left = `${Math.max(8, Math.min(window.innerWidth - r.width - 8, x - r.width / 2))}px`;
    tip.style.top = `${Math.max(8, y - r.height - 12)}px`;
  };
  root.addEventListener('pointermove', (e) => {
    const el = e.target.closest('.hit');
    if (el) show(el, e.clientX, e.clientY); else tip.hidden = true;
  });
  root.addEventListener('pointerleave', () => { tip.hidden = true; });
  // keyboard/touch parity: tap shows the same thing
  root.addEventListener('click', (e) => {
    const el = e.target.closest('.hit');
    if (el) { const r = el.getBoundingClientRect(); show(el, r.left + r.width / 2, r.top); }
    else tip.hidden = true;
  });
}

/* ── 10. 리뷰 화면 ─────────────────────────────────────────── */

let reviewDay = logicalDay();
let reviewScope = 'day';

function summarize(dks) {
  const iv = DB.set.interval;
  const all = dks.flatMap((dk) => dayEntries(dk));
  const byCat = {};
  let eSum = 0, eN = 0, fSum = 0, fN = 0, impactBlocks = 0, wasteBlocks = 0;
  for (const x of all) {
    const k = x.cat || 'other';
    byCat[k] = (byCat[k] || 0) + 1;
    if (x.energy) { eSum += x.energy; eN++; }
    if (x.focus) { fSum += x.focus; fN++; }
    if (x.impact === 2) impactBlocks++;
    if (x.cat === 'waste') wasteBlocks++;
  }
  const total = all.length;
  const rows = CATS.map((c) => ({ name: c.n, v: c.v, k: c.k, n: byCat[c.k] || 0 }))
    .concat(byCat.other ? [{ name: '미분류', v: '--text-muted', k: 'other', n: byCat.other }] : [])
    .filter((r) => r.n > 0)
    .map((r) => ({ ...r, h: hrs(r.n), pct: total ? Math.round((r.n / total) * 100) : 0 }))
    .sort((a, b) => b.n - a.n);
  const possible = dks.reduce((a, dk) => a + slotsOf().filter((s) => {
    const isToday = dk === logicalDay();
    return !isToday || s + iv <= offsetOf();
  }).length, 0);
  return {
    all, rows, total,
    impactH: hrs(impactBlocks), wasteH: hrs(wasteBlocks),
    energy: eN ? eSum / eN : 0, focus: fN ? fSum / fN : 0,
    coverage: possible ? Math.round((total / possible) * 100) : 0,
    ideas: DB.ideas.filter((i) => dks.includes(i.day)).length,
  };
}

function bestWindow(dk) {
  const list = dayEntries(dk).filter((x) => x.focus);
  if (list.length < 2) return null;
  let best = null;
  for (let i = 0; i < list.length; i++) {
    let sum = 0, n = 0;
    for (let j = i; j < list.length && j < i + 4; j++) {
      if (list[j].off !== list[i].off + (j - i) * DB.set.interval) break;
      sum += list[j].focus; n++;
      if (n >= 2) {
        const avg = sum / n;
        if (!best || avg > best.avg || (avg === best.avg && n > best.n)) {
          best = { avg, n, from: list[i].off, to: list[j].off + DB.set.interval };
        }
      }
    }
  }
  return best;
}

function tableView(id, head, rows) {
  return `<button class="tv-toggle" data-tv="${id}">표로 보기</button>
    <div id="tv-${id}" hidden><table class="tv"><thead><tr>${
      head.map((h, i) => `<th${i ? ' class="n"' : ''}>${esc(h)}</th>`).join('')
    }</tr></thead><tbody>${
      rows.map((r) => `<tr>${r.map((c, i) => `<td${i ? ' class="n"' : ''}>${esc(c)}</td>`).join('')}</tr>`).join('')
    }</tbody></table></div>`;
}

function renderReview() {
  $('#dPick').value = reviewDay;
  $$('#scopeSeg button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.v === reviewScope)));
  const dks = reviewScope === 'day' ? [reviewDay] : Array.from({ length: 7 }, (_, i) => addDays(reviewDay, -6 + i));
  const S = summarize(dks);
  const legend = `<div class="legend">${S.rows.map((r) => `<span style="--k:var(${r.v})"><i></i>${esc(r.name)}</span>`).join('')}</div>`;

  let html = '';

  if (!S.total) {
    html += `<div class="card"><div class="empty">이 ${reviewScope === 'day' ? '날' : '주'}엔 기록이 없어요.<br>
      <span style="opacity:.75">기록 탭에서 지난 블록도 채울 수 있어요.</span></div></div>`;
    $('#reviewBody').innerHTML = html;
    return;
  }

  /* hero — exactly one per view: the number this whole system exists for */
  html += `<div class="card">
    <div class="hero">
      <div class="val">${fmtH(S.impactH)}</div>
      <div class="lbl">임팩트 높은 일에 쓴 시간</div>
      <div class="delta">전체 기록 ${fmtH(hrs(S.total))} 중 ${S.total ? Math.round((S.impactH / hrs(S.total)) * 100) : 0}%${
        S.wasteH > 0 ? ` · 낭비로 표시한 시간 ${fmtH(S.wasteH)}` : ''
      }</div>
    </div>
  </div>`;

  html += `<div class="tiles" style="margin-bottom:14px">
    <div class="tile"><div class="lbl">기록률</div><div class="val">${S.coverage}<small>%</small></div></div>
    <div class="tile"><div class="lbl">평균 에너지</div><div class="val">${S.energy ? S.energy.toFixed(1) : '–'}<small>/5</small></div></div>
    <div class="tile"><div class="lbl">평균 집중력</div><div class="val">${S.focus ? S.focus.toFixed(1) : '–'}<small>/5</small></div></div>
    <div class="tile"><div class="lbl">아이디어</div><div class="val">${S.ideas}<small>개</small></div></div>
  </div>`;

  if (reviewScope === 'day') {
    const rows = slotsOf().map((s) => {
      const e = getEntry(reviewDay, s);
      return [`${hhmm(s)}–${hhmm(s + DB.set.interval)}`,
        e && !e.skipped && e.act ? e.act : '—',
        e?.cat ? CAT[e.cat].n : '—',
        e?.energy || '–', e?.focus || '–', e?.impact === 2 ? '높음' : e?.impact === 1 ? '보통' : e?.impact === 0 ? '낮음' : '–'];
    });
    html += `<div class="card">
      <div class="card-head"><h2>하루 타임라인</h2><span class="sub">한 칸 = ${DB.set.interval}분 · 아래 초록선 = 임팩트</span></div>
      <div class="chart-wrap">${chartDayBand(reviewDay)}</div>
      ${legend}
      ${tableView('band', ['시간', '활동', '분류', '에너지', '집중', '임팩트'], rows)}
    </div>`;

    html += `<div class="card">
      <div class="card-head"><h2>에너지 · 집중력</h2><span class="sub">1–5</span></div>
      <div class="chart-wrap">${chartEnergyFocus(reviewDay)}</div>
      <div class="legend"><span style="--k:var(--c1)"><i></i>에너지</span><span style="--k:var(--c2)"><i></i>집중력</span></div>
      ${tableView('ef', ['시간', '활동', '에너지', '집중'], dayEntries(reviewDay).map((x) => [hhmm(x.off), x.act, x.energy || '–', x.focus || '–']))}
    </div>`;
  } else {
    html += `<div class="card">
      <div class="card-head"><h2>시간대별 집중력</h2><span class="sub">진할수록 몰입 · 가로축 = 시</span></div>
      <div class="chart-wrap">${chartWeekHeat(dks)}</div>
      <div class="legend">
        ${[1, 2, 3, 4, 5].map((v) => `<span style="--k:var(--s${v})"><i></i>${v}${v === 1 ? ' 산만' : v === 5 ? ' 몰입' : ''}</span>`).join('')}
        <span style="--k:var(--surface-3)"><i></i>기록 없음</span>
      </div>
      ${tableView('heat', ['날짜', '블록', '평균 에너지', '평균 집중'], dks.map((dk) => {
        const l = dayEntries(dk);
        const en = l.filter((x) => x.energy), fo = l.filter((x) => x.focus);
        return [dk, l.length,
          en.length ? (en.reduce((a, b) => a + b.energy, 0) / en.length).toFixed(1) : '–',
          fo.length ? (fo.reduce((a, b) => a + b.focus, 0) / fo.length).toFixed(1) : '–'];
      }))}
    </div>`;
  }

  html += `<div class="card">
    <div class="card-head"><h2>분류별 시간</h2><span class="sub">${fmtH(hrs(S.total))} 기록됨</span></div>
    <div class="chart-wrap">${chartCategories(S.rows)}</div>
    ${tableView('cat', ['분류', '시간', '블록', '비중'], S.rows.map((r) => [r.name, fmtH(r.h), r.n, `${r.pct}%`]))}
  </div>`;

  /* derived read — the part that makes the dashboard say something */
  const ins = [];
  const top = S.rows[0];
  if (top) ins.push(`<span class="k">📌</span><div>가장 많이 한 건 <b>${esc(top.name)}</b> — ${fmtH(top.h)}, 전체의 ${top.pct}%.</div>`);
  const waste = S.rows.find((r) => r.k === 'waste');
  if (waste) ins.push(`<span class="k">🧹</span><div><b>낭비·산만</b>이 ${fmtH(waste.h)} (${waste.pct}%). 여기서 한 블록만 줄여도 ${DB.set.interval}분이 돌아와요.</div>`);
  if (reviewScope === 'day') {
    const bw = bestWindow(reviewDay);
    if (bw) ins.push(`<span class="k">🎯</span><div>최고 집중 구간은 <b>${hhmm(bw.from)}–${hhmm(bw.to)}</b> (평균 ${bw.avg.toFixed(1)}). 내일 가장 중요한 일을 이 시간에 두세요.</div>`);
    const lows = dayEntries(reviewDay).filter((x) => x.energy && x.energy <= 2);
    if (lows.length) ins.push(`<span class="k">🔋</span><div>에너지가 바닥난 블록 ${lows.length}개 — 가장 이른 건 <b>${hhmm(lows[0].off)}</b>. 회복 루틴을 그 앞에 넣어 보세요.</div>`);
  }
  if (S.impactH === 0 && S.total >= 4) ins.push(`<span class="k">⚠️</span><div>임팩트 <b>높음</b>으로 표시한 블록이 없어요. 우선순위가 실제 시간으로 안 옮겨졌다는 신호일 수 있어요.</div>`);
  if (ins.length) html += `<div class="card"><h2>읽어낸 것</h2>${ins.map((i) => `<div class="insight">${i}</div>`).join('')}</div>`;

  /* guided close-out */
  if (reviewScope === 'day') {
    const r = DB.reviews[reviewDay] || {};
    html += `<div class="card">
      <h2>하루 마감 회고</h2>
      <label class="field"><span class="lbl">오늘 가장 임팩트 있었던 행동 하나</span><textarea data-rev="win" style="min-height:56px">${esc(r.win || '')}</textarea></label>
      <label class="field"><span class="lbl">내일 없앨 낭비 하나</span><textarea data-rev="cut" style="min-height:56px">${esc(r.cut || '')}</textarea></label>
      <label class="field"><span class="lbl">내일의 우선순위 1가지</span><textarea data-rev="next" style="min-height:56px">${esc(r.next || '')}</textarea></label>
      <div class="hint">입력하면 자동 저장돼요.</div>
    </div>`;

    const inbox = DB.ideas.filter((i) => i.status === 'inbox' && dks.includes(i.day));
    html += `<div class="card">
      <div class="card-head"><h2>아이디어 정리</h2><span class="sub">${inbox.length}개 대기</span></div>
      ${inbox.length
        ? inbox.map((i) => `<div class="idea" data-id="${i.id}">
            <p>${esc(i.text)}</p><div class="when">${hhmm(i.slot)}</div>
            <div class="triage">
              <button class="btn sm ghost" data-to="content">콘텐츠감</button>
              <button class="btn sm ghost" data-to="bank">아이디어뱅크</button>
              <button class="btn sm ghost" data-to="vault">창고</button>
              <button class="btn sm ghost" data-to="dropped" style="color:var(--text-muted)">버림</button>
            </div></div>`).join('')
        : '<div class="empty">정리할 아이디어가 없어요</div>'}
    </div>`;
  }

  $('#reviewBody').innerHTML = html;
}

/* ── 11. 설정 · 내보내기 ───────────────────────────────────── */

function renderNotifStatus() {
  const el = $('#notifStatus'), t = $('#notifStatusText');
  const perm = 'Notification' in window ? Notification.permission : 'unsupported';
  const ok = perm === 'granted';
  el.dataset.ok = ok ? '1' : '0';
  t.textContent = perm === 'granted' ? '알림 켜짐 — 알람이 울립니다'
    : perm === 'denied' ? '알림이 차단됨 — 브라우저 사이트 설정에서 허용해 주세요'
    : perm === 'unsupported' ? '이 브라우저는 알림을 지원하지 않아요 (.ics 알람을 쓰세요)'
    : '알림 권한이 아직 없어요';
  $('#permBtn').hidden = ok;

  const std = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone;
  $('#alarmLayers').innerHTML = [
    `${Alarm.supportsTriggers && ok ? '✅' : '⬜️'} <b>예약 알림(OS)</b> — 앱을 완전히 꺼도 울림 ${Alarm.supportsTriggers ? '' : '<span style="opacity:.7">(이 브라우저 미지원)</span>'}`,
    `${ok ? '✅' : '⬜️'} <b>브라우저 알림</b> — 탭이 살아 있을 때`,
    `⬜️ <b>캘린더 알람</b> — 아래에서 .ics 받으면 상시 (아이폰 권장)`,
    `${DB.set.pushUrl ? '✅' : '⬜️'} <b>서버 푸시</b> — Worker 배포 시`,
    std ? '' : `<div style="margin-top:8px;opacity:.8">💡 홈 화면에 추가하면 알림이 훨씬 안정적이에요 (iOS는 16.4+ 필수).</div>`,
  ].filter(Boolean).join('<br>');
}

function exportJson() {
  download(`30min-${logicalDay()}.json`, 'application/json',
    JSON.stringify({ v: 1, exportedAt: new Date().toISOString(), settings: DB.set, entries: DB.entries, ideas: DB.ideas, reviews: DB.reviews }, null, 2));
}

function exportCsv() {
  const q = (s) => `"${String(s ?? '').replace(/"/g, '""')}"`;
  const lines = ['date,slot_start,slot_end,activity,category,energy,focus,impact,note'];
  for (const dk of Object.keys(DB.entries).sort()) {
    for (const [off, e] of Object.entries(DB.entries[dk]).sort((a, b) => a[0] - b[0])) {
      if (e.skipped || !e.act) continue;
      const o = Number(off);
      lines.push([dk, hhmm(o), hhmm(o + DB.set.interval), q(e.act), CAT[e.cat]?.n || '', e.energy || '', e.focus || '',
        e.impact === 2 ? '높음' : e.impact === 1 ? '보통' : e.impact === 0 ? '낮음' : '', q(e.note || '')].join(','));
    }
  }
  download(`30min-${logicalDay()}.csv`, 'text/csv;charset=utf-8', '﻿' + lines.join('\n'));
}

function exportMd() {
  const dk = reviewDay || logicalDay();
  const S = summarize([dk]);
  const r = DB.reviews[dk] || {};
  const bw = bestWindow(dk);
  const L = [`# ${dk} 하루 기록`, '',
    `- 임팩트 시간: **${fmtH(S.impactH)}** / 기록 ${fmtH(hrs(S.total))}`,
    `- 평균 에너지 ${S.energy.toFixed(1)} · 평균 집중력 ${S.focus.toFixed(1)} · 기록률 ${S.coverage}%`,
    bw ? `- 최고 집중 구간: ${hhmm(bw.from)}–${hhmm(bw.to)} (평균 ${bw.avg.toFixed(1)})` : '',
    '', '## 분류별', ...S.rows.map((x) => `- ${x.name}: ${fmtH(x.h)} (${x.pct}%)`),
    '', '## 타임라인', ...dayEntries(dk).map((e) =>
      `- \`${hhmm(e.off)}\` ${e.act}${e.cat ? ` _(${CAT[e.cat].n})_` : ''} — E${e.energy || '–'}/F${e.focus || '–'}${e.impact === 2 ? ' **임팩트**' : ''}${e.note ? `\n    - ${e.note.replace(/\n/g, ' ')}` : ''}`),
    '', '## 아이디어', ...(DB.ideas.filter((i) => i.day === dk).map((i) => `- [${IDEA_STATUS.find((s) => s.k === i.status).n}] ${i.text.replace(/\n/g, ' ')}`)),
    '', '## 회고', `- 임팩트: ${r.win || '—'}`, `- 없앨 낭비: ${r.cut || '—'}`, `- 내일 우선순위: ${r.next || '—'}`,
  ].filter((x) => x !== '');
  download(`30min-${dk}.md`, 'text/markdown;charset=utf-8', L.join('\n'));
}

function storageInfo() {
  let bytes = 0;
  for (const k of Object.values(K)) bytes += (localStorage.getItem(k) || '').length * 2;
  const n = Object.values(DB.entries).reduce((a, d) => a + Object.keys(d).length, 0);
  $('#storageInfo').textContent = `블록 ${n}개 · 아이디어 ${DB.ideas.length}개 · 약 ${(bytes / 1024).toFixed(0)}KB 사용 중`;
}

/* ── 12. 라우팅 · 이벤트 · 부팅 ────────────────────────────── */

let currentView = 'log';
const TITLES = { log: '기록', ideas: '아이디어', review: '리뷰', settings: '설정' };

function go(v) {
  currentView = v;
  $$('.view').forEach((s) => { s.hidden = s.id !== `v-${v}`; });
  $$('.tabbar button').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.v === v)));
  $('#viewTitle').textContent = TITLES[v];
  $('#fabIdea').hidden = false;
  window.scrollTo({ top: 0 });
  if (v === 'log') renderLog();
  if (v === 'ideas') renderIdeas();
  if (v === 'review') renderReview();
  if (v === 'settings') { renderNotifStatus(); storageInfo(); }
}

function routeAction(action, slot) {
  if (action === 'idea') { go('log'); openIdeaSheet(); return; }
  if (action === 'review') { reviewDay = logicalDay(); go('review'); return; }
  go('log');
  if (slot !== '' && slot != null) loadDraft(logicalDay(), Number(slot));
}

function openIdeaSheet() {
  $('#ideaText').value = '';
  $('#ideaSheet').showModal();
  setTimeout(() => $('#ideaText').focus(), 60);
}

function wire() {
  /* tabs */
  $$('.tabbar button').forEach((b) => b.addEventListener('click', () => go(b.dataset.v)));

  /* theme */
  $('#themeBtn').addEventListener('click', () => {
    DB.set.theme = DB.set.theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = DB.set.theme;
    saveSet();
  });
  $('#bellBtn').addEventListener('click', () => go('settings'));

  /* ── logging ── */
  buildScale('#sEnergy', ENERGY, 'energy');
  buildScale('#sFocus', FOCUS, 'focus');
  buildCats();
  wireMic('#micAct', '#fAct', '#micActHint');
  wireMic('#micNote', '#fNote');
  wireMic('#micIdea', '#ideaText', '#micIdeaHint');

  $('#fAct').addEventListener('input', (e) => { draft.act = e.target.value; });
  $('#fNote').addEventListener('input', (e) => { draft.note = e.target.value; });
  $('#sImpact').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    draft.impact = draft.impact === Number(b.dataset.v) ? -1 : Number(b.dataset.v);
    $$('#sImpact button').forEach((x) => x.setAttribute('aria-pressed', String(Number(x.dataset.v) === draft.impact)));
  });
  $('#recentChips').addEventListener('click', (e) => {
    const b = e.target.closest('.chip'); if (!b) return;
    draft.act = b.dataset.act; $('#fAct').value = draft.act;
    if (b.dataset.cat) { draft.cat = b.dataset.cat; paintCats(); }
  });
  $('#slotPrev').addEventListener('click', () => {
    const all = slotsOf(); const i = all.indexOf(editSlot);
    if (i > 0) loadDraft(editDay, all[i - 1]);
    else loadDraft(addDays(editDay, -1), all[all.length - 1]);
  });
  $('#slotNext').addEventListener('click', () => {
    const all = slotsOf(); const i = all.indexOf(editSlot);
    if (i >= 0 && i < all.length - 1) loadDraft(editDay, all[i + 1]);
    else loadDraft(addDays(editDay, 1), all[0]);
  });

  $('#saveEntry').addEventListener('click', () => {
    if (!draft.act.trim()) return toast('무엇을 했는지 한 줄만 적어 주세요');
    putEntry(editDay, editSlot, {
      act: draft.act.trim(), cat: draft.cat, energy: draft.energy,
      focus: draft.focus, impact: draft.impact, note: draft.note.trim(), skipped: false,
    });
    // a note flagged as an idea also lands in the inbox
    const m = draft.note.match(/^\s*아이디어\s*[:：]\s*([\s\S]+)/);
    if (m) addIdea(m[1], 'ping');
    toast(m ? '저장 · 아이디어함에도 담았어요' : '저장됐어요');
    // land on the next thing that still needs filling, so backfilling flows
    const all = slotsOf();
    const isToday = editDay === logicalDay();
    const fillable = (s) => s > editSlot && !getEntry(editDay, s) && (!isToday || s + DB.set.interval <= offsetOf());
    const next = all.find(fillable);
    loadDraft(editDay, next ?? (isToday ? currentSlot() : editSlot));
  });

  $('#skipEntry').addEventListener('click', () => {
    putEntry(editDay, editSlot, { skipped: true, act: '' });
    toast('건너뛰었어요');
    const all = slotsOf(); const i = all.indexOf(editSlot);
    loadDraft(editDay, all[Math.min(all.length - 1, i + 1)]);
  });

  $('#repeatPrev').addEventListener('click', () => {
    const all = slotsOf(); const i = all.indexOf(editSlot);
    let prev = null;
    for (let j = i - 1; j >= 0; j--) { const e = getEntry(editDay, all[j]); if (e && e.act) { prev = e; break; } }
    if (!prev) return toast('직전에 기록된 블록이 없어요');
    draft.act = prev.act; draft.cat = prev.cat; draft.impact = prev.impact ?? -1;
    $('#fAct').value = draft.act; paintCats();
    $$('#sImpact button').forEach((x) => x.setAttribute('aria-pressed', String(Number(x.dataset.v) === draft.impact)));
    toast('직전 블록을 불러왔어요 — 에너지·집중력만 골라 주세요');
  });

  $('#todayList').addEventListener('click', (e) => {
    const b = e.target.closest('[data-slot]'); if (!b) return;
    loadDraft(logicalDay(), Number(b.dataset.slot));
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  /* ── ideas ── */
  $('#fabIdea').addEventListener('click', openIdeaSheet);
  $('#ideaSheet').addEventListener('close', () => {
    if ($('#ideaSheet').returnValue === 'save') {
      const i = addIdea($('#ideaText').value, 'quick');
      if (i) { toast('아이디어함에 담았어요'); if (currentView === 'ideas') renderIdeas(); }
    }
  });
  $('#ideaFilters').addEventListener('click', (e) => {
    const b = e.target.closest('.chip'); if (!b) return;
    ideaFilter = b.dataset.k; renderIdeas();
  });
  $('#ideaSearch').addEventListener('input', (e) => { ideaQuery = e.target.value; renderIdeas(); });

  const triage = (root, after) => root.addEventListener('click', (e) => {
    const card = e.target.closest('.idea'); if (!card) return;
    const btn = e.target.closest('button'); if (!btn) return;
    const idea = DB.ideas.find((i) => i.id === card.dataset.id); if (!idea) return;
    if (btn.dataset.del) {
      if (!confirm('이 아이디어를 삭제할까요?')) return;
      DB.ideas = DB.ideas.filter((i) => i.id !== idea.id);
    } else if (btn.dataset.to) {
      idea.status = btn.dataset.to;
      toast(`${IDEA_STATUS.find((s) => s.k === idea.status).n}(으)로 옮겼어요`);
    } else return;
    saveIdeas(); after();
  });
  triage($('#ideaList'), renderIdeas);

  /* ── review ── */
  $('#dPrev').addEventListener('click', () => { reviewDay = addDays(reviewDay, -1); renderReview(); });
  $('#dNext').addEventListener('click', () => { reviewDay = addDays(reviewDay, 1); renderReview(); });
  $('#dPick').addEventListener('change', (e) => { if (e.target.value) { reviewDay = e.target.value; renderReview(); } });
  $('#scopeSeg').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    reviewScope = b.dataset.v; renderReview();
  });
  $('#reviewBody').addEventListener('click', (e) => {
    const t = e.target.closest('[data-tv]');
    if (t) { const box = $(`#tv-${t.dataset.tv}`); box.hidden = !box.hidden; t.textContent = box.hidden ? '표로 보기' : '표 닫기'; }
  });
  $('#reviewBody').addEventListener('input', (e) => {
    const f = e.target.closest('[data-rev]'); if (!f) return;
    DB.reviews[reviewDay] = DB.reviews[reviewDay] || {};
    DB.reviews[reviewDay][f.dataset.rev] = f.value;
    saveReviews();
  });
  triage($('#reviewBody'), renderReview);
  wireTips($('#reviewBody'));   // delegated once — survives every re-render

  /* ── settings ── */
  const bind = (sel, key, prop = 'value', ev = 'change', cast = (v) => v, regrid = false) => {
    const el = $(sel);
    el[prop] = DB.set[key];
    el.addEventListener(ev, () => {
      DB.set[key] = cast(el[prop]);
      saveSet();
      Alarm.lastFired = null;
      Alarm.schedule();
      // a new block grid means the editor has to re-seat on the current block
      if (regrid) loadDraft(logicalDay(), currentSlot()); else renderLog();
      renderNotifStatus();
    });
  };
  bind('#setInterval', 'interval', 'value', 'change', Number, true);
  bind('#setDayStart', 'dayStart', 'value', 'change', (v) => v, true);
  bind('#setDayEnd', 'dayEnd', 'value', 'change', (v) => v, true);
  bind('#setReviewAt', 'reviewAt');
  bind('#setSound', 'sound', 'checked');
  bind('#setWeekend', 'weekend', 'checked');
  bind('#setPushUrl', 'pushUrl', 'value', 'input');

  $('#permBtn').addEventListener('click', async () => {
    if (!('Notification' in window)) return toast('이 브라우저는 알림을 지원하지 않아요');
    await Notification.requestPermission();
    Alarm.chime();          // also unlocks the audio context for later chimes
    renderNotifStatus();
    Alarm.schedule();
  });
  $('#testBtn').addEventListener('click', () => Alarm.fire('⏱ 테스트 알람', '이렇게 30분마다 울려요', currentSlot()));
  $('#icsBtn').addEventListener('click', () => Alarm.ics());
  $('#pushBtn').addEventListener('click', () => Alarm.subscribePush());

  $('#expJson').addEventListener('click', exportJson);
  $('#expCsv').addEventListener('click', exportCsv);
  $('#expMd').addEventListener('click', exportMd);
  $('#impBtn').addEventListener('click', () => $('#impFile').click());
  $('#impFile').addEventListener('change', async (e) => {
    const f = e.target.files[0]; if (!f) return;
    try {
      const d = JSON.parse(await f.text());
      if (!d.entries) throw new Error('형식이 달라요');
      // merge, never clobber: existing blocks win
      for (const [dk, slots] of Object.entries(d.entries)) {
        DB.entries[dk] = Object.assign({}, slots, DB.entries[dk] || {});
      }
      const have = new Set(DB.ideas.map((i) => i.id));
      DB.ideas = DB.ideas.concat((d.ideas || []).filter((i) => !have.has(i.id)));
      DB.reviews = Object.assign({}, d.reviews || {}, DB.reviews);
      saveEntries(); saveIdeas(); saveReviews();
      toast('가져왔어요'); storageInfo(); renderLog();
    } catch (err) { toast('가져오기 실패: ' + err.message); }
    e.target.value = '';
  });
  $('#wipeBtn').addEventListener('click', () => {
    if (!confirm('모든 기록과 아이디어가 지워집니다. 계속할까요?')) return;
    if (!confirm('정말요? 되돌릴 수 없어요. 먼저 내보내기를 권해요.')) return;
    Object.values(K).forEach((k) => localStorage.removeItem(k));
    location.reload();
  });

  /* collapse the idea button while scrolling down so it stops covering 저장 */
  let lastY = 0, fabT;
  addEventListener('scroll', () => {
    const y = window.scrollY;
    const fab = $('#fabIdea');
    if (y > lastY + 6 && y > 80) fab.dataset.collapsed = '1';
    else if (y < lastY - 6 || y < 40) fab.dataset.collapsed = '0';
    lastY = y;
    clearTimeout(fabT);
    fabT = setTimeout(() => { fab.dataset.collapsed = '0'; }, 900);
  }, { passive: true });

  /* keyboard: 1–5 sets focus scale, ⌘/Ctrl+Enter saves, N opens idea */
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') $('#tip').hidden = true;
    const typing = /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName);
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter' && currentView === 'log') { e.preventDefault(); $('#saveEntry').click(); }
    if (typing) return;
    if (e.key.toLowerCase() === 'n') { e.preventDefault(); openIdeaSheet(); }
  });
}

function boot() {
  document.documentElement.dataset.theme = DB.set.theme || 'dark';
  wire();
  updateClock();

  const p = new URLSearchParams(location.search);
  editSlot = null;
  loadDraft(logicalDay(), currentSlot());
  if (p.get('view')) go(p.get('view'));
  else if (p.get('action')) routeAction(p.get('action'), p.get('slot') ?? '');
  else go('log');

  Alarm.init();
  // schedule the next day's OS alarms as the day rolls over
  setInterval(() => Alarm.schedule(), 3600000);
}

document.addEventListener('DOMContentLoaded', boot);
