#!/usr/bin/env bash
# ============================================================
#  클로드 안전장치 — 완전 제거 (macOS / Linux)
#  실행: bash uninstall.sh
#  하는 일: settings.json에서 안전장치 훅 등록을 빼고,
#          ~/.claude/hooks/ 의 안전장치 파일들을 삭제한다.
#          안전장치가 만들지 않은 설정·훅은 절대 건드리지 않는다.
# ============================================================
set -e

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"

echo ""
echo "🧹 클로드 안전장치를 제거할게요..."

# 1) settings.json 에서 안전장치 훅만 제거
if [ -f "$SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
  cp "$SETTINGS" "$SETTINGS.bak"
  python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        s = json.load(f)
except Exception:
    print("   ⚠ settings.json 을 읽을 수 없어 훅 등록 해제를 건너뜁니다. (파일은 그대로 둡니다)")
    sys.exit(0)

MARKERS = ("safety-guard", "safety-kit-sound")
hooks = s.get("hooks", {}) or {}
changed = False
for event in list(hooks.keys()):
    kept = []
    for entry in hooks.get(event) or []:
        blob = json.dumps(entry, ensure_ascii=False)
        if any(m in blob for m in MARKERS):
            changed = True
        else:
            kept.append(entry)
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]
        changed = True
if hooks:
    s["hooks"] = hooks
elif "hooks" in s:
    del s["hooks"]

if changed:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=2)
    print("   ✓ 훅 등록 해제됨 (다른 훅·설정은 그대로, 백업: settings.json.bak)")
else:
    print("   · settings.json 에 안전장치 등록이 없었습니다")
PY
else
  echo "   ⚠ settings.json 이 없거나 python3 이 없어 등록 해제를 건너뜁니다."
fi

# 2) 안전장치 파일 삭제 (자기 자신은 마지막에)
rm -f "$HOOKS_DIR/safety-guard.sh" "$HOOKS_DIR/SAFETY-KIT.md"
echo "   ✓ 안전장치 파일 삭제됨"

echo ""
echo "✅ 제거 완료. 클로드를 완전히 껐다 켜면 반영됩니다."
echo ""
rm -f "$HOOKS_DIR/uninstall.sh" 2>/dev/null || true
