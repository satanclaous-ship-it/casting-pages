#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# 30분 기록 — 맥북 셋업 + 빌드 진단
#
#   curl -fsSL https://raw.githubusercontent.com/satanclaous-ship-it/casting-pages/claude/30min-activity-tracker-5z988y/min30-ios/setup-mac.sh | bash
#
# 하는 일: 저장소를 최신으로 받고, 컴파일을 확인하고, 연결된 아이폰이 있으면
# 서명해서 설치까지 한다. 에러가 나면 사람이 읽을 수 있게 정리해 준다.
# 아무것도 자동으로 설치하지 않는다 — 필요하면 물어본다.
# ══════════════════════════════════════════════════════════════════
set -uo pipefail

REPO_URL="https://github.com/satanclaous-ship-it/casting-pages.git"
BRANCH="claude/30min-activity-tracker-5z988y"
DEST="${MIN30_DIR:-$HOME/min30}"
PROJ_DIR="$DEST/min30-ios"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
info() { printf '  · %s\n' "$1"; }

bold $'\n▶ 1/5  환경 확인'

if [[ "$(uname -s)" != "Darwin" ]]; then
  bad "맥이 아니에요 ($(uname -s)). 이 스크립트는 macOS 전용이에요."
  exit 1
fi
ok "macOS $(sw_vers -productVersion)"

if ! xcode-select -p >/dev/null 2>&1; then
  bad "Xcode 커맨드라인 도구가 없어요."
  info "터미널에 이걸 실행하고 설치가 끝나면 이 스크립트를 다시 돌려주세요:"
  info "    xcode-select --install"
  exit 1
fi
ok "커맨드라인 도구: $(xcode-select -p)"

if ! command -v xcodebuild >/dev/null 2>&1; then
  bad "xcodebuild 를 찾을 수 없어요. App Store 에서 Xcode 를 설치해 주세요."
  exit 1
fi
XC_VER="$(xcodebuild -version 2>/dev/null | head -1)"
if [[ -z "$XC_VER" ]]; then
  bad "Xcode 가 설치돼 있지만 선택되지 않았어요."
  info "이걸 한 번 실행해 주세요:"
  info "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi
ok "$XC_VER"

bold $'\n▶ 2/5  소스 받기'

if [[ -d "$DEST/.git" ]]; then
  info "이미 있어요 → 최신으로 갱신"
  # FETCH_HEAD 로 맞춘다. 얕은 클론이면 origin/<branch> 가 갱신 안 될 수 있다.
  git -C "$DEST" fetch origin "$BRANCH" --quiet 2>/dev/null \
    && git -C "$DEST" checkout -B "$BRANCH" --quiet FETCH_HEAD 2>/dev/null \
    && ok "갱신 완료: $DEST" \
    || { bad "갱신 실패 — 인터넷 연결이나 $DEST 상태를 확인해 주세요."; exit 1; }
else
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$DEST" --quiet 2>/dev/null \
    && ok "받았어요: $DEST" \
    || { bad "clone 실패 — 인터넷 연결을 확인해 주세요."; exit 1; }
fi

# 어떤 코드로 빌드하는지 눈에 보이게 — "돌렸는데 그대로" 를 진단할 수 있어야 한다
info "현재 커밋: $(git -C "$DEST" log -1 --format='%h %s' | cut -c1-70)"

cd "$PROJ_DIR" || { bad "$PROJ_DIR 가 없어요."; exit 1; }
info "$(find Min30 -name '*.swift' | wc -l | tr -d ' ')개 Swift 파일"

bold $'\n▶ 3/5  프로젝트 파일 확인'

# .pbxproj 는 손으로 작성한 것이라 Xcode 가 거부할 수 있다. 그러면 XcodeGen 으로 다시 만든다.
if xcodebuild -project Min30.xcodeproj -list >/dev/null 2>&1; then
  ok "Min30.xcodeproj 정상"
