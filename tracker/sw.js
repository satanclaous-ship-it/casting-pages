/* 30분 기록 — service worker
   Two jobs:
   1. Offline shell cache, so the app opens with no network.
   2. Own the notifications: the page asks the SW to show them, and the SW
      routes a click back into an already-open tab instead of spawning a new one. */

const CACHE = '30min-tracker-v1';
const SHELL = [
  './',
  './index.html',
  './app.css',
  './app.js',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Network-first for the shell so a deploy lands immediately, cache as the
// offline floor. Anything else is left to the browser.
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then((hit) => hit || caches.match('./index.html')))
  );
});

self.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.type === 'notify') {
    self.registration.showNotification(d.title || '30분 기록', {
      body: d.body || '',
      tag: d.tag || 'ping',
      renotify: true,
      requireInteraction: true,
      icon: './icon-192.png',
      badge: './icon-192.png',
      data: { slot: d.slot || null, action: d.act || 'log' },
      actions: [
        { action: 'log', title: '기록하기' },
        { action: 'idea', title: '아이디어만' },
      ],
    });
  }
});

// Layer 4: a push from the Cloudflare Worker. Arrives with the app fully
// closed, which is the whole point — so it must always show something.
self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch { d = { title: '⏱ 30분 기록' }; }
  e.waitUntil(
    self.registration.showNotification(d.title || '⏱ 30분 기록', {
      body: d.body || '뭐 했어? 에너지·집중력·아이디어 기록하기',
      tag: `t30-push-${d.action || 'log'}`,
      renotify: true,
      icon: './icon-192.png',
      badge: './icon-192.png',
      data: { slot: d.slot || null, action: d.action || 'log' },
      actions: [
        { action: 'log', title: '기록하기' },
        { action: 'idea', title: '아이디어만' },
      ],
    })
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const act = e.action || (e.notification.data && e.notification.data.action) || 'log';
  const slot = (e.notification.data && e.notification.data.slot) || '';
  const target = new URL(`./?action=${act}${slot ? `&slot=${encodeURIComponent(slot)}` : ''}`, self.location.href).href;

  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if (c.url.startsWith(self.location.origin) && 'focus' in c) {
          c.postMessage({ type: 'open', action: act, slot });
          return c.focus();
        }
      }
      return self.clients.openWindow(target);
    })
  );
});
