<#
.SYNOPSIS
  Chuyen du lieu RealGUIDE tu o C: sang thu muc DataRoot va tao junction.

.DESCRIPTION
  RealGUIDE ghi cung du lieu vao %APPDATA%, %LOCALAPPDATA% va C:\NNT. Script nay:
    - Neu duong dan C: la thu muc that: di chuyen noi dung sang DataRoot, xoa thu muc, tao junction.
    - Neu chua ton tai: tao thu muc dich rong + junction (dung ngay sau khi cai app hoac truoc khi cai).
    - Neu da la junction dung dich: bo qua. Sai dich: bao loi (khong tu sua tru khi -Force).
  Sau do test ghi xuyen tung junction.

.EXAMPLE
  .\Setup-Junctions.ps1 -DataRoot "D:\RealGuideData"
.EXAMPLE
  .\Setup-Junctions.ps1 -DataRoot "D:\RealGuideData" -Undo   # go junction, dua du lieu ve C:
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DataRoot,
    [switch]$Undo,     # go junction va chuyen du lieu ve lai C:
    [switch]$Force     # cho phep thay junction dang tro sai dich
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
if (-not $isAdmin) { Write-Warn "Khong chay voi quyen Admin - tao C:\NNT co the that bai." }

Stop-RealGuide
$maps = Get-RealGuideMappings -DataRoot $DataRoot

if ($Undo) {
    Write-Step "GO JUNCTION - dua du lieu ve C:"
    foreach ($m in $maps) {
        $item = Get-Item $m.Link -Force -ErrorAction SilentlyContinue
        if (-not $item) { Write-Info "Khong co: $($m.Link)"; continue }
        if ($item.LinkType -ne 'Junction') { Write-Info "Da la thu muc that: $($m.Link)"; continue }
        Remove-JunctionOnly -Link $m.Link
        if (Test-Path $m.Target) {
            Write-Host "  Chuyen ve $($m.Link) ..." -NoNewline
            Invoke-Robocopy -Source $m.Target -Destination $m.Link -Options @('/E', '/MOVE') | Out-Null
            Write-Host " xong" -ForegroundColor Green
        } else { New-Item -ItemType Directory -Path $m.Link -Force | Out-Null }
        Write-Ok "$($m.Name): da ve thu muc that."
    }
    Write-Step "XONG. Gio co the chay Uninstall.exe an toan."
    exit 0
}

Write-Step "TAO JUNCTION -> $DataRoot"
New-Item -ItemType Directory -Path $DataRoot -Force | Out-Null

foreach ($m in $maps) {
    Write-Host "`n  * $($m.Name)" -ForegroundColor White
    Write-Host "    $($m.Link)  ->  $($m.Target)"
    $item = Get-Item $m.Link -Force -ErrorAction SilentlyContinue

    if ($item -and $item.LinkType -eq 'Junction') {
        $cur = ($item.Target | Select-Object -First 1)
        if ($cur -and $cur.TrimEnd('\') -ieq $m.Target.TrimEnd('\')) { Write-Ok "Junction da dung - bo qua."; continue }
        if (-not $Force) { Write-Err "Junction dang tro '$cur'. Dung -Force de thay."; continue }
        Remove-JunctionOnly -Link $m.Link
        $item = $null
    }

    if ($item) {
        # Thu muc that -> di chuyen noi dung sang dich
        $s = Get-DirStats $m.Link
        Write-Host "    Di chuyen $($s.Files) file ($(Format-Bytes $s.Bytes)) ..." -NoNewline
        New-Item -ItemType Directory -Path $m.Target -Force | Out-Null
        Invoke-Robocopy -Source $m.Link -Destination $m.Target -Options @('/E', '/MOVE') | Out-Null
        Write-Host " xong" -ForegroundColor Green
        if (Test-Path $m.Link) { Remove-Item $m.Link -Recurse -Force }
    } else {
        New-Item -ItemType Directory -Path $m.Target -Force | Out-Null
    }

    $parent = Split-Path $m.Link -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    & cmd.exe /c mklink /J "$($m.Link)" "$($m.Target)" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Err "mklink that bai."; continue }

    if (Test-JunctionWrite -Link $m.Link -Target $m.Target) { Write-Ok "Junction OK, ghi xuyen OK." }
    else { Write-Err "Tao junction nhung ghi xuyen THAT BAI - kiem tra quyen." }
}

Write-Step "TRANG THAI"
foreach ($m in $maps) {
    $i = Get-Item $m.Link -Force -ErrorAction SilentlyContinue
    $st = if (-not $i) { 'KHONG CO' } elseif ($i.LinkType -eq 'Junction') { "Junction -> $($i.Target)" } else { 'Thu muc that' }
    Write-Host ("  {0,-28} {1}" -f $m.Name, $st)
}
Write-Host ""
Write-Host "LUU Y: Truoc khi chay Uninstall.exe cua RealGUIDE, chay lai script nay voi -Undo de go junction," -ForegroundColor Yellow
Write-Host "       tranh trinh go cai dat xoa lan sang du lieu that." -ForegroundColor Yellow