else
  bad "Min30.xcodeproj 를 Xcode 가 읽지 못해요 — XcodeGen 으로 다시 만들게요."
  if command -v xcodegen >/dev/null 2>&1; then
    :
  elif command -v brew >/dev/null 2>&1; then
    printf '\n  XcodeGen 을 설치할까요? (brew install xcodegen) [y/N] '
    read -r ans </dev/tty
    [[ "$ans" =~ ^[Yy]$ ]] || { info "건너뜁니다. 수동: brew install xcodegen && xcodegen generate"; exit 1; }
    brew install xcodegen || { bad "설치 실패"; exit 1; }
  else
    bad "Homebrew 가 없어요. https://brew.sh 설치 후 'brew install xcodegen' 해주세요."
    exit 1
  fi
  rm -rf Min30.xcodeproj
  xcodegen generate && ok "프로젝트 재생성 완료" || { bad "재생성 실패"; exit 1; }
fi

bold $'\n▶ 4/5  컴파일 확인'

LOG="$PROJ_DIR/build.log"
info "시뮬레이터용으로 빌드 중… (처음엔 1~2분 걸려요)"

xcodebuild \
  -project Min30.xcodeproj \
  -target Min30 \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build > "$LOG" 2>&1
BUILD_RC=$?

# 에러만 뽑아 사람이 읽을 수 있게 정리
REPORT="$PROJ_DIR/build-errors.txt"
grep -E "error:|warning: .*(deprecated|will never be executed)" "$LOG" \
  | sed "s|$PROJ_DIR/||g" \
  | sort -u > "$REPORT"
ERR_N=$(grep -c "error:" "$REPORT" 2>/dev/null || echo 0)

echo
if [[ $BUILD_RC -eq 0 ]]; then
  bold '✅ 컴파일 성공'
  info "여기까지는 시뮬레이터용 확인일 뿐이에요 — 아직 폰엔 아무것도 안 올라갔어요."

  # ── 연결된 아이폰이 있으면 실제로 설치까지 한다 ──────────────
  bold $'\n▶ 5/5  아이폰에 설치'

  # 무선 기기는 발견되는 데 몇 초 걸린다. 케이블이면 첫 시도에 바로 잡힌다.
  DEV_JSON="$(mktemp)"
  FOUND=""
  for attempt in 1 2 3; do
    xcrun devicectl list devices --timeout 15 --json-output "$DEV_JSON" >/dev/null 2>&1 || true
    FOUND="$(python3 - "$DEV_JSON" <<'PY' 2>/dev/null || true
import json, sys

try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)

cands = []
for dev in d.get("result", {}).get("devices", []):
    hw   = dev.get("hardwareProperties", {})
    if hw.get("platform") not in ("iOS", "iPadOS"):
        continue
    props = dev.get("deviceProperties", {})
    conn  = dev.get("connectionProperties", {})
    udid  = dev.get("identifier", "")
    if not udid:
        continue
    transport = conn.get("transportType", "")          # wired | localNetwork
    tunnel    = conn.get("tunnelState", "")            # connected | connecting | unavailable
    paired    = conn.get("pairingState", "")           # paired | ...
    # 연결이 살아 있는 것 우선, 그다음 유선, 그다음 무선.
    score = (
        0 if tunnel == "connected" else 1 if tunnel == "connecting" else 2,
        0 if transport == "wired" else 1,
    )
    cands.append((score, udid, props.get("name", "iPhone"), transport, tunnel, paired))

if not cands:
    sys.exit(0)
