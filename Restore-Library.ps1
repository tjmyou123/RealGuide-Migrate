<#
.SYNOPSIS
  Khoi phuc thu vien RealGUIDE tu thu muc backup (do Backup-Library.ps1 tao).

.DESCRIPTION
  Mirror tung thu muc thu vien (robocopy /MIR - xoa ca file rac 0-byte phat sinh),
  khoi phuc file index goc, copy .stl.dec da chot so, roi va sleeve ket.
  Dich la %APPDATA%\RealguideZimmerBiomet (di xuyen junction neu da tao).

.EXAMPLE
  .\Restore-Library.ps1 -BackupPath "F:\RealGuideBackup\RealGuideLibrary-20260928-0900"
.EXAMPLE
  .\Restore-Library.ps1 -BackupPath "..." -RestorePatientDb -RestoreConfig
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BackupPath,
    [switch]$RestorePatientDb,   # khoi phuc RealGUIDE50-DB (neu backup co)
    [switch]$RestoreConfig       # khoi phuc *.ini/*.dat/*.set/*.xlb (co the mang cau hinh may cu sang)
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

$srcLib = Join-Path $BackupPath 'RealguideZimmerBiomet'
if (-not (Test-Path $srcLib)) {
    # Tuong thich backup cu (LibraryBackup-20260819: khong co thu muc con)
    if (Test-Path (Join-Path $BackupPath 'stldb')) { $srcLib = $BackupPath }
    else { Write-Err "Khong thay thu vien trong backup: $BackupPath"; exit 1 }
}

$mf = Join-Path $BackupPath 'manifest.json'
if (Test-Path $mf) {
    $m = Get-Content $mf -Raw | ConvertFrom-Json
    Write-Info "Backup tao $($m.created) tren may $($m.sourceMachine) ($($m.sourceUser))"
}

$lib = Get-LibraryPath
if (-not (Test-Path $lib)) {
    Write-Warn "Chua co $lib - RealGUIDE chua duoc cai/chay lan dau? Tao thu muc trong."
    New-Item -ItemType Directory -Path $lib -Force | Out-Null
}
$linkInfo = Get-Item $lib -Force
if ($linkInfo.LinkType -eq 'Junction') { Write-Info "Dich la junction -> $($linkInfo.Target)" }

Stop-RealGuide

Write-Step "Khoi phuc thu vien -> $lib"
foreach ($d in $script:LibraryDirs) {
    $src = Join-Path $srcLib $d
    if (-not (Test-Path $src)) { continue }
    Write-Host "  Mirror $d ..." -NoNewline
    Invoke-Robocopy -Source $src -Destination (Join-Path $lib $d) -Options @('/MIR') | Out-Null
    $s = Get-DirStats (Join-Path $lib $d)
    Write-Host " $($s.Files) file, $(Format-Bytes $s.Bytes)" -ForegroundColor Green
}

Write-Host "  Index (*.imp, *.pin) ..." -NoNewline
Invoke-Robocopy -Source $srcLib -Destination $lib -Files $script:IndexPatterns -Options @() | Out-Null
Write-Host " xong" -ForegroundColor Green

if ($RestoreConfig) {
    Write-Host "  Cau hinh (*.ini, *.dat, *.set, *.xlb) ..." -NoNewline
    Invoke-Robocopy -Source $srcLib -Destination $lib -Files $script:ConfigPatterns -Options @() | Out-Null
    Write-Host " xong" -ForegroundColor Green
}

$srcDecs = Join-Path $srcLib 'tmp\decs'
if (Test-Path $srcDecs) {
    Write-Host "  tmp\decs (*.stl.dec) ..." -NoNewline
    Invoke-Robocopy -Source $srcDecs -Destination (Join-Path $lib 'tmp\decs') -Files @('*.stl.dec') -Options @() | Out-Null
    Write-Host " xong" -ForegroundColor Green
}

Write-Step "Va sleeve ket (.part -> .stl.dec)"
Repair-StuckSleeves -LibraryPath $lib

if ($RestorePatientDb) {
    $srcDb = Join-Path $BackupPath 'RealGUIDE50-DB'
    if (Test-Path $srcDb) {
        $db = Get-PatientDbPath
        Write-Step "Khoi phuc DB benh nhan -> $db"
        Invoke-Robocopy -Source $srcDb -Destination $db -Options @('/E') | Out-Null
        $s = Get-DirStats $db
        Write-Ok "$($s.Files) file, $(Format-Bytes $s.Bytes)"
    } else { Write-Warn "Backup khong co RealGUIDE50-DB." }
}

Write-Step "XONG. Mo RealGUIDE va kiem tra thu vien implant/sleeve."
