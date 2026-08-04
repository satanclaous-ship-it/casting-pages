# casting-pages

Public pages for the Casting iOS app — Privacy Policy, Support, and landing.

Hosted via GitHub Pages.

## Live URLs

- Landing: https://satanclaous-ship-it.github.io/casting-pages/
- Privacy Policy: https://satanclaous-ship-it.github.io/casting-pages/privacy/
- Support: https://satanclaous-ship-it.github.io/casting-pages/support/
- 30분 기록 (tracker PWA): https://satanclaous-ship-it.github.io/casting-pages/tracker/

## 30분 기록 — time & energy ledger

A personal PWA under `tracker/`. Every 30 minutes it pings you to log what you
did, your energy, your focus, and any idea that surfaced; at day's end it
visualizes where the time actually went. All data stays in the browser's
localStorage — nothing is sent anywhere.

It is deliberately **not linked from the landing page** — it ships alongside the
marketing pages but isn't part of them.

- `tracker/` — the web app (no build step, no dependencies) — **verified in a browser**
- `worker/` — optional Cloudflare Worker for real Web Push; see `worker/README.md`
- `min30-ios/` — the same system as a native iOS app; see `min30-ios/README.md`.
  **Not yet compiled** — it was written without access to macOS or Xcode.

### Two ways to log a block

- **간편 (quick)** — tap one tag. Category and a default impact come with it, and
  energy/focus carry forward from the previous block, so a block is two taps.
  Built for logging while walking. `직전과 동일로 바로 저장` is one tap.
- **자세히 (detailed)** — type (or dictate) what you actually did, pick a category,
  add a note. Anything typed here is promoted into the quick grid automatically,
  so the tag set becomes yours after about a week.

### Which alarms fire on which browser

| | Safari tab (iOS) | Home-screen PWA (iOS 16.4+) | Chrome / Android |
|---|---|---|---|
| `.ics` calendar alarm | ✅ | ✅ | ✅ |
| Web Push (needs `worker/`) | ❌ | ✅ | ✅ |
| Notification Triggers (no server) | ❌ | ❌ | ✅ |
| In-page alarm + chime | only while open | only while open | only while open |

On iPhone the `.ics` route is the one that needs neither a server nor a
home-screen install — iOS Calendar fires it regardless of the browser.
Whatever fires, a missed block is still recoverable: opening the app offers to
backfill it.

## Editing

Markdown files in this repo render as pages via Jekyll on GitHub Pages.

- `index.md` → `/`
- `privacy.md` → `/privacy/`
- `support.md` → `/support/`
- `_config.yml` → site-wide settings

Push to `main` and Pages will rebuild within ~1 minute.

## Sister repo

- App code (private): `casting`