cands.sort()
_, udid, name, transport, tunnel, paired = cands[0]
print("\t".join([udid, name, transport, tunnel, paired]))
PY
)"
    [[ -n "$FOUND" ]] && break
    [[ $attempt -lt 3 ]] && { info "기기를 찾는 중… ($attempt/3)"; sleep 4; }
  done
  rm -f "$DEV_JSON"

  UDID="$(cut -f1 <<<"$FOUND")"
  DEV_NAME="$(cut -f2 <<<"$FOUND")"
  DEV_TRANSPORT="$(cut -f3 <<<"$FOUND")"
  DEV_TUNNEL="$(cut -f4 <<<"$FOUND")"

  # 서명에 쓸 팀 ID 를 키체인의 개발자 인증서에서 뽑는다
  TEAM="$(security find-identity -v -p codesigning 2>/dev/null \
          | grep -o '(\([A-Z0-9]\{10\}\))' | head -1 | tr -d '()')"

  if [[ -z "$UDID" ]]; then
    bad "아이폰을 못 찾았어요."
    echo
    info "무선으로 쓰려면 한 번만 준비가 필요해요 (케이블이 필요한 유일한 순간):"
    info "  1. 아이폰을 케이블로 연결"
    info "  2. Xcode → Window → Devices and Simulators (⇧⌘2)"
    info "  3. 왼쪽에서 기기 선택 → 'Connect via network' 체크"
    info "  4. 케이블 뽑기. 이후로는 같은 와이파이면 무선으로 잡혀요."
    echo
    info "이미 해뒀다면: 아이폰 잠금을 풀고 화면을 켠 채로 다시 돌려 주세요."
    info "(잠긴 기기는 무선으로 응답하지 않아요)"
  elif [[ -z "$TEAM" ]]; then
    bad "개발자 서명 인증서를 못 찾았어요 (첫 설치라면 정상)."
    info "Xcode 에서 한 번만 설정해 주세요:"
    info "  왼쪽 Min30 클릭 → Signing & Capabilities → Team 을 본인 Apple ID 로"
    info "  그다음 ⌘R. 한 번 해두면 이후로는 이 스크립트가 알아서 설치해요."
  else
    case "$DEV_TRANSPORT" in
      wired)        LINK="케이블" ;;
      localNetwork) LINK="와이파이" ;;
      *)            LINK="$DEV_TRANSPORT" ;;
    esac
    info "기기: ${DEV_NAME:-iPhone}  ·  연결: $LINK  ·  팀: $TEAM"
    if [[ "$DEV_TRANSPORT" == "localNetwork" ]]; then
      info "무선이라 설치가 조금 느려요. 아이폰 잠금을 풀어 두세요."
    fi
    info "서명해서 빌드 중…"
    if xcodebuild \
        -project Min30.xcodeproj \
        -scheme Min30 \
        -configuration Debug \
        -destination "platform=iOS,id=$UDID" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$TEAM" \
        -derivedDataPath ./.dd \
        build > device-build.log 2>&1
    then
      APP="$(find ./.dd/Build/Products -maxdepth 2 -name 'Min30.app' -type d 2>/dev/null | head -1)"
      info "설치 중…"
      if [[ -n "$APP" ]] && xcrun devicectl device install app \
           --device "$UDID" "$APP" > install.log 2>&1; then
        bold $'\n🎉 폰에 설치했어요'
        ok "홈 화면에서 '30분 기록' 을 열어 보세요"
        info "처음이면: 설정 → 일반 → VPN 및 기기 관리 → 본인 Apple ID → 신뢰"
      else
        bad "빌드는 됐는데 설치가 안 됐어요."
        grep -iE "error|denied|locked|unavailable|timed out" install.log 2>/dev/null | head -6
        if [[ "$DEV_TRANSPORT" == "localNetwork" ]]; then
          info "무선이면 흔한 원인: 아이폰이 잠겨 있거나, 절전 모드이거나,"
          info "맥과 다른 와이파이에 있는 경우예요. 잠금 풀고 다시 돌려 보세요."
        fi
        info "안 되면 Xcode 에서 기기를 고르고 ⌘R. 로그: $PROJ_DIR/install.log"
      fi
    else
      bad "기기용 빌드 실패 — 보통 서명 설정이 아직 없어서예요."
      grep -E "error:|Signing|provisioning" device-build.log 2>/dev/null | sed "s|$PROJ_DIR/||g" | sort -u | head -12
      echo
      info "Xcode 에서 Team 을 한 번만 골라 주세요 → Signing & Capabilities"
      info "그다음 ⌘R. 이후로는 이 스크립트가 알아서 설치해요."
    fi
  fi

  echo
  info "Xcode 로 열기:  open $PROJ_DIR/Min30.xcodeproj"
else
  bold "❌ 빌드 에러 ${ERR_N}건"
  echo
  echo "────────── 여기부터 복사해서 Claude 에게 붙여넣으세요 ──────────"
  echo "Xcode: $XC_VER"
  echo
  head -60 "$REPORT"
  [[ $(wc -l < "$REPORT") -gt 60 ]] && echo "... (전체는 $REPORT 에 있어요)"
  echo "──────────────────────── 여기까지 ────────────────────────"
  echo
  info "전체 로그: $LOG"
  # 클립보드에 바로 담아준다
  if command -v pbcopy >/dev/null 2>&1; then
    { echo "Xcode: $XC_VER"; echo; head -60 "$REPORT"; } | pbcopy
    ok "클립보드에 복사해 뒀어요 — 그냥 붙여넣기(⌘V) 하면 돼요"
  fi
fi

exit $BUILD_RC
