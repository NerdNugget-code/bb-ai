# ============================================================
#  safety-guard.ps1 — 클로드 안전장치 v1.1.0 (Windows / PowerShell)
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
#  ▸ 지금 바로 확인:
#      powershell -NoProfile -ExecutionPolicy Bypass -File safety-guard.ps1 -SelfTest
#  ▸ 설명·끄기·삭제:   같은 폴더의 SAFETY-KIT.md
# ============================================================
param([switch]$SelfTest)
$ErrorActionPreference = 'SilentlyContinue'

$VERSION = '1.1.1'
$TAG     = "[안전장치 v$VERSION]"
$GUIDE   = '%USERPROFILE%\.claude\hooks\SAFETY-KIT.md'

# ── 위험 대상 패턴 (safety-guard.sh 와 동일 로직) ─────────────
# 원칙: "프로젝트 안 폴더 삭제는 허용, 되돌릴 수 없는 대상은 차단"
$TGT = '(^|[\s=])(/|~|\*|\.\.?/?)(\s|$)' +
       '|\$HOME/?(\s|$)|\$env:USERPROFILE\\?(\s|$)|%USERPROFILE%\\?(\s|$)' +
       '|[A-Za-z]:[\\/]?(\s|$)|[A-Za-z]:[\\/]Users([\\/][^\\/\s]+)?[\\/]?(\s|$)|[\\/]Windows([\\/]|\s|$)' +
       '|/(Users|home)(/[^/\s]+)?/?(\s|$)|/(etc|usr|bin|sbin|lib|var|opt|boot|System|Library|Applications)/?(\s|$)' +
       '|[^\s]*[\\/](Desktop|Documents|Downloads|Pictures|Movies|Music|OneDrive|바탕화면|문서|다운로드)[\\/]?(\s|$)'

# 명령 조각 하나를 검사: 위험하면 이유 문자열, 안전하면 $null 반환
function Test-Segment([string]$s) {
  # 1) 되돌릴 수 없는 삭제 (bash rm)
  if ($s -match '(^|\s)(sudo\s+)?rm(\s|$)' -and
      $s -match '\s(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)(\s|$)' -and
      $s -match $TGT) {
    return '홈·바탕화면·시스템 폴더처럼 되돌릴 수 없는 대상을 지우는 rm 명령을 막았어요'
  }
  # 2) 되돌릴 수 없는 삭제 (PowerShell/cmd)
  if ($s -match '(^|\s)(Remove-Item|ri|rd|rmdir|del|erase)(\s|$)' -and
      $s -match '(-Recurse|/s(\s|$)|\s-r(\s|$))' -and
      $s -match $TGT) {
    return '홈·바탕화면·시스템 폴더를 통째로 지우는 삭제 명령을 막았어요'
  }
  # 3) 디스크를 지우는 명령
  if ($s -match '(^|[^A-Za-z])format\s+[A-Za-z]:|Format-Volume|(^|\s)diskpart(\s|$)|cipher\s+/w|(^|\s)mkfs(\.|\s)|(^|\s)dd\s[^;]*of=/dev/') {
    return '디스크·드라이브를 통째로 지우는 명령을 막았어요'
  }
  # 4) git — 기록·작업물이 날아가는 명령
  if ($s -match 'git\s+push\s' -and
      ($s -match '\s(--force|-f)(\s|$)' -or $s -match 'git\s+push\s+[^\s]*\s\+[^\s]+')) {
    return '강제 푸시(git push --force)를 막았어요. 협업 기록이 지워질 수 있어요 (--force-with-lease 는 허용됩니다)'
  }
  if ($s -match 'git\s+reset\s+--hard') {
    return '작업 내용을 통째로 되돌리는 git reset --hard 를 막았어요'
  }
  if ($s -match 'git\s+clean\s' -and $s -match '\s-[a-zA-Z]*f') {
    return '커밋 안 한 새 파일을 지우는 git clean -f 를 막았어요'
  }
  # 5) 기타 파괴적 명령
  if ($s -match ':\(\)\s*\{') { return '시스템을 멈추게 하는 명령(포크밤)을 막았어요' }
  if ($s -match 'chmod\s+-R\s+777') { return '위험한 권한 변경(chmod -R 777)을 막았어요' }
  if ($s -match '(^|\s)DROP\s+(TABLE|DATABASE|SCHEMA)|(^|\s)TRUNCATE\s+TABLE') {
    return '데이터베이스를 통째로 지우는 명령을 막았어요'
  }
  # 6) 비밀키(API키·비밀번호) 화면 노출
  if ($s -cmatch '(^|[^A-Za-z0-9_])printenv([^A-Za-z0-9_]|$)|^\s*env\s*$|^\s*set\s*$' -or
      $s -match '(Get-ChildItem|gci|dir|ls)\s+env:') {
    return '환경변수 전체(비밀키 포함)를 화면에 쏟아내는 명령을 막았어요'
  }
  if ($s -match '(^|\s)(cat|type|less|more|head|tail|grep|rg|sed|awk|strings|xxd|od|pbcopy|open|code|notepad|Get-Content|gc|Select-String|sls|findstr)\s' -and
      $s -match '(^|[/\\\s])\.?[A-Za-z0-9._-]*\.env([/\\\s.]|$)') {
    return '.env(비밀키 파일) 열람을 막았어요. 키 값은 화면에 찍지 말고 환경변수로만 쓰세요'
  }
  if ($s -match '(^|\s)(echo|printf|print|Write-Host|Write-Output)(\s|$)' -and
      $s -cmatch '\$\{?(env:)?[A-Za-z_]*(KEY|SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL)') {
    return '비밀키를 화면에 출력하려는 명령을 막았어요'
  }
  return $null
}

