<#
.SYNOPSIS
  Sao chep mot ban backup thu vien co san sang USB / o ngoai / o khac (kem bo cong cu) de mang sang may moi.

.DESCRIPTION
  Khong backup lai tu app - chi copy nguyen ban backup da co (robocopy /E, chay lai duoc, bo qua file da co).
  Backup dang cu (phang, LibraryBackup-...) se duoc chuyen sang dang chuan (RealguideZimmerBiomet\ + manifest.json).

.EXAMPLE
  .\Export-Backup.ps1 -BackupPath "E:\RealGuideData\Backups\RealGuideLibrary-20260928-0903" -Destination "F:\"
.EXAMPLE
  .\Export-Backup.ps1 -List      # liet ke backup co san tren may
#>
[CmdletBinding()]
param(
    [string]$BackupPath,
    [string]$Destination,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

if ($List -or -not $BackupPath) {
    Write-Step "Backup thu vien co san tren may"
    $all = Find-ExistingBackups
    if (-not $all) { Write-Warn "Khong tim thay backup nao."; exit 0 }
    foreach ($b in $all) {
        $s = Get-DirStats $b.Path
        Write-Host ("  {0,-19} {1,-11} {2,7} file {3,10}   {4}" -f $b.Created.ToString('yyyy-MM-dd HH:mm'), $b.Type, $s.Files, (Format-Bytes $s.Bytes), $b.Path)
    }
    exit 0
}

if (-not (Test-Path $BackupPath)) { Write-Err "Khong thay backup: $BackupPath"; exit 1 }
if (-not $Destination) { Write-Err "Thieu -Destination."; exit 1 }

$isStd = Test-Path (Join-Path $BackupPath 'manifest.json')
$name  = Split-Path $BackupPath -Leaf
$dest  = Join-Path $Destination $name
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$src = Get-DirStats $BackupPath
$free = (Get-PSDrive ((Resolve-Path $Destination).Drive.Name) -ErrorAction SilentlyContinue).Free
if ($free -and $free -lt $src.Bytes) { Write-Err "O dich chi con $(Format-Bytes $free), can $(Format-Bytes $src.Bytes)."; exit 1 }

Write-Step "Copy backup: $BackupPath -> $dest ($(Format-Bytes $src.Bytes))"
if ($isStd) {
    Invoke-Robocopy -Source $BackupPath -Destination $dest -Options @('/E', '/XD', 'RealGuide-Migrate') | Out-Null
} else {
    # Chuyen dang cu -> chuan
    Write-Info "Backup dang cu (phang) -> chuyen sang dang chuan."
    $libDest = Join-Path $dest 'RealguideZimmerBiomet'
    Invoke-Robocopy -Source $BackupPath -Destination $libDest -Options @('/E') | Out-Null
    [ordered]@{
        tool = "RealGuide-Migrate $script:ToolVersion (export tu backup cu)"; created = (Get-Item $BackupPath).LastWriteTime.ToString('s')
        sourceMachine = $env:COMPUTERNAME; sourceUser = $env:USERNAME; sourceLibrary = $BackupPath; items = @{}
    } | ConvertTo-Json | Set-Content (Join-Path $dest 'manifest.json') -Encoding UTF8
}

# Kem bo cong cu (phien ban hien tai)
$tools = Join-Path $dest 'RealGuide-Migrate'
New-Item -ItemType Directory -Path $tools -Force | Out-Null
Copy-Item "$PSScriptRoot\*.ps1", "$PSScriptRoot\*.cmd", "$PSScriptRoot\README.md" $tools -Force -ErrorAction SilentlyContinue

$d = Get-DirStats $dest
Write-Step "HOAN TAT"
Write-Ok "Dich : $dest"
Write-Ok "Tong : $($d.Files) file, $(Format-Bytes $d.Bytes)"
Write-Host ""
Write-Host "Tren may moi: mo '$name\RealGuide-Migrate\RealGuide-Migrate.cmd' -> Tab 2 -> THIET LAP MAY MOI." -ForegroundColor Yellow
