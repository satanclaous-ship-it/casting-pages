---
title: Privacy Policy
permalink: /privacy/
---

# Privacy Policy

**Effective date**: May 10, 2026
**Last updated**: August 13, 2026 (v1.0 submission pass — favorites moved to your
private iCloud; subscriptions added; removed the personalized-affirmation,
AI-provider, and device-attestation sections, since that feature does not ship
in v1.0)

This Privacy Policy describes how Casting ("we," "us," or "our") collects, uses, and protects your information when you use the Casting iOS app ("the App").

We designed Casting to do the absolute minimum needed to make the ritual work. We do not sell your data. We do not use third-party advertising or behavioral analytics SDKs. We do not transmit your voice recordings to any server.

## 1. Information We Collect

### No account, no email

**Casting has no sign-in.** We do not collect your name, your email address, or
any account credentials. Everything we do collect is tied to an anonymous
per-install identifier — a random value created when you first open the App and
stored on your device. Deleting the App resets it.

### Stored on your device only

The following never leaves your iPhone, and we cannot see it:

- Your alarm times, recurrence, sound, and topic settings
- Your ritual progress and completion history
- The affirmations shown to you during the ritual

### Saved affirmations — your private iCloud

When you save an affirmation, it is stored in **your own private iCloud
database** (Apple's CloudKit), under your Apple Account, so your saved
affirmations follow you to a new iPhone.

This is a *private* database. **We have no access to it.** We cannot read, list,
export, or delete what it contains — only your devices, signed in to your Apple
Account, can. If you sign out of iCloud or disable iCloud for Casting, saving
still works; it simply stays on that one device. See
[Apple's privacy policy](https://www.apple.com/legal/privacy/).

### Subscription

Casting offers an optional paid subscription. **Purchases are handled entirely
by Apple.** We never see or receive your payment method, card number, billing
address, or Apple Account. The App only asks your device whether an active
subscription exists, and that answer stays on your device — we do not transmit,
log, or store your purchase history on our servers. Billing questions and
cancellations are managed in your Apple Account settings.

### Voice

Casting requires microphone access to listen for spoken affirmations during the ritual. Voice processing happens **entirely on your device** using Apple's on-device speech recognition. **We do not record, store, or transmit your voice to any server.** Voice data never leaves your iPhone.

### Calendar (optional)

If you grant calendar access, Casting reads your **upcoming event titles only**, to show what your day holds as you enter the ritual. We do not read attendees, notes, locations, descriptions, recurrence rules, or past events. **Calendar data is processed entirely on your device and never transmitted to our servers.** You can deny or revoke calendar access at any time in iOS Settings — the App still works without it.

### Crash and performance diagnostics

We use **Sentry** for crash and performance monitoring only. When the App crashes or encounters an unhandled error, Sentry sends a diagnostic report containing the stack trace, device model, OS version, and App version. This report contains **no personal information, no behavioral analytics, no advertising identifiers, and no content you wrote or spoke**, and is not joined to the identifier used elsewhere in this policy. It is used solely to find and fix bugs. See [Sentry's privacy policy](https://sentry.io/privacy/).

### Anonymous usage events

To understand whether the ritual is actually forming a daily habit for real users, the App records a small set of anonymous events to our own Supabase backend:

- **Lifecycle**: app opened, onboarding completed, alarm set, alarm fired,
  ritual started, ritual completed or the stage you stopped at (trap / prep /
  speak / grounding), star placed, tapping the Personalize entry point
- **Alarm follow-through**: whether a follow-up alarm was armed and reached
  you, whether a ritual was left unfinished, and whether a completed ritual was
  spoken or typed
- **Affirmation engagement**: which affirmations were shown, skipped, dwelled
  on, saved, or unsaved, and how long they were on screen

Each event carries only the **anonymous per-install identifier**, the event name, a timestamp, and — where noted above — a short label such as the stage you stopped at or whether you spoke or typed. **No third-party analytics SDK is used** — these events go directly to our own Supabase database, never to Google Analytics, Mixpanel, Amplitude, or any other behavioral analytics vendor. The events contain **no name, no voice, no transcript, no affirmation text you wrote, no advertising identifier, and no device serial.**

We use this data to answer one question: do people repeat the ritual, and where do they drop off? It is not used for advertising or sale.

## 2. Information We Do NOT Collect

- We do **not** ask for or store your name, email address, or any account
- We do **not** receive your payment details, card number, or purchase history
- We do **not** have access to the affirmations you save — they live in your private iCloud
- We do **not** use any third-party behavioral analytics SDK (no Google Analytics, no Mixpanel, no Amplitude, no Firebase Analytics)
- We do **not** use advertising SDKs or tracking
- We do **not** collect device identifiers for advertising (IDFA)
- We do **not** access your contacts, photos, location, or health data
- We do **not** record or transmit audio
- We do **not** transmit your calendar events off your device
- We do **not** send your personal information to any AI or machine-learning service

## 3. How We Use Your Information

We use the information we collect to:
- Keep your saved affirmations available across your own devices
- Understand whether the ritual works, so we can improve it
- Find and fix crashes
- Provide the subscription you purchased

We do not use it for advertising, and we do not sell it.

## 4. Third-Party Services

We use the following third-party services to operate Casting:

- **Apple (iCloud / CloudKit)** — stores your saved affirmations in your own private database, which we cannot access. Apple also processes all subscription payments. See [Apple's privacy policy](https://www.apple.com/legal/privacy/).
- **Supabase** — hosts our affirmation library and receives the anonymous usage events described above. See [Supabase's privacy policy](https://supabase.com/privacy).
- **Sentry** — receives crash reports and performance diagnostics so we can fix bugs quickly. No PII, no advertising, no behavioral tracking. See [Sentry's privacy policy](https://sentry.io/privacy/).

We do not share your information with any other third parties for marketing, advertising, or behavioral analytics.

## 5. Data Retention

Anonymous usage events tied to your per-install identifier are retained while
they remain useful for the purposes described above. Deleting the App resets
your identifier, which disconnects you from the events already recorded.

Your saved affirmations are held in your own private iCloud database and are
retained until you delete them. Because we cannot access that database, removing
them is done from within the App or through your iCloud settings — we cannot do
it on your behalf.

To request deletion of anonymous usage events already recorded, contact us at the
address below. Because we have no account system, we may need your help
identifying the right records.

## 6. Your Rights

You have the right to:
- Access the data we hold about you
- Correct inaccurate data
- Request deletion of your data
- Export your data

To exercise any of these rights, email us at [satanclaous@gmail.com](mailto:satanclaous@gmail.com). We will respond within 30 days.

## 7. Children's Privacy

Casting is not intended for children under 13. We do not knowingly collect personal information from children under 13. If we learn that we have collected such information, we will delete it.

## 8. Security

We use industry-standard security practices (encrypted connections, encrypted data at rest where supported by our service providers) to protect your information. No method of transmission over the internet is 100% secure, but we work to keep your data safe.

## 9. Changes to This Policy

If we make material changes to this Privacy Policy, we will notify you in the App and update the "Last updated" date above. Continued use of the App after changes means you accept the updated policy.

## 10. Contact

If you have questions about this Privacy Policy or your data, contact us at:

**Email**: [satanclaous@gmail.com](mailto:satanclaous@gmail.com)
