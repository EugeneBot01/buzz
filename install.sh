#!/usr/bin/env bash
# Buzz team build installer (macOS).
#
#   curl -fsSL https://raw.githubusercontent.com/EugeneBot01/buzz/team/install.sh | bash
#
# Downloads the latest team release for this Mac (Apple Silicon or Intel),
# replaces /Applications/Buzz.app (the old one goes to the Trash), and opens it.
# Accounts, channels and messages are kept: they are not stored in the app.
#
# BUZZ_TEAM_TAG=team-v0.5.26-team.1 installs a specific (e.g. test) release.

set -euo pipefail

# Braces: bash reads the whole script before running it (safe with curl | bash).
{
REPO="EugeneBot01/buzz"
APP="/Applications/Buzz.app"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\n[오류] %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || die "맥에서만 설치할 수 있어요."

# Apple Silicon reports x86_64 when the terminal runs under Rosetta.
if [[ "$(uname -m)" == arm64 || "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" == 1 ]]; then
  ARCH=aarch64; ARCH_NAME="Apple 칩"
else
  ARCH=x64; ARCH_NAME="Intel"
fi

if [[ -n "${BUZZ_TEAM_TAG:-}" ]]; then
  API="https://api.github.com/repos/$REPO/releases/tags/$BUZZ_TEAM_TAG"
else
  API="https://api.github.com/repos/$REPO/releases/latest"
fi

say "최신 팀 버전 확인 중 ($ARCH_NAME 맥)"
URL=$(curl -fsSL "$API" | grep -o "\"browser_download_url\": *\"[^\"]*_${ARCH}\.app\.tar\.gz\"" | head -1 | sed 's/.*"\(https[^"]*\)"$/\1/') \
  || die "릴리스 정보를 가져오지 못했어요. 인터넷 연결을 확인해 주세요."
[[ -n "$URL" ]] || die "이 맥($ARCH_NAME)용 파일을 찾지 못했어요."
echo "$URL"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

say "다운로드 중"
curl -fL --progress-bar "$URL" -o "$TMP/Buzz.app.tar.gz" || die "다운로드에 실패했어요."
tar -xzf "$TMP/Buzz.app.tar.gz" -C "$TMP"
[[ -d "$TMP/Buzz.app" ]] || die "받은 파일에 Buzz.app이 없어요."
codesign --verify --deep --strict "$TMP/Buzz.app" 2>/dev/null || die "받은 앱의 서명이 올바르지 않아요. 설치를 중단했어요."

if pgrep -xq buzz-desktop || pgrep -xq Buzz; then
  say "실행 중인 Buzz 종료 중"
  osascript -e 'quit app "Buzz"' >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    pgrep -xq buzz-desktop || pgrep -xq Buzz || break
    sleep 0.5
  done
fi

if [[ -d "$APP" ]]; then
  say "기존 Buzz를 휴지통으로 옮기는 중 (필요하면 휴지통에서 되살릴 수 있어요)"
  osascript -e "tell application \"Finder\" to delete POSIX file \"$APP\"" >/dev/null 2>&1 \
    || mv "$APP" "$HOME/.Trash/Buzz $(date +%Y%m%d-%H%M%S).app" \
    || die "기존 Buzz를 옮기지 못했어요. 응용 프로그램 폴더에서 Buzz를 직접 휴지통에 넣고 다시 실행해 주세요."
fi

say "설치 중"
ditto "$TMP/Buzz.app" "$APP" || die "설치하지 못했어요. 응용 프로그램 폴더에 쓸 권한이 있는지 확인해 주세요."
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

say "완료! Buzz를 여는 중"
open "$APP"
cat <<'EOF'

키체인 창이 뜨면: 맥 로그인 비밀번호 입력 → "항상 허용"을 눌러 주세요.
("허용"만 누르면 매번 다시 물어봐요.)
앞으로 업데이트는 Buzz 앱 안의 "업데이트" 버튼으로 받으면 돼요.
EOF
}
