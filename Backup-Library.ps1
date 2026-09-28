<#
.SYNOPSIS
  Backup thu vien RealGUIDE (implant/sleeve/CAD/templates) de mang sang may khac.

.DESCRIPTION
  Copy cac thu muc thu vien + file index tu %APPDATA%\RealguideZimmerBiomet (di xuyen junction
  neu co) vao thu muc backup kem manifest.json. Tuy chon kem DB benh nhan.

.EXAMPLE
  .\Backup-Library.ps1 -Destination "F:\RealGuideBackup"
.EXAMPLE
  .\Backup-Library.ps1 -Destination "F:\RealGuideBackup" -IncludePatientDb -IncludeConfig
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Destination,
    [switch]$IncludePatientDb,   # kem RealGUIDE50-DB (co the rat lon, hang chuc GB)
    [switch]$IncludeConfig,      # kem *.ini/*.dat/*.set/*.xlb (cau hinh may hien tai)
    [switch]$NoTimestamp,        # ghi thang vao $Destination thay vi tao thu muc con theo ngay
    [switch]$CloseApp            # tu dong dong RealGUIDE neu dang chay
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

$lib = Get-LibraryPath
if (-not (Test-Path $lib)) { Write-Err "Khong tim thay thu vien: $lib"; exit 1 }

if (Get-Process RealGUIDE -ErrorAction SilentlyContinue) {
    if ($CloseApp) { Stop-RealGuide }
    else { Write-Warn "RealGUIDE dang chay. Nen dong app hoac dung -CloseApp de backup nhat quan." }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dest = if ($NoTimestamp) { $Destination } else { Join-Path $Destination "RealGuideLibrary-$stamp" }
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$manifest = [ordered]@{
    tool          = "RealGuide-Migrate $script:ToolVersion"
    created       = (Get-Date).ToString('s')
    sourceMachine = $env:COMPUTERNAME
    sourceUser    = $env:USERNAME
    sourceLibrary = (Get-Item $lib -Force).Target -join ',' ; # rong neu khong phai junction
    items         = [ordered]@{}
}
if (-not $manifest.sourceLibrary) { $manifest.sourceLibrary = $lib }

Write-Step "Backup thu vien: $lib -> $dest"
$libDest = Join-Path $dest 'RealguideZimmerBiomet'
New-Item -ItemType Directory -Path $libDest -Force | Out-Null

foreach ($d in $script:LibraryDirs) {
    $src = Join-Path $lib $d
    if (-not (Test-Path $src)) { Write-Info "Bo qua (khong co): $d"; continue }
    Write-Host "  Copy $d ..." -NoNewline
    Invoke-Robocopy -Source $src -Destination (Join-Path $libDest $d) -Options @('/MIR') | Out-Null
    $s = Get-DirStats (Join-Path $libDest $d)
    $manifest.items[$d] = @{ files = $s.Files; bytes = $s.Bytes }
    Write-Host " $($s.Files) file, $(Format-Bytes $s.Bytes)" -ForegroundColor Green
}

Write-Host "  Copy index (*.imp, *.pin) ..." -NoNewline
Invoke-Robocopy -Source $lib -Destination $libDest -Files $script:IndexPatterns -Options @() | Out-Null
$idx = Get-ChildItem "$libDest\*" -File -Include $script:IndexPatterns
Write-Host " $($idx.Count) file" -ForegroundColor Green
$manifest.items['index'] = @{ files = $idx.Count; names = @($idx.Name) }

if ($IncludeConfig) {
    Write-Host "  Copy cau hinh (*.ini, *.dat, *.set, *.xlb) ..." -NoNewline
    Invoke-Robocopy -Source $lib -Destination $libDest -Files $script:ConfigPatterns -Options @() | Out-Null
    $cfg = Get-ChildItem "$libDest\*" -File -Include $script:ConfigPatterns
    Write-Host " $($cfg.Count) file" -ForegroundColor Green
    $manifest.items['config'] = @{ files = $cfg.Count; names = @($cfg.Name) }
}

# Sleeve da "chot so" (.stl.dec) - giu lai de may moi khong bi "Polygon count is zero"
$decs = Join-Path $lib 'tmp\decs'
if (Test-Path $decs) {
    Write-Host "  Copy tmp\decs (*.stl.dec) ..." -NoNewline
    Invoke-Robocopy -Source $decs -Destination (Join-Path $libDest 'tmp\decs') -Files @('*.stl.dec') -Options @() | Out-Null
    $n = (Get-ChildItem (Join-Path $libDest 'tmp\decs') -Filter '*.stl.dec' -ErrorAction SilentlyContinue).Count
    Write-Host " $n file" -ForegroundColor Green
    $manifest.items['stl.dec'] = @{ files = $n }
}

if ($IncludePatientDb) {
    $db = Get-PatientDbPath
    if (Test-Path $db) {
        Write-Step "Backup DB benh nhan: $db"
        $s0 = Get-DirStats $db
        Write-Info "Kich thuoc nguon: $($s0.Files) file, $(Format-Bytes $s0.Bytes)"
        Invoke-Robocopy -Source $db -Destination (Join-Path $dest 'RealGUIDE50-DB') -Options @('/MIR', '/XD', 'backup') | Out-Null
        $s = Get-DirStats (Join-Path $dest 'RealGUIDE50-DB')
        $manifest.items['RealGUIDE50-DB'] = @{ files = $s.Files; bytes = $s.Bytes }
        Write-Ok "$($s.Files) file, $(Format-Bytes $s.Bytes)"
    } else { Write-Warn "Khong thay DB benh nhan: $db" }
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dest 'manifest.json') -Encoding UTF8

# Kem bo cong cu vao backup de may moi chay ngay khong can copy rieng
$toolsDest = Join-Path $dest 'RealGuide-Migrate'
New-Item -ItemType Directory -Path $toolsDest -Force | Out-Null
Copy-Item "$PSScriptRoot\*.ps1", "$PSScriptRoot\*.cmd", "$PSScriptRoot\README.md" $toolsDest -Force -ErrorAction SilentlyContinue

$total = Get-DirStats $dest
Write-Step "HOAN TAT"
Write-Ok "Vi tri : $dest"
Write-Ok "Tong   : $($total.Files) file, $(Format-Bytes $total.Bytes)"
Write-Host ""
Write-Host "Tren may moi: cai RealGUIDE -> chay 'RealGuide-Migrate\Setup-NewMachine.cmd' (Admin) trong thu muc backup nay." -ForegroundColor Yellow
