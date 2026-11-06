---
title: Privacy Policy
permalink: /privacy/
---

# Privacy Policy

**Effective: November 6, 2026** · **Previous version: effective November 3, 2026**

> This policy is also published at https://getcasting.app/privacy/ — operated by CheonJiIn (천지인).

CheonJiIn (천지인, “we”) operates the Casting iPhone app (“the App”) and the getcasting.app website (“the Site”), and builds them to handle as little personal information as possible. We do not sell your data, we use no third-party advertising or behavioral analytics SDKs, and we do not send voice recordings to any server. This policy explains, in line with South Korea’s Personal Information Protection Act, what we process and why, how long we keep it, who processes it for us (including outside Korea), and how you can exercise your rights.

## 1. Who is responsible

- Business: CheonJiIn (천지인) — sole proprietorship in South Korea, business registration no. 708-32-01900
- Representative and privacy officer: Jung Hoon Han (한정훈)
- Email: jung@getcasting.app (questions and access/deletion requests)

## 2. No account, your nickname, and per-install identifiers

App Store version 1.4 has no sign-up or login and does not collect your email address, phone number or account credentials. On the last screen of “Clearing the unconscious” (the belief finder) the App asks for a nickname to call you by; it does not need to be your real name.

What we handle is tied to identifiers created on your device: a random per-install record id (starting with “cast_”) and the device identifier Apple gives each app vendor. Deleting and reinstalling the App creates a new record id.

## 3. Purposes, data collected and retention

We do not collect payment information, voice recordings, your real name, contacts, location, photos or health data.

- Providing alarms and the ritual — alarm settings and ritual progress and completion history: stored on your iPhone. What is listed under “Belief finder and ritual records” below is also kept on our server.
- Belief finder and ritual records (section 8) — your nickname, record id, the answers you choose or write in “Clearing the unconscious” (the scene, where you feel it in the body, feelings, the old and the new belief, and similar), and what you choose or write in the morning and evening rituals (how you felt before and after, today’s action, what you write looking back on the day, and similar): sent to our server when you finish the belief finder and when you finish a morning or evening ritual. Used to make suggestions and guidance that fit you and to improve the service; kept while we provide the service and deleted when you ask.
- Making AI suggestions (section 8) — the parts of those answers and records a suggestion needs: sent to Anthropic from the screens that make suggestions; our server only relays the request.
- The Galaxy (section 9) — your nickname, the lines you post, reactions, and report/block records: sent when you post or tap, and kept until you take a post down or ask us to delete it.
- Improving the service (learning whether the ritual becomes a habit) — the device identifier and usage events: collected automatically while you use the App and kept while they remain useful for this purpose.
- Fixing crashes — device model, OS and app version, and the stack trace at the time of a crash: collected automatically when a crash happens and kept while needed to fix it.
- Answering your messages — your email address and message: collected when you email us and deleted promptly once handled (unless a law requires us to keep it).
- In-app requests (“Ask the Developer” in Settings) — the request you write, app and OS version, device model, language setting and a random per-install tag: collected only when you tap Send, delivered to our mailbox, and deleted promptly once handled. We do not receive your name or contact details.

## 4. What stays on your device

The following never leaves your iPhone and we cannot see it.

- Alarm times, recurrence and sound settings
- Voice: the microphone is used only when you choose “Out loud” to say a line instead of typing it; Apple’s on-device dictation turns it into text on the device. We do not record, store or transmit your voice. The dictated text joins your ritual record just like typed text.
- Pausing before an app opens (Screen Time, optional): if you turn it on in Settings → “Before an app opens” and pick apps, the App uses Apple’s Screen Time (Family Controls) permission to show a short breathing screen in front of them. Apple handles the chosen apps and their usage only on the device; we cannot see which apps you chose or how you use them.
- Calendar (optional): if you allow it, only the titles of upcoming events are read on the device to show your day; nothing is transmitted.

## 5. Saved affirmations — your private iCloud

When you save an affirmation it is stored in your own private iCloud (CloudKit) database under your Apple Account. Only you can reach it; we cannot read, list or delete it.

## 6. Payments

App Store version 1.4 has no in-app purchases. When paid subscriptions arrive, payment is handled entirely by Apple; we never receive your payment method, card number, billing address or Apple Account.

## 7. Usage events and crash diagnostics

The App records a small set of events with the device identifier to our own Supabase database (app opened, alarm set or fired, ritual started or finished or the stage where it stopped, whether an affirmation was shown or saved, whether a ritual was spoken or typed, and similar). These events contain no name, voice, transcript, text you wrote, or advertising identifier.

We use Sentry for crash diagnostics only: stack trace, device model, OS and app version. It contains no personal identifiers and nothing you wrote or said.

## 8. AI features — clearing the unconscious and ritual suggestions

“Clearing the unconscious” (the belief finder) and the morning and evening rituals show suggestions built from your answers — a new belief, today’s action, something for your evening. They are made like this:

