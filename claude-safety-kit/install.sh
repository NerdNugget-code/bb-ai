#!/usr/bin/env bash
# ============================================================
#  클로드 안전장치 — 원클릭 설치 (macOS / Linux)
#
#  [원격 설치] 터미널 또는 클로드에게:
#     curl -fsSL https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.sh | bash
#  [로컬 설치]
#     bash install.sh
#
#  하는 일: 안전장치를 ~/.claude 에 넣고 클로드 설정에 자동 등록.
#  * git init 하지 않음  * 기존 설정 덮어쓰지 않고 보존+백업  * 여러 번 돌려도 안전
# ============================================================
set -e

SAFETY_KIT_VERSION="1.0.0"
SOURCE_URL="https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit"   # 내용 공개 확인용

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
GUARD="$HOOKS_DIR/safety-guard.sh"

echo ""
echo "🛟  클로드 안전장치를 설치할게요...  (v$SAFETY_KIT_VERSION)"
mkdir -p "$HOOKS_DIR"

# ── 1) 안전장치 스크립트 심기 ────────────────────────────────
cat > "$GUARD" <<'GUARD'
#!/usr/bin/env bash
# safety-guard.sh — Claude Code 초보 안전장치 (macOS / Linux / Git Bash)
raw="$(cat)"
[ -z "$raw" ] && exit 0
block() { printf '%s\n' "$1" >&2; exit 2; }

echo "$raw" | grep -qE 'rm[[:space:]]+-[a-z]*r[a-z]*f?[[:space:]]+(/|~|\*|\.($|[[:space:]/]))' \
  && block "[SAFETY] 되돌릴 수 없는 삭제(rm -rf)를 막았어요. 정말 필요하면 직접 터미널에서 실행하세요."
echo "$raw" | grep -qE ':\(\)[[:space:]]*\{' \
  && block "[SAFETY] 시스템을 멈추게 하는 명령(포크밤)을 막았어요."
echo "$raw" | grep -qE 'chmod[[:space:]]+-R[[:space:]]+777' \
  && block "[SAFETY] 위험한 권한 변경(chmod -R 777)을 막았어요."
echo "$raw" | grep -qE 'git[[:space:]]+push[[:space:]]+(--force|-f)([[:space:]]|$)' \
  && block "[SAFETY] 강제 푸시(git push --force)를 막았어요. 협업 기록이 지워질 수 있어요."
echo "$raw" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard' \
  && block "[SAFETY] 작업 내용을 통째로 되돌리는 git reset --hard를 막았어요."
echo "$raw" | grep -qiE 'DROP[[:space:]]+TABLE|(^|[^A-Za-z])format[[:space:]]+[A-Za-z]:' \
  && block "[SAFETY] 데이터를 통째로 지우는 명령을 막았어요."

echo "$raw" | grep -qE '(^|[^A-Za-z0-9_])printenv([^A-Za-z0-9_]|$)' \
  && block "[SECRET] 환경변수 전체 덤프(printenv)를 막았어요. 키는 환경변수로만 사용하세요."
echo "$raw" | grep -qiE '(echo|printf)[^;&|]*\$\{?[A-Za-z_]*(KEY|SECRET|TOKEN|PASSWORD|PASSWD)' \
  && block "[SECRET] 비밀키를 화면에 출력하려는 명령을 막았어요. 키는 환경변수로만 사용하세요."
echo "$raw" | grep -qE '(cat|less|more|head|tail|grep|sed|awk|strings|xxd|od|pbcopy)[^;&|]*(^|[/[:space:]"'"'"'])\.?[A-Za-z0-9._-]*\.env([[:space:]"'"'"']|$|\.[A-Za-z]+)' \
  && block "[SECRET] .env(비밀키 파일) 열람을 막았어요. 키는 환경변수로만 사용하세요."
exit 0
GUARD
chmod +x "$GUARD"
echo "   ✓ 안전장치 스크립트 설치됨"

# ── 2) 클로드 설정에 등록 (기존 설정은 보존) ──────────────────
if command -v python3 >/dev/null 2>&1; then
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"
  python3 - "$SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]
s = {}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8") as f: s = json.load(f)
    except Exception: s = {}
hooks = s.get("hooks", {}) or {}

def dedupe(arr, *needles):
    out = []
    for e in arr or []:
        blob = json.dumps(e, ensure_ascii=False)
        if not any(n in blob for n in needles):
            out.append(e)
    return out

pre = dedupe(hooks.get("PreToolUse", []), "safety-guard.sh")
pre.append({"matcher": "Bash", "hooks": [{
    "type": "command", "shell": "bash",
    "command": "\"$HOME/.claude/hooks/safety-guard.sh\"",
    "statusMessage": "안전장치 검사 중"}]})

stop = dedupe(hooks.get("Stop", []), "afplay", "paplay", "safety-kit-sound")
stop.append({"matcher": "", "hooks": [{
    "type": "command",
    "command": "bash -c 'case \"$(uname -s)\" in Darwin) afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 & ;; *) (command -v paplay >/dev/null && paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1) & ;; esac; exit 0'"}]})

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
echo "🎉  설치 완료!  클로드를 껐다 켠 뒤, 이렇게 한번 확인해 보세요:"
echo ""
echo "     클로드에게 →  \"내 바탕화면 폴더 전부 지워줘\""
echo ""
echo "   🛡️  '[SAFETY] ...막았어요' 메시지가 뜨면 정상 작동입니다. (실제로 지워지지 않아요)"
echo ""
echo "   이 스크립트가 무엇을 하는지는 여기서 다 볼 수 있어요: $SOURCE_URL"
echo ""
