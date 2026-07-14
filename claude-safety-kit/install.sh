#!/usr/bin/env bash
# ============================================================
#  클로드 안전장치 — 원클릭 설치 v1.1.0 (macOS / Linux)
#
#  [원격 설치] 터미널 또는 클로드에게:
#     curl -fsSL https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.sh | bash
#  [로컬 설치]
#     bash install.sh
#
#  하는 일: 안전장치 3개 파일(차단기·설명서·제거스크립트)을 ~/.claude/hooks/ 에
#          넣고 클로드 설정(hooks)에 등록한다.
#  * git init 하지 않음        * 기존 설정은 보존 + 백업(settings.json.bak)
#  * 설정 파일이 깨져 있으면 절대 덮어쓰지 않고 중단
#  * 여러 번 돌려도 안전(중복 등록 안 됨), 제거는 uninstall.sh 한 번이면 끝
# ============================================================
set -e

SAFETY_KIT_VERSION="1.1.1"
BASE_URL="https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit"
SOURCE_URL="https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit"   # 내용 공개 확인용

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"

echo ""
echo "🛟  클로드 안전장치를 설치할게요...  (v$SAFETY_KIT_VERSION)"
mkdir -p "$HOOKS_DIR"

# ── 1) 파일 3개 설치 (로컬 사본이 있으면 복사, 없으면 원본 저장소에서 다운로드) ──
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd || true)"
fetch() { # fetch <저장소 상대경로> <설치 경로>
  if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$1" ]; then
    cp "$SRC_DIR/$1" "$2"
  else
    curl -fsSL "$BASE_URL/$1" -o "$2"
  fi
}
fetch "hooks/safety-guard.sh" "$HOOKS_DIR/safety-guard.sh"
fetch "hooks/SAFETY-KIT.md"   "$HOOKS_DIR/SAFETY-KIT.md"
fetch "uninstall.sh"          "$HOOKS_DIR/uninstall.sh"
chmod +x "$HOOKS_DIR/safety-guard.sh" "$HOOKS_DIR/uninstall.sh"
echo "   ✓ 안전장치 파일 설치됨 (~/.claude/hooks/)"

# ── 2) 설치 직후 자가진단 — 통과 못 하면 여기서 멈춘다 ─────────
if bash "$HOOKS_DIR/safety-guard.sh" --self-test >/dev/null 2>&1; then
  echo "   ✓ 자가진단 통과"
else
  echo "   ❌ 자가진단 실패 — 설치를 중단합니다. (등록 전이라 클로드 설정은 그대로입니다)"
  exit 1
fi

# ── 3) 클로드 설정에 등록 (기존 설정은 보존, 깨진 JSON은 건드리지 않음) ──
if command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" <<'PY'
import json, os, shutil, sys
path = sys.argv[1]
s = {}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8") as f:
            s = json.load(f)
    except Exception:
        print("   ❌ 기존 settings.json 이 올바른 JSON이 아니라서, 안전을 위해 아무것도")
        print("      덮어쓰지 않고 중단합니다. 클로드에게 'settings.json 이 왜 깨졌는지")
        print("      봐줘'라고 요청한 뒤 다시 설치하세요.")
        sys.exit(1)
    shutil.copyfile(path, path + ".bak")

hooks = s.get("hooks", {}) or {}

def dedupe(arr, *needles):
    return [e for e in (arr or [])
            if not any(n in json.dumps(e, ensure_ascii=False) for n in needles)]

# 이전 버전 포함, 우리가 등록했던 항목만 제거(다른 훅은 그대로)
pre = dedupe(hooks.get("PreToolUse", []), "safety-guard")
pre.append({"matcher": "Bash", "hooks": [{
    "type": "command", "shell": "bash",
    "command": "bash \"$HOME/.claude/hooks/safety-guard.sh\"",
    "statusMessage": "안전장치 검사 중"}]})

stop = dedupe(hooks.get("Stop", []), "safety-kit-sound", ";; *) (command -v paplay")
stop.append({"matcher": "", "hooks": [{
    "type": "command",
    "command": "bash -c 'case \"$(uname -s)\" in Darwin) afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 & ;; *) (command -v paplay >/dev/null && paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1) & ;; esac; exit 0' # safety-kit-sound"}]})

hooks["PreToolUse"] = pre
hooks["Stop"] = stop
s["hooks"] = hooks
with open(path, "w", encoding="utf-8") as f:
    json.dump(s, f, ensure_ascii=False, indent=2)
print("   ✓ 클로드 설정에 등록됨" + ("  (기존 설정은 settings.json.bak 으로 백업)" if os.path.exists(path + ".bak") else ""))
PY
else
  echo "   ⚠ python3 이 없어 자동 등록을 건너뜁니다. settings-snippet.mac.json 을 참고해 수동 병합하세요."
fi

echo ""
echo "🎉  설치 완료!  클로드를 완전히 껐다 켠 뒤, 이렇게 확인해 보세요:"
echo ""
echo "   ① 클로드에게 →  \"안전장치 자가진단 실행해줘\""
echo "      (아무것도 실행하지 않는 검사입니다. '전부 통과'가 나오면 규칙 정상)"
echo ""
echo "   ② 클로드에게 →  \"git push --force 실행해봐\""
echo "      → 🛡️ '[안전장치 v$SAFETY_KIT_VERSION] 강제 푸시...를 막았어요' 가 뜨면 훅 연결 성공"
echo "      (git 저장소가 아닌 폴더에서 하면, 설령 안 막혀도 아무 일도 일어나지 않습니다)"
echo ""
echo "   설명서·끄는 법: ~/.claude/hooks/SAFETY-KIT.md   |   완전 제거: bash ~/.claude/hooks/uninstall.sh"
echo "   전체 코드 공개: $SOURCE_URL"
echo ""
