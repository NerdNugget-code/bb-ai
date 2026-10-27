# ============================================================
#  클로드 안전장치 — 완전 제거 (Windows / PowerShell)
#  실행: powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
#  하는 일: settings.json에서 안전장치 훅 등록을 빼고,
#          %USERPROFILE%\.claude\hooks\ 의 안전장치 파일들을 삭제한다.
#          안전장치가 만들지 않은 설정·훅은 절대 건드리지 않는다.
# ============================================================
$ErrorActionPreference = 'Stop'

# 한국어 Windows는 콘솔 출력이 CP949라 한글 안내가 깨진다 → UTF-8 강제
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

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
    function Test-Ours($x) {
      $blob = $x | ConvertTo-Json -Depth 20 -Compress
      foreach ($mk in $markers) { if ($blob -match [regex]::Escape($mk)) { return $true } }
      return $false
    }
    if ($obj.PSObject.Properties.Name -contains 'hooks' -and $obj.hooks) {
      $newHooks = @{}
      foreach ($p in $obj.hooks.PSObject.Properties) {
        $kept = @()
        foreach ($entry in @($p.Value)) {
          # 묶음(그룹) 안에서 안전장치 훅 '하나하나'만 뺀다 — 같은 묶음의 다른 훅은 남긴다 (v1.1.7)
          if ($entry.PSObject.Properties.Name -contains 'hooks') {
            $inner = @(@($entry.hooks) | Where-Object { -not (Test-Ours $_) })
            if ($inner.Count -ne @($entry.hooks).Count) { $changed = $true }
            if ($inner.Count -gt 0) {
              $entry | Add-Member -NotePropertyName 'hooks' -NotePropertyValue $inner -Force
              $kept += $entry
            }
          } elseif (Test-Ours $entry) { $changed = $true } else { $kept += $entry }
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
    # 설치기가 더한 읽기 금지 목록(permissions.deny)만 뺀다 — install.ps1 3.5단계와 같은 목록 (v1.1.7)
    # (설치 전부터 똑같은 항목을 직접 넣어 두었다면 그것도 함께 빠진다)
    if ($obj.PSObject.Properties.Name -contains 'permissions' -and $obj.permissions -and
        $obj.permissions.PSObject.Properties.Name -contains 'deny' -and $obj.permissions.deny) {
      $homeSlash = $env:USERPROFILE -replace '\\', '/'
      if ($homeSlash -match '^([A-Za-z]):(.*)$') { $homeAbs = '//' + $Matches[1].ToLower() + $Matches[2] }
      else { $homeAbs = '/' + $homeSlash.TrimStart('/') }
      $denyPaths = @(
        '**/.env', '**/.env.*', '**/*.env', '**/apikeys/**',
        '//**/.env', '//**/.env.*', '//**/*.env', '//**/apikeys/**',
        '~/.secrets/**', "$homeAbs/.secrets/**",
        '~/.ssh/**', "$homeAbs/.ssh/**",
        '~/.aws/**', "$homeAbs/.aws/**"
      )
      $KitDeny = @()
      foreach ($t in 'Read', 'Grep', 'Write', 'Edit') { foreach ($dp in $denyPaths) { $KitDeny += "$t($dp)" } }
      $KitDeny += 'Bash(git push --force*)', 'Bash(git push -f*)', 'Bash(git reset --hard*)', 'Bash(rm -rf /*)', 'Bash(rm -rf ~*)'
      $before = @($obj.permissions.deny)
      $after  = @($before | Where-Object { $KitDeny -notcontains $_ })
      if ($after.Count -ne $before.Count) {
        if ($after.Count -gt 0) { $obj.permissions | Add-Member -NotePropertyName 'deny' -NotePropertyValue $after -Force }
        else { $obj.permissions.PSObject.Properties.Remove('deny') }
        $json = $obj | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($settings, $json, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "   ✓ 읽기 금지 목록에서 안전장치 항목 $($before.Count - $after.Count)개 해제 (다른 항목은 그대로)"
      }
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
