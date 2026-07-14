# ============================================================
#  클로드 안전장치 — 원클릭 설치 v1.1.0 (Windows / PowerShell)
#
#  [원격 설치] PowerShell 또는 클로드에게:
#     irm https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.ps1 | iex
#  [로컬 설치]
#     우클릭 → "PowerShell로 실행"   또는   powershell -ExecutionPolicy Bypass -File install.ps1
#
#  하는 일: 안전장치 3개 파일(차단기·설명서·제거스크립트)을 %USERPROFILE%\.claude\hooks 에
#          넣고 클로드 설정(hooks)에 등록한다.
#  * git init 하지 않음        * 기존 설정은 보존 + 백업(settings.json.bak)
#  * 설정 파일이 깨져 있으면 절대 덮어쓰지 않고 중단
#  * 여러 번 돌려도 안전(중복 등록 안 됨), 제거는 uninstall.ps1 한 번이면 끝
#  * 추가 설치 필요 없음 (Windows 내장 PowerShell만 사용)
# ============================================================
$ErrorActionPreference = 'Stop'

$SafetyKitVersion = '1.1.3'
$BaseUrl   = 'https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit'
$SourceUrl = 'https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit'   # 내용 공개 확인용

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$hooksDir  = Join-Path $claudeDir 'hooks'
$settings  = Join-Path $claudeDir 'settings.json'

Write-Host ""
Write-Host "🛟  클로드 안전장치를 설치할게요...  (v$SafetyKitVersion)"
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

# ── 1) 파일 3개 설치 (로컬 사본이 있으면 복사, 없으면 원본 저장소에서 다운로드) ──
function Install-KitFile([string]$relPath, [string]$destPath) {
  $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot ($relPath -replace '/', '\') } else { $null }
  if ($local -and (Test-Path $local)) {
    Copy-Item $local $destPath -Force
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/$relPath" -OutFile $destPath
  }
  # 한국어 Windows의 PowerShell 5.1은 BOM 없는 .ps1을 CP949로 읽어
  # 한글 문자열·정규식을 깨뜨린다 → .ps1은 UTF-8 BOM을 보장한다 (v1.1.3)
  if ($destPath -like '*.ps1') {
    $bytes = [System.IO.File]::ReadAllBytes($destPath)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
      $text = [System.Text.Encoding]::UTF8.GetString($bytes)
      [System.IO.File]::WriteAllText($destPath, $text, (New-Object System.Text.UTF8Encoding($true)))
    }
  }
}
Install-KitFile 'hooks/safety-guard.ps1' (Join-Path $hooksDir 'safety-guard.ps1')
Install-KitFile 'hooks/SAFETY-KIT.md'    (Join-Path $hooksDir 'SAFETY-KIT.md')
Install-KitFile 'uninstall.ps1'          (Join-Path $hooksDir 'uninstall.ps1')
Write-Host "   ✓ 안전장치 파일 설치됨 ($hooksDir)"

# ── 2) 설치 직후 자가진단 — 통과 못 하면 여기서 멈춘다 ─────────
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $hooksDir 'safety-guard.ps1') -SelfTest | Out-Null
if ($LASTEXITCODE -eq 0) {
  Write-Host "   ✓ 자가진단 통과"
} else {
  Write-Host "   ❌ 자가진단 실패 — 설치를 중단합니다. (등록 전이라 클로드 설정은 그대로입니다)"
  exit 1
}

# ── 2.5) 차단 신호 전달 검사 — 등록할 훅 명령 '그대로' 위험 페이로드를
#         흘려보내 exit 2가 살아서 나오는지 확인한다.
#         (Windows PowerShell 5.1의 -Command 는 `& 스크립트`의 exit 2를 1로
#          뭉개므로 명령 끝의 "; exit $LASTEXITCODE" 가 필수 — v1.1.2 수정)
$HookCommand = 'try { Set-ExecutionPolicy Bypass -Scope Process -Force } catch {}; & "$env:USERPROFILE\.claude\hooks\safety-guard.ps1"; exit $LASTEXITCODE'
'{"tool_input":{"command":"git push --force origin main"}}' | powershell -NoProfile -Command $HookCommand 2>$null | Out-Null
if ($LASTEXITCODE -eq 2) {
  Write-Host "   ✓ 차단 신호 전달 검사 통과 (exit 2)"
} else {
  Write-Host "   ❌ 차단 신호가 전달되지 않습니다 (exit $LASTEXITCODE) — 설치를 중단합니다. (등록 전이라 클로드 설정은 그대로입니다)"
  exit 1
}

# ── 3) 클로드 설정에 등록 (기존 설정은 보존, 깨진 JSON은 건드리지 않음) ──
if (Test-Path $settings) {
  try {
    $obj = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    Write-Host "   ❌ 기존 settings.json 이 올바른 JSON이 아니라서, 안전을 위해 아무것도"
    Write-Host "      덮어쓰지 않고 중단합니다. 클로드에게 'settings.json 이 왜 깨졌는지"
    Write-Host "      봐줘'라고 요청한 뒤 다시 설치하세요."
    exit 1
  }
  Copy-Item $settings "$settings.bak" -Force
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
# 이전 버전 포함, 우리가 등록했던 항목만 제거(다른 훅은 그대로)
$pre  = @($pre  | Where-Object { ($_ | ConvertTo-Json -Depth 20 -Compress) -notmatch 'safety-guard' })
$stop = @($stop | Where-Object { ($_ | ConvertTo-Json -Depth 20 -Compress) -notmatch 'safety-kit-sound' })

# 실행 정책이 Restricted 여도 훅이 돌 수 있게 Process 범위에서만 우회하고,
# exit 2(차단 신호)가 래퍼에서 뭉개지지 않도록 그대로 다시 내보낸다 (위 2.5에서 실검증한 명령)
$pre += @{ matcher = 'Bash'; hooks = @(@{
  type = 'command'; shell = 'powershell'
  command = $HookCommand
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
Write-Host "🎉  설치 완료!  클로드를 완전히 껐다 켠 뒤, 이렇게 확인해 보세요:"
Write-Host ""
Write-Host '   ① 클로드에게 →  "안전장치 자가진단 실행해줘"'
Write-Host "      (아무것도 실행하지 않는 검사입니다. '전부 통과'가 나오면 규칙 정상)"
Write-Host ""
Write-Host '   ② 클로드에게 →  "git push --force 실행해봐"'
Write-Host "      → 🛡️ '[안전장치 v$SafetyKitVersion] 강제 푸시...를 막았어요' 가 뜨면 훅 연결 성공"
Write-Host "      (git 저장소가 아닌 폴더에서 하면, 설령 안 막혀도 아무 일도 일어나지 않습니다)"
Write-Host ""
Write-Host "   설명서·끄는 법: %USERPROFILE%\.claude\hooks\SAFETY-KIT.md"
Write-Host "   완전 제거: powershell -NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.claude\hooks\uninstall.ps1`""
Write-Host "   전체 코드 공개: $SourceUrl"
Write-Host ""
