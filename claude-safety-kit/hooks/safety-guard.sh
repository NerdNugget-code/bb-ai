#!/usr/bin/env bash
# ============================================================
#  safety-guard.sh — 클로드 안전장치 v1.1.0 (macOS / Linux / Git Bash)
#  출처(전체 코드 공개): https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit
#
#  ▸ 무엇인가요?
#    Claude Code가 셸 명령을 실행하기 직전(PreToolUse 훅)에 호출되어,
#    되돌릴 수 없는 삭제·비밀키 노출 명령이면 실행을 막는 안전장치입니다.
#    막을 때는 항상 "[안전장치 v...]"로 시작하는 메시지를 남기므로,
#    무언가 차단됐다면 그 이유와 출처를 바로 알 수 있습니다.
#
#  ▸ 작동 원리
#    stdin으로 들어오는 JSON에서 실행될 명령(tool_input.command)만 꺼내 검사.
#    따옴표를 벗기고(따옴표로 감싼 경로 우회 방지) 파이프/세미콜론 단위로 나눠
#    검사한 뒤, 위험하면 이유를 stderr에 쓰고 exit 2 → 명령이 실행되지 않음.
#
#  ▸ 지금 바로 확인:   bash safety-guard.sh --self-test
#  ▸ 설명·끄기·삭제:   같은 폴더의 SAFETY-KIT.md
# ============================================================
VERSION="1.1.0"
TAG="[안전장치 v$VERSION]"
GUIDE="~/.claude/hooks/SAFETY-KIT.md"

# ── 위험 대상 패턴 ───────────────────────────────────────────
# 원칙: "프로젝트 안 폴더 삭제는 허용, 되돌릴 수 없는 대상은 차단"
#  차단: 홈 폴더 자체(~, $HOME), 바탕화면·문서 등 홈 최상위 폴더,
#        루트(/)·드라이브(C:\)·시스템 폴더, * 전체 삭제
#  허용: node_modules, dist, /tmp/... 같은 프로젝트·임시 폴더
TGT='(^|[[:space:]=])(/|~|\*|\.\.?/?)([[:space:]]|$)'
TGT="$TGT"'|\$HOME/?([[:space:]]|$)|\$env:USERPROFILE\\?([[:space:]]|$)|%USERPROFILE%\\?([[:space:]]|$)'
TGT="$TGT"'|[A-Za-z]:[\\/]?([[:space:]]|$)|[A-Za-z]:[\\/][Uu]sers([\\/][^\\/[:space:]]+)?[\\/]?([[:space:]]|$)|[\\/][Ww]indows([\\/]|[[:space:]]|$)'
TGT="$TGT"'|/(Users|home)(/[^/[:space:]]+)?/?([[:space:]]|$)|/(etc|usr|bin|sbin|lib|var|opt|boot|System|Library|Applications)/?([[:space:]]|$)'
TGT="$TGT"'|[^[:space:]]*[\\/](Desktop|Documents|Downloads|Pictures|Movies|Music|OneDrive|바탕화면|문서|다운로드)[\\/]?([[:space:]]|$)'

