# safety-guard.ps1 — Claude Code 초보 안전장치 (Windows / PowerShell)
# PreToolUse[Bash] 훅으로 등록. 되돌릴 수 없는 위험 명령과 비밀키 노출을 차단한다.
# 입력: stdin으로 들어오는 JSON( tool_input.command 등 ). 의존성 없음(정규식만 사용).
# 차단 방식: 위험하면 stderr에 이유 출력 후 exit 2 (Claude에게 에러로 전달되어 실행 취소됨).

$ErrorActionPreference = 'SilentlyContinue'

# stdin 전체를 한 덩어리로 읽어 그대로 검사한다(JSON 파싱 불필요 = 의존성 0).
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

function Block([string]$msg) {
  [Console]::Error.WriteLine($msg)
  exit 2
}

# ── 1) 되돌릴 수 없는 파괴적 명령 ─────────────────────────────
$danger = @(
  @{ p = 'rm\s+-[a-z]*r[a-z]*f?\s+(/|~|\*|\.(\s|$|/))'; m = '되돌릴 수 없는 삭제(rm -rf)를 막았어요.' },
  @{ p = 'Remove-Item[^;&|]*-Recurse[^;&|]*-Force[^;&|]*(C:\\(\s|"|''|$)|\\Windows|\$env:USERPROFILE)'; m = '시스템 폴더 전체 삭제(Remove-Item -Recurse -Force)를 막았어요.' },
  @{ p = '\b(rd|rmdir|del)\s+[^;&|]*/[a-zA-Z]*s[^;&|]*(C:\\?(\s|$)|\\Windows|%SystemRoot%)'; m = '시스템 폴더 재귀 삭제(rd/del /s)를 막았어요.' },
  @{ p = '\bformat\s+[A-Za-z]:'; m = '드라이브 포맷(format)을 막았어요.' },
  @{ p = 'Format-Volume|\bdiskpart\b|cipher\s+/w'; m = '디스크를 지우는 명령을 막았어요.' },
  @{ p = 'git\s+push\s+(--force|-f)(\s|$)'; m = '강제 푸시(git push --force)를 막았어요. 협업 기록이 지워질 수 있어요.' },
  @{ p = 'git\s+reset\s+--hard'; m = '작업 내용을 통째로 되돌리는 git reset --hard를 막았어요.' },
  @{ p = 'chmod\s+-R\s+777'; m = '위험한 권한 변경(chmod -R 777)을 막았어요.' },
  @{ p = ':\(\)\s*\{'; m = '시스템을 멈추게 하는 명령(포크밤)을 막았어요.' },
  @{ p = 'DROP\s+TABLE'; m = '데이터베이스 테이블 삭제(DROP TABLE)를 막았어요.' }
)
foreach ($d in $danger) {
  if ($raw -match $d.p) { Block("[SAFETY] $($d.m) 정말 필요하면 직접 터미널에서 실행하세요.") }
}

# ── 2) 비밀키(API키/비밀번호) 화면 노출 ───────────────────────
$secret = @(
  @{ p = '(^|[^A-Za-z0-9_])printenv([^A-Za-z0-9_]|$)'; m = '환경변수 전체 덤프(printenv)를 막았어요.' },
  @{ p = '(Get-ChildItem|gci|ls|dir)\s+Env:'; m = '환경변수 전체 열람(Env:)을 막았어요.' },
  @{ p = '(Get-Content|gc|cat|type|more|Select-String|sls|findstr)\b[^;&|]*\.env\b'; m = '.env(비밀키 파일) 열람을 막았어요.' },
  @{ p = '(echo|Write-Host|Write-Output)[^;&|]*\$\{?(env:)?[A-Za-z_]*(KEY|SECRET|TOKEN|PASSWORD|PASSWD)'; m = '비밀키를 화면에 출력하려는 명령을 막았어요.' }
)
foreach ($s in $secret) {
  if ($raw -match $s.p) { Block("[SECRET] $($s.m) 키는 화면에 찍지 말고 환경변수로만 사용하세요.") }
}

exit 0
