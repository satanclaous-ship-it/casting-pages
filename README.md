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

- `tracker/` — the app (no build step, no dependencies)
- `worker/` — optional Cloudflare Worker for real Web Push; see `worker/README.md`

## Editing

Markdown files in this repo render as pages via Jekyll on GitHub Pages.

- `index.md` → `/`
- `privacy.md` → `/privacy/`
- `support.md` → `/support/`
- `_config.yml` → site-wide settings

Push to `main` and Pages will rebuild within ~1 minute.

## Sister repo

- App code (private): `casting`