# seg_check <명령조각> : 위험하면 이유를 출력하고 1 리턴, 안전하면 0
seg_check() {
  local s="$1"

  # 1) 되돌릴 수 없는 삭제 (bash rm)
  if echo "$s" | grep -qE '(^|[[:space:]])(sudo[[:space:]]+)?rm([[:space:]]|$)' \
     && echo "$s" | grep -qE '[[:space:]](-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)' \
     && echo "$s" | grep -qiE "$TGT"; then
    echo "홈·바탕화면·시스템 폴더처럼 되돌릴 수 없는 대상을 지우는 rm 명령을 막았어요"; return 1
  fi

  # 2) 되돌릴 수 없는 삭제 (PowerShell/cmd)
  if echo "$s" | grep -qiE '(^|[[:space:]])(Remove-Item|ri|rd|rmdir|del|erase)([[:space:]]|$)' \
     && echo "$s" | grep -qiE '(-Recurse|/s([[:space:]]|$)|[[:space:]]-r([[:space:]]|$))' \
     && echo "$s" | grep -qiE "$TGT"; then
    echo "홈·바탕화면·시스템 폴더를 통째로 지우는 삭제 명령을 막았어요"; return 1
  fi

  # 3) 디스크를 지우는 명령
  if echo "$s" | grep -qiE '(^|[^A-Za-z])format[[:space:]]+[A-Za-z]:|Format-Volume|(^|[[:space:]])diskpart([[:space:]]|$)|cipher[[:space:]]+/w|(^|[[:space:]])mkfs(\.|[[:space:]])|(^|[[:space:]])dd[[:space:]][^;]*of=/dev/'; then
    echo "디스크·드라이브를 통째로 지우는 명령을 막았어요"; return 1
  fi

  # 4) git — 기록·작업물이 날아가는 명령
  if echo "$s" | grep -qE 'git[[:space:]]+push[[:space:]]' \
     && echo "$s" | grep -qE '[[:space:]](--force|-f)([[:space:]]|$)|git[[:space:]]+push[[:space:]]+[^[:space:]]*[[:space:]]\+[^[:space:]]+'; then
    echo "강제 푸시(git push --force)를 막았어요. 협업 기록이 지워질 수 있어요 (--force-with-lease 는 허용됩니다)"; return 1
  fi
  if echo "$s" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
    echo "작업 내용을 통째로 되돌리는 git reset --hard 를 막았어요"; return 1
  fi
  if echo "$s" | grep -qE 'git[[:space:]]+clean[[:space:]]' \
     && echo "$s" | grep -qE '[[:space:]]-[a-zA-Z]*f'; then
    echo "커밋 안 한 새 파일을 지우는 git clean -f 를 막았어요"; return 1
  fi

  # 5) 기타 파괴적 명령
  if echo "$s" | grep -qE ':\(\)[[:space:]]*\{'; then
    echo "시스템을 멈추게 하는 명령(포크밤)을 막았어요"; return 1
  fi
  if echo "$s" | grep -qE 'chmod[[:space:]]+-R[[:space:]]+777'; then
    echo "위험한 권한 변경(chmod -R 777)을 막았어요"; return 1
  fi
  if echo "$s" | grep -qiE '(^|[[:space:]])DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|(^|[[:space:]])TRUNCATE[[:space:]]+TABLE'; then
    echo "데이터베이스를 통째로 지우는 명령을 막았어요"; return 1
  fi

  # 6) 비밀키(API키·비밀번호) 화면 노출
  if echo "$s" | grep -qE '(^|[^A-Za-z0-9_])printenv([^A-Za-z0-9_]|$)|(^|[[:space:]])env[[:space:]]*$|(^|[[:space:]])set[[:space:]]*$' \
     || echo "$s" | grep -qiE '(Get-ChildItem|gci|dir|ls)[[:space:]]+env:'; then
    echo "환경변수 전체(비밀키 포함)를 화면에 쏟아내는 명령을 막았어요"; return 1
  fi
  if echo "$s" | grep -qiE '(^|[[:space:]])(cat|type|less|more|head|tail|grep|rg|sed|awk|strings|xxd|od|pbcopy|open|code|notepad|Get-Content|gc|Select-String|sls|findstr)[[:space:]]' \
     && echo "$s" | grep -qE '(^|[/\\[:space:]])\.?[A-Za-z0-9._-]*\.env([/\\[:space:].]|$)'; then
    echo ".env(비밀키 파일) 열람을 막았어요. 키 값은 화면에 찍지 말고 환경변수로만 쓰세요"; return 1
  fi
  if echo "$s" | grep -qiE '(^|[[:space:]])(echo|printf|print|Write-Host|Write-Output)([[:space:]]|$)' \
     && echo "$s" | grep -qE '\$\{?(env:)?[A-Za-z_]*(KEY|SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL)'; then
    echo "비밀키를 화면에 출력하려는 명령을 막았어요"; return 1
  fi

  return 0
}

# check_command <전체 명령> : 위험하면 이유 출력 + 1 리턴
check_command() {
  local cmd="$1" norm seg reason
  norm=$(printf '%s' "$cmd" | tr -d '"'"'"'')   # 따옴표 제거(경로 숨기기 방지)
  while IFS= read -r seg; do
    [ -z "$seg" ] && continue
    if ! reason=$(seg_check "$seg"); then
      printf '%s' "$reason"; return 1
    fi
  done <<EOF
$(printf '%s' "$norm" | tr ';&|' '\n')
EOF
  return 0
}

