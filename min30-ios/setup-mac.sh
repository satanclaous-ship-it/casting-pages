#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# 30분 기록 — 맥북 셋업 + 빌드 진단
#
#   curl -fsSL https://raw.githubusercontent.com/satanclaous-ship-it/casting-pages/claude/30min-activity-tracker-5z988y/min30-ios/setup-mac.sh | bash
#
# 하는 일: 저장소를 받아오고, 프로젝트를 열 수 있는지 확인하고,
# 실제로 빌드를 돌려서 에러를 사람이 읽을 수 있게 정리해 준다.
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

bold $'\n▶ 1/4  환경 확인'

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

bold $'\n▶ 2/4  소스 받기'

if [[ -d "$DEST/.git" ]]; then
  info "이미 있어요 → 최신으로 갱신"
  git -C "$DEST" fetch origin "$BRANCH" --quiet 2>/dev/null \
    && git -C "$DEST" checkout "$BRANCH" --quiet 2>/dev/null \
    && git -C "$DEST" reset --hard "origin/$BRANCH" --quiet 2>/dev/null \
    && ok "갱신 완료: $DEST" \
    || { bad "갱신 실패 — 인터넷 연결이나 $DEST 상태를 확인해 주세요."; exit 1; }
else
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$DEST" --quiet 2>/dev/null \
    && ok "받았어요: $DEST" \
    || { bad "clone 실패 — 인터넷 연결을 확인해 주세요."; exit 1; }
fi

cd "$PROJ_DIR" || { bad "$PROJ_DIR 가 없어요."; exit 1; }
info "$(find Min30 -name '*.swift' | wc -l | tr -d ' ')개 Swift 파일"

bold $'\n▶ 3/4  프로젝트 파일 확인'

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

bold $'\n▶ 4/4  빌드'

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
  bold '✅ 빌드 성공'
  ok "이제 Xcode 에서 열어 Team 만 고르면 실기기에 올라가요"
  info "열기:  open $PROJ_DIR/Min30.xcodeproj"
  echo
  info "실기기에 올릴 때: 왼쪽 Min30 클릭 → Signing & Capabilities →"
  info "Team 을 본인 계정으로. 번들 ID 가 중복이면 뒤에 아무 글자나 붙이세요."
  open "$PROJ_DIR/Min30.xcodeproj" 2>/dev/null || true
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
