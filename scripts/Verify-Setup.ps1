<#
.SYNOPSIS
  Kiem tra tinh trang junction + thu vien RealGUIDE tren may hien tai.
.EXAMPLE
  .\Verify-Setup.ps1 -DataRoot "E:\RealGuideData"
#>
[CmdletBinding()]
param([string]$DataRoot)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\Common.ps1"

Write-Step "JUNCTION"
$maps = if ($DataRoot) { Get-RealGuideMappings -DataRoot $DataRoot } else { Get-RealGuideMappings -DataRoot '?' }
foreach ($m in $maps) {
    $i = Get-Item $m.Link -Force -ErrorAction SilentlyContinue
    if (-not $i) { Write-Host ("  {0,-26} KHONG CO   {1}" -f $m.Name, $m.Link) -ForegroundColor Gray; continue }
    if ($i.LinkType -eq 'Junction') {
        $t = $i.Target | Select-Object -First 1
        $ok = Test-Path $t
        $s = Get-DirStats $t
        $color = if ($ok) { 'Green' } else { 'Red' }
        Write-Host ("  {0,-26} Junction   {1} -> {2}  [{3} file, {4}]" -f $m.Name, $m.Link, $t, $s.Files, (Format-Bytes $s.Bytes)) -ForegroundColor $color
        if (-not $ok) { Write-Err "Dich khong ton tai!" }
    } else {
        $s = Get-DirStats $m.Link
        Write-Host ("  {0,-26} Thu muc that (tren C:)  [{1} file, {2}]" -f $m.Name, $s.Files, (Format-Bytes $s.Bytes)) -ForegroundColor Yellow
    }
}

Write-Step "THU VIEN"
$lib = Get-LibraryPath
if (-not (Test-Path $lib)) { Write-Err "Khong co $lib"; exit 1 }
foreach ($d in $script:LibraryDirs) {
    $p = Join-Path $lib $d
    if (Test-Path $p) { $s = Get-DirStats $p; Write-Host ("  {0,-14} {1,6} file  {2,10}" -f $d, $s.Files, (Format-Bytes $s.Bytes)) }
    else { Write-Host ("  {0,-14} (khong co)" -f $d) -ForegroundColor Gray }
}
$idx = Get-ChildItem "$lib\*" -File -Include $script:IndexPatterns
Write-Host ("  {0,-14} {1}" -f 'index', (($idx | ForEach-Object Name) -join ', '))
if ($idx.Count -lt 4) { Write-Warn "Thieu file index (mong doi sleeves.imp/.pin, models.imp/.pin)." }

Write-Step "SLEEVE (tmp\decs)"
$decs = Join-Path $lib 'tmp\decs'
if (Test-Path $decs) {
    $parts = Get-ChildItem $decs -Filter '*.part' -File
    $decsN = (Get-ChildItem $decs -Filter '*.stl.dec' -File).Count
    $stuck = $parts | Where-Object { -not (Test-Path (Join-Path $decs "$($_.BaseName).stl.dec")) }
    Write-Host "  .part: $($parts.Count)   .stl.dec: $decsN   ket (chua co .stl.dec): $($stuck.Count)"
    if ($stuck.Count -gt 0) { Write-Warn "Co sleeve ket -> chay Repair-Sleeves.ps1" }
} else { Write-Info "Chua co tmp\decs (app chua giai nen sleeve nao)." }

$zero = Get-ChildItem (Join-Path $lib 'asset_cache') -Recurse -File -ErrorAction SilentlyContinue | Where-Object Length -eq 0
if ($zero) { Write-Warn "asset_cache co $($zero.Count) file 0-byte (server tra rong) - binh thuong neu app van chay." }

Write-Step "APP"
$exe = Get-ItemProperty 'HKCU:\SOFTWARE\RealGUIDE5' -ErrorAction SilentlyContinue
if ($exe) { Write-Ok "Registry HKCU\SOFTWARE\RealGUIDE5 co: $($exe.InstallString)" } else { Write-Warn "Chua thay registry RealGUIDE5 - app chua cai?" }
if (Get-Process RealGUIDE -ErrorAction SilentlyContinue) { Write-Info "RealGUIDE dang chay." }
