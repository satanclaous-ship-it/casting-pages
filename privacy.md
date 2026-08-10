---
title: Privacy Policy
permalink: /privacy/
---

# Privacy Policy

**Effective date**: May 10, 2026
**Last updated**: August 10, 2026 (v1.0 accuracy pass — removed the account/email
section, since v1.0 ships with no sign-in; disclosed Google Gemini as the
provider that generates personalized affirmations; disclosed affirmation
engagement events and device attestation)

This Privacy Policy describes how Casting ("we," "us," or "our") collects, uses, and protects your information when you use the Casting iOS app ("the App").

We designed Casting to do the absolute minimum needed to make the ritual work. We do not sell your data. We do not use third-party advertising or behavioral analytics SDKs. We do not transmit your voice recordings to any server.

## 1. Information We Collect

### No account, no email

**Casting has no sign-in.** We do not collect your name, your email address, or
any account credentials. Everything below is tied to an anonymous per-install
identifier — a random value created when you first open the App and stored on
your device. Deleting the App resets it.

Because there is no account, your data does not follow you to a new phone. That
is a deliberate trade for not asking you to register.

### App data

- Which affirmations you save (stored as identifiers — the affirmation text
  itself is part of our shared library, not something we store about you)
- Ritual completion records (which ritual stages you reached, and when)
- Alarm and ritual settings you configure

This is stored on Supabase, our backend, under the anonymous identifier above.

### Personalized affirmations (only if you use the feature)

If you ask the App to generate affirmations for you, the short description you
write about yourself is sent to our server and on to **Google Gemini**, which
generates the affirmations. We also send a summary of the *kinds* of
affirmations you have saved, so the results match your taste — this summary is
calculated on your device and is not stored on our servers.

The affirmations Gemini returns are stored **only on your device**. Your
description is not saved to our database; it is used to fulfil the request and
is retained on your device so you do not have to retype it.

If you never use this feature, nothing in this section applies to you.

### Voice

Casting requires microphone access to listen for spoken affirmations during the ritual. Voice processing happens **entirely on your device** using Apple's on-device speech recognition. **We do not record, store, or transmit your voice to any server.** Voice data never leaves your iPhone.

### Calendar (optional)

If you grant calendar access, Casting reads your **upcoming event titles only** to craft affirmations that match what your day actually holds. We do not read attendees, notes, locations, descriptions, recurrence rules, or past events. **Calendar data is processed entirely on your device and never transmitted to our servers.** You can deny or revoke calendar access at any time in iOS Settings — the App still works without it.

### Crash and performance diagnostics

We use **Sentry** for crash and performance monitoring only. When the App crashes or encounters an unhandled error, Sentry sends a diagnostic report containing the stack trace, device model, OS version, and App version. This report contains **no personal information, no behavioral analytics, no advertising identifiers, and no content you wrote or spoke**, and is not joined to the identifier used elsewhere in this policy. It is used solely to find and fix bugs. See [Sentry's privacy policy](https://sentry.io/privacy/).

### Anonymous usage events

To understand whether the ritual is actually forming a daily habit for real users, the App records a small set of anonymous events to our own Supabase backend:

- **Lifecycle**: app opened, onboarding completed, alarm set, alarm fired,
  ritual started, ritual completed or the stage you stopped at (trap / prep /
  speak / grounding), star placed, tapping the Personalize entry point
- **Affirmation engagement**: which affirmations were shown, skipped, dwelled
  on, saved, or unsaved, and how long they were on screen

Each event carries only the **anonymous per-install identifier** and a timestamp. **No third-party analytics SDK is used** — these events go directly to our own Supabase database, never to Google Analytics, Mixpanel, Amplitude, or any other behavioral analytics vendor. The events contain **no name, no voice, no transcript, no affirmation text you wrote, no advertising identifier, and no device serial.**

We use this data to answer one question: do people repeat the ritual, and where do they drop off? It is not used for advertising or sale.

### Device attestation

When you generate personalized affirmations, your device produces a
cryptographic key held in its secure hardware, which proves the request came
from a genuine copy of Casting. We store the key's public identifier. It
contains no personal information, is not connected to your Apple ID, and exists
only to prevent abuse of a feature that costs us money on every use.

## 2. Information We Do NOT Collect

- We do **not** ask for or store your name, email address, or any account
- We do **not** use any third-party behavioral analytics SDK (no Google Analytics, no Mixpanel, no Amplitude, no Firebase Analytics)
- We do **not** use advertising SDKs or tracking
- We do **not** collect device identifiers for advertising (IDFA)
- We do **not** access your contacts, photos, location, or health data
- We do **not** record or transmit audio
- We do **not** transmit your calendar events off your device
- We do **not** store the affirmations generated for you, or the description you
  wrote to generate them, on our servers

## 3. How We Use Your Information

We use the information we collect to:
- Give you back the affirmations you saved, and remember where you are in the ritual
- Generate personalized affirmations when you ask for them
- Understand whether the ritual works, so we can improve it
- Find and fix crashes
- Prevent abuse of features that cost us money to run

We do not use it for advertising, and we do not sell it.

## 4. Third-Party Services

We use the following third-party services to operate Casting:

- **Supabase** — hosts our database and backend. See [Supabase's privacy policy](https://supabase.com/privacy).
- **Google Gemini** — generates personalized affirmations from the description
  you provide, when you use that feature. See [Google's privacy policy](https://policies.google.com/privacy).
- **Sentry** — receives crash reports and performance diagnostics so we can fix bugs quickly. No PII, no advertising, no behavioral tracking. See [Sentry's privacy policy](https://sentry.io/privacy/).

We do not share your information with any other third parties for marketing, advertising, or behavioral analytics.

## 5. Data Retention

Data tied to your anonymous identifier is retained while it remains useful for
the purposes described above. Deleting the App resets your identifier, which
disconnects you from the data already collected.

To request deletion of data already collected, contact us at the address below.
Because we have no account system, we may need your help identifying the right
records.

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
