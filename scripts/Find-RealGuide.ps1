<#
.SYNOPSIS
  Tu tim RealGUIDE dang luu file o dau tren may nay (app, thu vien, DB benh nhan, cache, junction).
.EXAMPLE
  .\Find-RealGuide.ps1              # nhanh: registry + %APPDATA% + %LOCALAPPDATA%
  .\Find-RealGuide.ps1 -ScanDrives  # quet them cac o dia (tim backup/du lieu chuyen tay)
  .\Find-RealGuide.ps1 -AsJson
#>
[CmdletBinding()]
param([switch]$ScanDrives, [switch]$AsJson)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\Common.ps1"

$p = Find-RealGuidePaths -ScanDrives:$ScanDrives
if ($AsJson) { $p | ConvertTo-Json -Depth 4; exit 0 }

function Show { param($Label, $Path, $Src, $Found = $true)
    $exists = $Path -and (Test-Path $Path)
    $color = if (-not $exists) { 'Gray' } elseif ($Found) { 'Green' } else { 'Yellow' }
    $s = if ($exists -and (Get-Item $Path -Force).PSIsContainer) { $st = Get-DirStats $Path; "  [$($st.Files) file, $(Format-Bytes $st.Bytes)]" } else { '' }
    $j = if ($Path) { Resolve-LinkTarget $Path } else { $null }
    Write-Host ("  {0,-22} {1}" -f $Label, $(if ($Path) { $Path } else { '(khong thay)' })) -ForegroundColor $color -NoNewline
    Write-Host $s -ForegroundColor DarkGray
    if ($j)   { Write-Host ("  {0,-22}   -> junction toi: {1}" -f '', $j) -ForegroundColor Cyan }
    if ($Src) { Write-Host ("  {0,-22}   nguon: {1}" -f '', $Src) -ForegroundColor DarkGray }
}

Write-Step "UNG DUNG"
Show 'RealGUIDE.exe' $p.Exe $p.Source.Exe
Show 'Thu muc cai'   $p.AppDir
Show 'Uninstall.exe' $p.Uninstall

Write-Step "DU LIEU (noi RealGUIDE ghi cung)"
Show 'Thu vien implant'  $p.Library   $p.Source.Library   $p.Found.Library
Show 'DB benh nhan'      $p.PatientDb $p.Source.PatientDb $p.Found.PatientDb
Show 'QML cache'         $p.QmlCache  $p.Source.QmlCache  $p.Found.QmlCache
Show 'NNT ini'           $p.NNT       $p.Source.NNT       $p.Found.NNT

if ($p.Extra.Count) {
    Write-Step "TIM THAY THEM TREN CAC O DIA"
    $p.Extra | ForEach-Object { Write-Host ("  {0,-10} {1}" -f $_.Kind, $_.Path) }
}

$notFound = @($p.Found.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
if ($notFound.Count) {
    Write-Host ""
    Write-Warn "Chua thay: $($notFound -join ', ') -> dung ten mac dinh (mau vang). App chua cai hoac chua chay lan dau?"
}
