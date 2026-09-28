<#
.SYNOPSIS
  MAY MOI - mot lenh lam het: tao junction sang o du lieu + khoi phuc thu vien tu backup.

.DESCRIPTION
  Thu tu: dong app -> Setup-Junctions (di chuyen du lieu C: hien co, tao 4 junction)
          -> Restore-Library (mirror thu vien tu backup vao junction) -> Verify.
  Chay SAU khi da cai RealGUIDE tren may moi (hoac truoc cung duoc - junction se tao san).

.EXAMPLE
  .\Setup-NewMachine.ps1 -DataRoot "D:\RealGuideData" -BackupPath "F:\RealGuideLibrary-20260928-0900"
.EXAMPLE
  # Chay tu ben trong thu muc backup (Setup-NewMachine.cmd goi kieu nay): tu suy ra BackupPath
  .\Setup-NewMachine.ps1 -DataRoot "D:\RealGuideData"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DataRoot,
    [string]$BackupPath,
    [switch]$RestorePatientDb,
    [switch]$RestoreConfig,
    [switch]$SkipJunctions      # chi khoi phuc thu vien, khong dung junction (de du lieu tren C:)
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

if (-not $BackupPath) {
    # Bo cong cu duoc Backup-Library.ps1 copy vao <backup>\RealGuide-Migrate\ -> cha cua no la backup
    $guess = Split-Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path $guess 'manifest.json')) { $BackupPath = $guess }
    else { Write-Err "Khong suy ra duoc BackupPath - hay truyen -BackupPath."; exit 1 }
}
if (-not (Test-Path $BackupPath)) { Write-Err "Khong thay backup: $BackupPath"; exit 1 }

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " RealGuide-Migrate $script:ToolVersion - THIET LAP MAY MOI" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Du lieu  : $DataRoot"
Write-Host " Backup   : $BackupPath"
Write-Host " DB BN    : $(if ($RestorePatientDb) {'co'} else {'khong'})"
Write-Host " Junction : $(if ($SkipJunctions) {'bo qua'} else {'tao'})"
Write-Host ""

if (-not $SkipJunctions) {
    & "$PSScriptRoot\Setup-Junctions.ps1" -DataRoot $DataRoot
}

$restoreArgs = @{ BackupPath = $BackupPath }
if ($RestorePatientDb) { $restoreArgs.RestorePatientDb = $true }
if ($RestoreConfig)    { $restoreArgs.RestoreConfig = $true }
& "$PSScriptRoot\Restore-Library.ps1" @restoreArgs

& "$PSScriptRoot\Verify-Setup.ps1" -DataRoot $DataRoot
