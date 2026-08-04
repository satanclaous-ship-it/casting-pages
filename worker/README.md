# 30분 기록 — 푸시 서버 (Cloudflare Worker)

**이건 선택 사항이야.** 앱은 서버 없이도 완전히 동작해 (아래 "알람 3중 안전장치" 참고).
이 Worker를 배포하면 **브라우저를 완전히 종료해도** 서버가 시간 맞춰 푸시를 쏴줘 —
아이폰에서 홈 화면에 추가한 PWA(iOS 16.4+)도 포함.

무료 플랜 안에서 충분히 돌아가. Cron이 1분마다 도니까 하루 1,440번 실행 + 구독 수만큼 KV 읽기.

---

## 배포 (5분)

```bash
cd worker
npm i -g wrangler            # 이미 있으면 생략
wrangler login

# 1. 구독 저장용 KV 네임스페이스
wrangler kv namespace create SUBS
#    → 출력된 id를 wrangler.toml의 REPLACE_WITH_YOUR_KV_NAMESPACE_ID 자리에 붙여넣기

# 2. VAPID 키 한 쌍 생성
node gen-vapid.mjs
#    → 공개키는 wrangler.toml [vars]에 VAPID_PUBLIC_KEY = "..." 로 추가
#    → 개인키는 secret으로:
wrangler secret put VAPID_PRIVATE_KEY

# 3. 배포
wrangler deploy
```

배포되면 `https://min30-push.<계정>.workers.dev` 주소가 나와.
앱 → **설정 → 푸시 서버**에 그 주소를 넣고 **푸시 구독하기**를 누르면 끝.

> ⚠️ 아이폰은 반드시 **홈 화면에 추가한 상태**여야 웹 푸시가 와. Safari 탭에서는 안 와.
> iOS 16.4 이상 필요.

---

## API

| 메서드 | 경로 | 하는 일 |
|---|---|---|
| `GET` | `/vapid` | 공개키 반환 — 앱이 구독할 때 씀 |
| `POST` | `/subscribe` | 구독 + 스케줄(간격·기상시간·타임존) 저장 |
| `POST` | `/unsubscribe` | `{ endpoint }` 로 구독 삭제 |
| `POST` | `/test` | `{ endpoint }` 로 지금 즉시 한 발 |

Cron(`* * * * *`)이 매분 깨어나서 각 구독의 **자기 타임존 기준** 로컬 시각을 계산하고,
블록 경계에 걸리면 푸시를 보내. 브라우저가 구독을 버리면(404/410) KV에서 자동으로 지워.

---

## 동작 원리

- **VAPID (RFC 8292)** — ES256 JWT로 푸시 서비스에 신원 증명
- **페이로드 암호화 (RFC 8291, `aes128gcm`)** — 매번 새 ECDH 키쌍 → HKDF → AES-128-GCM.
  푸시 서비스는 내용을 못 읽고, 기기에서만 복호화돼.

의존성 없음. 전부 WebCrypto로 구현.

---

## 알람 3중(+1) 안전장치

Worker 없이도 이 순서로 알람이 울려:

1. **예약 알림 (Notification Triggers)** — 앱을 완전히 꺼도 OS가 쏨. Chrome/Android.
2. **브라우저 알림** — 탭이 살아 있을 때. 전 브라우저.
3. **캘린더 알람 (.ics)** — 설정에서 내려받아 캘린더에 넣으면 OS가 상시 울림.
   **아이폰에서 서버 없이 쓰는 가장 확실한 방법.**
4. **서버 푸시** — 이 Worker. 앱을 꺼도, 어떤 기기든.

그리고 어떤 알람을 놓쳐도 앱을 열면 **밀린 블록**을 잡아서 채우라고 알려줘.
