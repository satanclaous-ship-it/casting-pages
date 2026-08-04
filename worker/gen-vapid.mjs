/* VAPID 키 한 쌍 생성 —  node gen-vapid.mjs
   공개키는 wrangler.toml의 [vars]에, 개인키는 secret으로 넣으세요. */
const { subtle } = globalThis.crypto;

const b64u = (buf) => Buffer.from(buf).toString('base64')
  .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

const kp = await subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const pub = await subtle.exportKey('raw', kp.publicKey);       // 65 bytes, 0x04||X||Y
const jwk = await subtle.exportKey('jwk', kp.privateKey);

console.log('\nVAPID_PUBLIC_KEY  (공개 — wrangler.toml [vars]에 넣고, 앱에도 자동 전달됨)');
console.log(b64u(pub));
console.log('\nVAPID_PRIVATE_KEY (비밀 — 아래 명령으로 넣기)');
console.log(jwk.d);
console.log('\n  npx wrangler secret put VAPID_PRIVATE_KEY\n');
