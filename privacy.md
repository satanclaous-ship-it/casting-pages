---
title: Privacy Policy
permalink: /privacy/
---

# Privacy Policy

**Effective: October 11, 2026** · **Previous version: effective May 10, 2026**

> This policy is also published at https://getcasting.app/en/privacy/ — operated by CheonJiIn (천지인).

CheonJiIn (천지인, “we”) operates the Casting iPhone app (“the App”) and the getcasting.app website (“the Site”), and builds them to handle as little personal information as possible. We do not sell your data, we use no third-party advertising or behavioral analytics SDKs, and we do not send voice recordings to any server. This policy explains, in line with South Korea’s Personal Information Protection Act, what we process and why, how long we keep it, who processes it for us (including outside Korea), and how you can exercise your rights.

## 1. Who is responsible

- Business: CheonJiIn (천지인) — sole proprietorship in South Korea, business registration no. 708-32-01900
- Representative and privacy officer: Jung Hoon Han (한정훈)
- Email: junghoon@getcasting.app (questions and access/deletion requests)

## 2. No account, and the per-install identifier

The version of the App being prepared for release has no sign-up and does not collect your name, email address or account credentials. What we do handle is tied to an anonymous per-install identifier created at random on your device when you first open the App; deleting the App resets it.

## 3. Purposes, data collected and retention

We do not collect payment information, voice, your name, contacts, location, photos or health data.

- Providing alarms and the ritual — alarm settings, progress and completion history, the affirmations shown: stored only on your iPhone; we do not collect them.
- Improving the service (learning whether the ritual becomes a habit) — the anonymous identifier and usage events: collected automatically while you use the App and kept while they remain useful for this purpose.
- Fixing crashes — device model, OS and app version, and the stack trace at the time of a crash: collected automatically when a crash happens and kept while needed to fix it.
- Answering your messages — your email address and message: collected when you email us and deleted promptly once handled (unless a law requires us to keep it).
- Composing personal affirmations (in development, see section 8) — the text of answers you enter in the interview: processed only if you consent.

## 4. What stays on your device

The following never leaves your iPhone and we cannot see it.

- Alarm times, recurrence and sound settings
- Ritual progress and completion history
- The affirmations shown during the ritual
- Voice: the microphone is used only to listen while you speak an affirmation, processed on-device by Apple’s speech recognition. We do not record, store or transmit your voice.
- Calendar (optional): if you allow it, only the titles of upcoming events are read on the device to show your day; nothing is transmitted.

## 5. Saved affirmations — your private iCloud

When you save an affirmation it is stored in your own private iCloud (CloudKit) database under your Apple Account. Only you can reach it; we cannot read, list or delete it.

## 6. Subscription payments

Paid subscriptions are handled entirely by Apple. We never receive your payment method, card number, billing address or Apple Account; the App only asks your device whether an active subscription exists.

## 7. Anonymous usage events and crash diagnostics

The App records a small set of events with the anonymous per-install identifier to our own Supabase database (app opened, alarm set or fired, ritual started or finished or the stage where it stopped, whether an affirmation was shown or saved, whether a ritual was spoken or typed, and similar). These events contain no name, voice, transcript, text you wrote, or advertising identifier.

We use Sentry for crash diagnostics only: stack trace, device model, OS and app version. It contains no personal identifiers and nothing you wrote or said.

## 8. AI features — “Words that know you” (in development)

“Words that know you” is a feature under development and is not part of the version being prepared for release. Before it ships we will update this policy and tell you in the App. The current design is:

- The text of answers you type or dictate into the interview is sent to Anthropic, PBC’s Claude API to help compose your personal affirmations.
- Before your first answer is sent, we tell you it goes to an AI service and ask for your explicit consent.
- Your voice is not sent. The App holds no API key; it calls a server function operated by us.
- In this feature, the text you enter passes through our server to Anthropic.

## 9. The Site, and cookies

The Site has no cookies, sign-up, login, advertising or analytics tools and does not collect behavioral data. It is served through Cloudflare, which may process ordinary connection records such as IP addresses to run the web service. If you email us, we use the address and message you send to reply.

## 10. Processors and processing outside Korea

We use the providers below to run the service and do not give personal information to third parties for advertising, marketing or sale. These providers process data outside South Korea.

- Supabase — stores the anonymous identifier and usage events and serves affirmation content. Storage region: Australia (Sydney). Sent over an encrypted connection while you use the App.
- Sentry — crash diagnostics (device model, OS and app version, stack trace). Processing region: United States. Sent over an encrypted connection when a crash happens.
- Cloudflare — serves the Site. Connection records (such as IP addresses) are processed on its global network.
- Apple (iCloud/CloudKit, subscription payments) — stores saved affirmations and handles payment under Apple’s own privacy policy; we cannot access that data.
- Anthropic, PBC — processes interview text you consented to send in the AI feature under development. Processing region: United States. Not applicable before that feature ships.

## 11. Retention and deletion

Anonymous usage events are kept while they remain useful for the purposes above; deleting the App resets your identifier so later events are not linked to it. If you ask us to delete recorded events, we will irreversibly delete them where we can identify them, within 30 days. Because there is no account system, we may ask for your help finding the right records.

## 12. Your rights and how to use them

You may ask to access, correct, delete or restrict processing of your data, or withdraw consent. Email junghoon@getcasting.app; after verifying it is you, we reply within 30 days. A legal guardian or an authorized representative may also make the request.

## 13. Children

Casting is not directed at children under 14, and we do not knowingly collect their personal information. If we learn we have, we delete it.

## 14. Security measures

- Data is transmitted only over encrypted connections (HTTPS).
- Stored data is encrypted where our providers support it.
- Voice and most usage records are kept on your device instead of being sent to a server, which keeps what we hold small.
- Secrets such as API keys live on the server, not in the App, and access to them is limited to what is necessary.

## 15. Remedies for privacy violations

If you need to report or seek advice about a privacy violation in South Korea, you can contact:

- Personal Information Infringement Report Center (privacy.kisa.or.kr, dial 118)
- Personal Information Dispute Mediation Committee (kopico.go.kr, 1833-6972)
- Supreme Prosecutors’ Office (spo.go.kr, dial 1301)
- Korean National Police Agency Cyber Bureau (ecrm.police.go.kr, dial 182)

## 16. Changes to this policy

If this policy changes in a material way, we will update the effective date and tell you in the App.

---

[한국어](/casting-pages/privacy-ko/)