- The answers you write or choose in “Clearing the unconscious” (the scene, the problem, where you feel it in the body, feelings, the old belief, fears, direction, and similar) and what you write or choose in the rituals (the new belief, actions, how you felt before and after, what you write looking back on the day, a summary of the last seven days) pass through a server we operate (Cloudflare Workers) to Anthropic, PBC’s Claude API. Your nickname and record id are not sent to Anthropic.
- In this version the ritual opens after you finish “Clearing the unconscious”, and there is no separate setting that turns this sending off. If you do not want it, do not start “Clearing the unconscious”; you can ask us to delete what was already sent (section 13). Settings → Your Data → “AI sharing” → “Stop Sharing” applies only to the interview feature, which this version does not use.
- Without a network connection or an answer, the App falls back to built-in lists and no suggestion request is sent.
- Your voice is not sent. The App holds no API key.
- Anthropic’s handling and retention of the text it receives are governed by its commercial terms and privacy policy (anthropic.com/legal/commercial-terms, anthropic.com/legal/privacy); we do not control that retention.
- The belief finder and ritual records kept on our server (section 3) can be read by our operator and are used only for guidance that fits you and to improve the service.
- Text you enter in our web prototypes (the interview and the belief finder) passes through our server to Anthropic in the same way.

## 9. The Galaxy — a place shared with other users

“My journey” → “Galaxy” is where people using Casting see and cheer each other’s lines. You pass a promise screen the first time you enter.

- What goes up: your nickname; the morning “the me who does it” line and the evening “what filled today” line (when “Share to the galaxy too” is on for that screen); a mark that you finished a ritual; and your reactions to others’ posts (Cheering you on · Congratulations · Me too) with your nickname. Posts and nicknames are visible to other users who enter the Galaxy.
- “Share to the galaxy too” starts on and can be turned off on the screen where you write the line.
- Other users never see your record id, only a transformed value.
- Reporting and blocking: each post’s “…” menu offers “Report”, “Stop seeing this person” and “Hide”. A reported post is hidden at once and the operator reviews it within 24 hours. Posts containing rough words are refused by the server. You can remove your own post at any time with “Take my post down”.
- Galaxy posts are kept on our server (Cloudflare) and deleted when you take them down or ask us to delete them.

## 10. The Site, and cookies

The Site has no cookies, sign-up, login, advertising or analytics tools and does not collect behavioral data. It is served through Cloudflare, which may process ordinary connection records such as IP addresses to run the web service. If you email us, we use the address and message you send to reply.

## 11. Processors and processing outside Korea

We use the providers below to run the service and do not give personal information to third parties for advertising, marketing or sale. These providers process data outside South Korea.

- Supabase — stores the device identifier and usage events and serves affirmation content. Storage region: Australia (Sydney). Sent over an encrypted connection while you use the App.
- Sentry — crash diagnostics (device model, OS and app version, stack trace). Processing region: United States. Sent over an encrypted connection when a crash happens.
- Cloudflare — serves the Site, relays in-app requests as email, stores belief finder and ritual records and Galaxy posts (Workers · KV), and relays AI suggestion requests. Processed on its global network over encrypted connections.
- Apple (iCloud/CloudKit, Screen Time) — stores saved affirmations and runs the breathing screen under Apple’s own privacy policy; we cannot access that data.
- Anthropic, PBC — processes the text used to make suggestions in “Clearing the unconscious” and the rituals (section 8), and text entered in our web prototypes. Processing region: United States. Sent over an encrypted connection when a suggestion is made.

## 12. Retention and deletion

Usage events are kept while they remain useful for the purposes above. Belief finder and ritual records and Galaxy posts are kept while we provide the service. If you ask us to delete your data, we will irreversibly delete it where we can identify it, within 30 days. Because there is no account system, we may ask for your record id (at the bottom of “My day” → “Belief” → “Edit my sentences”) or your nickname to find it.

## 13. Your rights and how to use them

You may ask to access, correct or delete your data or to restrict its processing. Email jung@getcasting.app or use “Ask the Developer” in the App; after verifying it is you, we reply within 30 days. A legal guardian or an authorized representative may also make the request.

## 14. Children

Casting is not directed at children under 14, and we do not knowingly collect their personal information. If we learn we have, we delete it.

## 15. Security measures

- Data is transmitted only over encrypted connections (HTTPS).
- Stored data is encrypted where our providers support it.
- Your voice is turned into text on the device instead of being sent to a server, which keeps what we hold small.
- Secrets such as API keys live on the server, not in the App, and access to them is limited to what is necessary.

## 16. Remedies for privacy violations

If you need to report or seek advice about a privacy violation in South Korea, you can contact:

- Personal Information Infringement Report Center (privacy.kisa.or.kr, dial 118)
- Personal Information Dispute Mediation Committee (kopico.go.kr, 1833-6972)
- Supreme Prosecutors’ Office (spo.go.kr, dial 1301)
- Korean National Police Agency Cyber Bureau (ecrm.police.go.kr, dial 182)

## 17. Changes to this policy

If this policy changes in a material way, we will update the effective date and tell you in the App.

---

[한국어](/casting-pages/privacy-ko/)
