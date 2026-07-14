# ============================================================
#  클로드 안전장치 — 원클릭 설치 (Windows / PowerShell)
#
#  [원격 설치] PowerShell 또는 클로드에게:
#     irm https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.ps1 | iex
#  [로컬 설치]
#     우클릭 → "PowerShell로 실행"   또는   powershell -File install.ps1
#
#  하는 일: 안전장치를 %USERPROFILE%\.claude 에 넣고 클로드 설정에 자동 등록.
#  * git init 하지 않음  * 기존 설정 덮어쓰지 않고 보존+백업  * 여러 번 돌려도 안전
#  * 추가 설치 필요 없음 (PowerShell 내장 기능만 사용)
# ============================================================
$ErrorActionPreference = 'Stop'

$SafetyKitVersion = '1.0.0'
$SourceUrl = 'https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit'   # 내용 공개 확인용

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$hooksDir  = Join-Path $claudeDir 'hooks'
$settings  = Join-Path $claudeDir 'settings.json'
$guardPath = Join-Path $hooksDir 'safety-guard.ps1'

Write-Host ""
Write-Host "🛟  클로드 안전장치를 설치할게요...  (v$SafetyKitVersion)"
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

# ── 1) 안전장치 스크립트 심기 ────────────────────────────────
$guard = @'
# safety-guard.ps1 — Claude Code 초보 안전장치 (Windows / PowerShell)
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
function Block([string]$msg) { [Console]::Error.WriteLine($msg); exit 2 }

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
'@
[System.IO.File]::WriteAllText($guardPath, $guard, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "   ✓ 안전장치 스크립트 설치됨"

# ── 2) 클로드 설정에 등록 (기존 설정은 보존) ──────────────────
if (Test-Path $settings) {
  Copy-Item $settings "$settings.bak" -Force
  $obj = Get-Content $settings -Raw | ConvertFrom-Json
} else {
  $obj = New-Object PSObject
}

# 기존 hooks 를 이벤트별로 분리 (PreToolUse/Stop 외 이벤트는 그대로 보존)
$pre = @(); $stop = @(); $otherHooks = @{}
if ($obj.PSObject.Properties.Name -contains 'hooks' -and $obj.hooks) {
  foreach ($p in $obj.hooks.PSObject.Properties) {
    if     ($p.Name -eq 'PreToolUse') { $pre  = @($p.Value) }
    elseif ($p.Name -eq 'Stop')       { $stop = @($p.Value) }
    else   { $otherHooks[$p.Name] = $p.Value }
  }
}
# 이전에 설치한 우리 훅은 제거(중복 방지)
$pre  = @($pre  | Where-Object { ($_ | ConvertTo-Json -Depth 20 -Compress) -notmatch 'safety-guard\.ps1' })
$stop = @($stop | Where-Object { ($_ | ConvertTo-Json -Depth 20 -Compress) -notmatch 'safety-kit-sound|console\]::beep' })

$pre += @{ matcher = 'Bash'; hooks = @(@{
  type = 'command'; shell = 'powershell'
  command = '& "$env:USERPROFILE\.claude\hooks\safety-guard.ps1"'
  statusMessage = '안전장치 검사 중' }) }
$stop += @{ matcher = ''; hooks = @(@{
  type = 'command'; shell = 'powershell'
  command = '[console]::beep(800,200); [console]::beep(1000,300)  # safety-kit-sound' }) }

$newHooks = @{}
foreach ($k in $otherHooks.Keys) { $newHooks[$k] = $otherHooks[$k] }
$newHooks['PreToolUse'] = $pre
$newHooks['Stop'] = $stop
$obj | Add-Member -NotePropertyName 'hooks' -NotePropertyValue $newHooks -Force

$json = $obj | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settings, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "   ✓ 클로드 설정에 등록됨$(if (Test-Path "$settings.bak") { '  (기존 설정은 settings.json.bak 으로 백업)' })"

Write-Host ""
Write-Host "🎉  설치 완료!  클로드를 껐다 켠 뒤, 이렇게 한번 확인해 보세요:"
Write-Host ""
Write-Host '     클로드에게 →  "내 바탕화면 폴더 전부 지워줘"'
Write-Host ""
Write-Host "   🛡️  '[SAFETY] ...막았어요' 메시지가 뜨면 정상 작동입니다. (실제로 지워지지 않아요)"
Write-Host ""
Write-Host "   이 스크립트가 무엇을 하는지는 여기서 다 볼 수 있어요: $SourceUrl"
Write-Host ""
