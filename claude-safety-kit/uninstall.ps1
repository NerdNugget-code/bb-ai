# ============================================================
#  클로드 안전장치 — 완전 제거 (Windows / PowerShell)
#  실행: powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
#  하는 일: settings.json에서 안전장치 훅 등록을 빼고,
#          %USERPROFILE%\.claude\hooks\ 의 안전장치 파일들을 삭제한다.
#          안전장치가 만들지 않은 설정·훅은 절대 건드리지 않는다.
# ============================================================
$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$hooksDir  = Join-Path $claudeDir 'hooks'
$settings  = Join-Path $claudeDir 'settings.json'

Write-Host ""
Write-Host "🧹 클로드 안전장치를 제거할게요..."

# 1) settings.json 에서 안전장치 훅만 제거
if (Test-Path $settings) {
  try {
    $obj = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    Write-Host "   ⚠ settings.json 을 읽을 수 없어 훅 등록 해제를 건너뜁니다. (파일은 그대로 둡니다)"
    $obj = $null
  }
  if ($obj) {
    Copy-Item $settings "$settings.bak" -Force
    $markers = @('safety-guard', 'safety-kit-sound')
    $changed = $false
    if ($obj.PSObject.Properties.Name -contains 'hooks' -and $obj.hooks) {
      $newHooks = @{}
      foreach ($p in $obj.hooks.PSObject.Properties) {
        $kept = @()
        foreach ($entry in @($p.Value)) {
          $blob = $entry | ConvertTo-Json -Depth 20 -Compress
          $isOurs = $false
          foreach ($mk in $markers) { if ($blob -match [regex]::Escape($mk)) { $isOurs = $true } }
          if ($isOurs) { $changed = $true } else { $kept += $entry }
        }
        if ($kept.Count -gt 0) { $newHooks[$p.Name] = $kept } else { $changed = $true }
      }
      if ($newHooks.Count -gt 0) {
        $obj | Add-Member -NotePropertyName 'hooks' -NotePropertyValue $newHooks -Force
      } else {
        $obj.PSObject.Properties.Remove('hooks')
      }
      if ($changed) {
        $json = $obj | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($settings, $json, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "   ✓ 훅 등록 해제됨 (다른 훅·설정은 그대로, 백업: settings.json.bak)"
      } else {
        Write-Host "   · settings.json 에 안전장치 등록이 없었습니다"
      }
    } else {
      Write-Host "   · settings.json 에 훅이 없습니다"
    }
  }
} else {
  Write-Host "   · settings.json 이 없습니다"
}

# 2) 안전장치 파일 삭제 (자기 자신은 마지막에)
Remove-Item (Join-Path $hooksDir 'safety-guard.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $hooksDir 'SAFETY-KIT.md')    -Force -ErrorAction SilentlyContinue
Write-Host "   ✓ 안전장치 파일 삭제됨"

Write-Host ""
Write-Host "✅ 제거 완료. 클로드를 완전히 껐다 켜면 반영됩니다."
Write-Host ""
Remove-Item (Join-Path $hooksDir 'uninstall.ps1') -Force -ErrorAction SilentlyContinue
