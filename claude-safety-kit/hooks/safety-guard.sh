#!/usr/bin/env bash
# safety-guard.sh — Claude Code 초보 안전장치 (macOS / Linux / Git Bash)
# PreToolUse[Bash] 훅으로 등록. 되돌릴 수 없는 위험 명령과 비밀키 노출을 차단한다.
# 입력: stdin으로 들어오는 JSON( tool_input.command 등 ). 의존성 없음(grep만 사용).
# 차단 방식: 위험하면 stderr에 이유 출력 후 exit 2 (Claude에게 에러로 전달되어 실행 취소됨).

raw="$(cat)"
[ -z "$raw" ] && exit 0

block() { printf '%s\n' "$1" >&2; exit 2; }

# ── 1) 되돌릴 수 없는 파괴적 명령 ─────────────────────────────
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

# ── 2) 비밀키(API키/비밀번호) 화면 노출 ───────────────────────
echo "$raw" | grep -qE '(^|[^A-Za-z0-9_])printenv([^A-Za-z0-9_]|$)' \
  && block "[SECRET] 환경변수 전체 덤프(printenv)를 막았어요. 키는 환경변수로만 사용하세요."
echo "$raw" | grep -qiE '(echo|printf)[^;&|]*\$\{?[A-Za-z_]*(KEY|SECRET|TOKEN|PASSWORD|PASSWD)' \
  && block "[SECRET] 비밀키를 화면에 출력하려는 명령을 막았어요. 키는 환경변수로만 사용하세요."
echo "$raw" | grep -qE '(cat|less|more|head|tail|grep|sed|awk|strings|xxd|od|pbcopy)[^;&|]*(^|[/[:space:]"'"'"'])\.?[A-Za-z0-9._-]*\.env([[:space:]"'"'"']|$|\.[A-Za-z]+)' \
  && block "[SECRET] .env(비밀키 파일) 열람을 막았어요. 키는 환경변수로만 사용하세요."

exit 0