block() {
  printf '%s %s. 정말 필요하면 클로드가 아니라 여러분이 직접 터미널에서 실행하세요. (이 차단의 정체와 끄는 법: %s)\n' "$TAG" "$1" "$GUIDE" >&2
  exit 2
}

# ── 자가진단 모드 ────────────────────────────────────────────
self_test() {
  local ok=0 bad=0
  t() { # t <BLOCK|PASS> <명령>
    local expect="$1" cmd="$2" got reason
    if reason=$(check_command "$cmd"); then got="PASS"; else got="BLOCK"; fi
    if [ "$got" = "$expect" ]; then
      printf '  ✅ %-5s %s\n' "$expect" "$cmd"; ok=$((ok+1))
    else
      printf '  ❌ %-5s(실제:%s) %s\n' "$expect" "$got" "$cmd"; bad=$((bad+1))
    fi
  }
  echo "🛟 안전장치 v$VERSION 자가진단 — 아래 명령은 '검사만' 하며 아무것도 실행하지 않습니다."
  echo ""
  echo "[막아야 하는 명령들]"
  t BLOCK 'rm -rf ~'
  t BLOCK 'rm -rf ~/Desktop'
  t BLOCK 'rm -rf "/Users/kim/Desktop"'
  t BLOCK 'rm -rf $HOME'
  t BLOCK 'sudo rm -rf /'
  t BLOCK 'rm -rf *'
  t BLOCK 'Remove-Item -Recurse -Force C:\Users\kim\Desktop'
  t BLOCK 'Remove-Item -Force -Recurse "$env:USERPROFILE"'
  t BLOCK 'rd /s /q C:\'
  t BLOCK 'format d:'
  t BLOCK 'git push --force origin main'
  t BLOCK 'git push origin +main'
  t BLOCK 'git reset --hard HEAD~3'
  t BLOCK 'git clean -fd'
  t BLOCK 'chmod -R 777 .'
  t BLOCK 'printenv'
  t BLOCK 'env | grep API'
  t BLOCK 'cat .env'
  t BLOCK 'type .env.local'
  t BLOCK 'echo $OPENAI_API_KEY'
  echo ""
  echo "[통과해야 하는 일상 명령들]"
  t PASS 'npm install'
  t PASS 'rm -rf node_modules'
  t PASS 'rm -rf dist build'
  t PASS 'rm -rf /tmp/build-cache'
  t PASS 'rm old-notes.txt'
  t PASS 'git push origin main'
  t PASS 'git push --force-with-lease origin main'
  t PASS 'git commit -m "fix; cleanup"'
  t PASS 'cat README.md'
  t PASS 'echo $PATH'
  t PASS 'python3 -m venv .venv'
  t PASS 'tail -f logs/dev.envoy.log'
  echo ""
  if [ "$bad" -eq 0 ]; then
    echo "🎉 전부 통과 ($ok/$((ok+bad))) — 안전장치가 정상 작동 중입니다."
    return 0
  else
    echo "⚠️  $bad개 항목이 기대와 다릅니다. SAFETY-KIT.md 의 문의처를 확인하세요."
    return 1
  fi
}

# ── 진입점 ───────────────────────────────────────────────────
if [ "${1:-}" = "--self-test" ]; then
  self_test; exit $?
fi

raw="$(cat 2>/dev/null || true)"
[ -z "$raw" ] && exit 0

# stdin JSON에서 실행될 명령만 추출 (python3가 없거나 JSON이 깨졌으면
# 안전 우선: 원문 전체를 그대로 검사한다 — 과하게 막을지언정 놓치지 않음)
cmd="__PARSE_FAIL__"
if command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$raw" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("__PARSE_FAIL__")' 2>/dev/null) || cmd="__PARSE_FAIL__"
fi
[ "$cmd" = "__PARSE_FAIL__" ] && cmd="$raw"
[ -z "$cmd" ] && exit 0

if ! reason=$(check_command "$cmd"); then
  block "$reason"
fi
exit 0