# 전체 명령을 검사: 따옴표 제거 → 조각으로 나눠 각각 검사
function Test-BBCommand([string]$cmd) {
  $norm = $cmd -replace '["'']', ''
  foreach ($seg in ($norm -split '[;&|\r\n]')) {
    if ([string]::IsNullOrWhiteSpace($seg)) { continue }
    $reason = Test-Segment $seg
    if ($reason) { return $reason }
  }
  return $null
}

function Block([string]$reason) {
  [Console]::Error.WriteLine("$TAG $reason. 정말 필요하면 클로드가 아니라 여러분이 직접 터미널에서 실행하세요. (이 차단의 정체와 끄는 법: $GUIDE)")
  exit 2
}

# ── 자가진단 모드 ────────────────────────────────────────────
if ($SelfTest) {
  $script:ok = 0; $script:bad = 0
  function T([string]$expect, [string]$cmd) {
    $got = if (Test-BBCommand $cmd) { 'BLOCK' } else { 'PASS' }
    if ($got -eq $expect) { Write-Host ("  [OK] {0,-5} {1}" -f $expect, $cmd); $script:ok++ }
    else { Write-Host ("  [!!] {0,-5} (실제:{1}) {2}" -f $expect, $got, $cmd); $script:bad++ }
  }
  Write-Host "🛟 안전장치 v$VERSION 자가진단 — 아래 명령은 '검사만' 하며 아무것도 실행하지 않습니다."
  Write-Host ""
  Write-Host "[막아야 하는 명령들]"
  T 'BLOCK' 'rm -rf ~'
  T 'BLOCK' 'rm -rf ~/Desktop'
  T 'BLOCK' 'rm -rf "/Users/kim/Desktop"'
  T 'BLOCK' 'rm -rf $HOME'
  T 'BLOCK' 'sudo rm -rf /'
  T 'BLOCK' 'rm -rf *'
  T 'BLOCK' 'Remove-Item -Recurse -Force C:\Users\kim\Desktop'
  T 'BLOCK' 'Remove-Item -Force -Recurse "$env:USERPROFILE"'
  T 'BLOCK' 'rd /s /q C:\'
  T 'BLOCK' 'format d:'
  T 'BLOCK' 'git push --force origin main'
  T 'BLOCK' 'git push origin +main'
  T 'BLOCK' 'git reset --hard HEAD~3'
  T 'BLOCK' 'git clean -fd'
  T 'BLOCK' 'chmod -R 777 .'
  T 'BLOCK' 'printenv'
  T 'BLOCK' 'env | grep API'
  T 'BLOCK' 'Get-ChildItem Env:'
  T 'BLOCK' 'cat .env'
  T 'BLOCK' 'Get-Content .env.local'
  T 'BLOCK' 'echo $env:OPENAI_API_KEY'
  Write-Host ""
  Write-Host "[통과해야 하는 일상 명령들]"
  T 'PASS' 'npm install'
  T 'PASS' 'rm -rf node_modules'
  T 'PASS' 'rm -rf dist build'
  T 'PASS' 'rm -rf /tmp/build-cache'
  T 'PASS' 'Remove-Item -Recurse -Force node_modules'
  T 'PASS' 'git push origin main'
  T 'PASS' 'git push --force-with-lease origin main'
  T 'PASS' 'git commit -m "fix; cleanup"'
  T 'PASS' 'cat README.md'
  T 'PASS' 'echo $PATH'
  T 'PASS' 'python -m venv .venv'
  T 'PASS' 'git status --short | grep -E env'
  T 'PASS' 'ls -la | Select-String set'
  Write-Host ""
  if ($script:bad -eq 0) {
    Write-Host "🎉 전부 통과 ($($script:ok)/$($script:ok + $script:bad)) — 안전장치가 정상 작동 중입니다."
    exit 0
  } else {
    Write-Host "⚠️  $($script:bad)개 항목이 기대와 다릅니다. SAFETY-KIT.md 의 문의처를 확인하세요."
    exit 1
  }
}

# ── 진입점 (훅 모드) ─────────────────────────────────────────
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

# stdin JSON에서 실행될 명령만 추출 (JSON이 깨졌으면 안전 우선:
# 원문 전체를 그대로 검사한다 — 과하게 막을지언정 놓치지 않음)
$cmd = $null
try {
  $obj = $raw | ConvertFrom-Json
  $cmd = [string]$obj.tool_input.command
} catch { $cmd = $raw }
if ($null -eq $cmd) { $cmd = $raw }
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

$reason = Test-BBCommand $cmd
if ($reason) { Block $reason }
exit 0
