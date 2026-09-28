# Common.ps1 - ham dung chung cho bo cong cu RealGuide-Migrate
# Khong chay truc tiep file nay; cac script khac se dot-source no.

$script:ToolVersion = "1.0"

# Thu muc thu vien can backup/khoi phuc trong RealguideZimmerBiomet
$script:LibraryDirs    = 'stldb', 'stlcaddb', 'asset_cache', '3D_Templates', 'templates'
# File index sleeve/implant o goc (bat buoc)
$script:IndexPatterns  = '*.imp', '*.pin'
# File cau hinh o goc (tuy chon - co the chua thong tin rieng cua may/tai khoan)
$script:ConfigPatterns = '*.ini', '*.dat', '*.set', '*.xlb'

function Write-Step { param([string]$Msg) Write-Host "`n== $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "  [OK]   $Msg" -ForegroundColor Green }
function Write-Info { param([string]$Msg) Write-Host "  [INFO] $Msg" -ForegroundColor Gray }
function Write-Warn { param([string]$Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "  [LOI]  $Msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# TU PHAT HIEN duong dan RealGUIDE tren may hien tai
#   1. Registry HKCU/HKLM\SOFTWARE\RealGUIDE5: InstallString (exe), UninstallFolder (thu vien AppData)
#   2. Quet %APPDATA% theo dau hieu: thu vien co sleeves.imp/stldb, DB co xmlStudiesList.xml
#   3. Quet nhanh cac o dia khac (do sau 2) tim ban sao/du lieu da chuyen tay
# Neu khong tim thay -> dung ten mac dinh (Found=$false) de van tao duoc junction truoc khi cai app.
# ---------------------------------------------------------------------------
function Test-LibraryFolder { param([string]$P) (Test-Path -LiteralPath "$P\sleeves.imp") -or (Test-Path -LiteralPath "$P\stldb") -or (Test-Path -LiteralPath "$P\asset_cache") }
function Test-PatientDbFolder { param([string]$P) (Test-Path -LiteralPath "$P\xmlStudiesList.xml") -or (Test-Path -LiteralPath "$P\Storage") }

function Resolve-LinkTarget {
    param([string]$Path)
    $i = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if ($i -and $i.LinkType -eq 'Junction') { return ($i.Target | Select-Object -First 1) }
    return $null
}

function Find-RealGuidePaths {
    param([switch]$ScanDrives)   # quet them cac o dia (cham hon vai giay)

    $r = [ordered]@{
        Exe = $null; Uninstall = $null; AppDir = $null
        Library = $null; PatientDb = $null; QmlCache = $null; NNT = $null
        Source = [ordered]@{}; Extra = @()
    }

    # 1. Registry
    foreach ($k in 'HKCU:\SOFTWARE\RealGUIDE5', 'HKLM:\SOFTWARE\RealGUIDE5', 'HKLM:\SOFTWARE\WOW6432Node\RealGUIDE5') {
        $reg = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if (-not $reg) { continue }
        if (-not $r.Exe -and $reg.InstallString)       { $r.Exe = $reg.InstallString; $r.Source.Exe = $k }
        if (-not $r.Uninstall -and $reg.UninstallString) { $r.Uninstall = $reg.UninstallString }
        if (-not $r.Library -and $reg.UninstallFolder -and (Test-Path $reg.UninstallFolder)) { $r.Library = $reg.UninstallFolder; $r.Source.Library = "$k\UninstallFolder" }
    }
    if ($r.Exe) { $r.AppDir = Split-Path (Split-Path $r.Exe -Parent) -Parent }

    # 2. Quet %APPDATA%
    $appdataDirs = Get-ChildItem $env:APPDATA -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Real ?guide' }
    if (-not $r.Library) {
        $c = $appdataDirs | Where-Object { $_.Name -notmatch '-DB$' -and (Test-LibraryFolder $_.FullName) } | Select-Object -First 1
        if ($c) { $r.Library = $c.FullName; $r.Source.Library = 'quet %APPDATA% (sleeves.imp/stldb)' }
    }
    $c = $appdataDirs | Where-Object { $_.Name -match '-DB$' -and (Test-PatientDbFolder $_.FullName) } | Select-Object -First 1
    if ($c) { $r.PatientDb = $c.FullName; $r.Source.PatientDb = 'quet %APPDATA% (xmlStudiesList.xml)' }

    # QML cache (%LOCALAPPDATA%\RealGUIDE\cache|qmlcache)
    $q = Get-ChildItem $env:LOCALAPPDATA -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^RealGUIDE' } | Select-Object -First 1
    if ($q) { $r.QmlCache = $q.FullName; $r.Source.QmlCache = 'quet %LOCALAPPDATA%' }

    # NNT
    if (Test-Path 'C:\NNT') { $r.NNT = 'C:\NNT'; $r.Source.NNT = 'C:\NNT ton tai' }

    # 3. Quet o dia khac (thu muc du lieu chuyen tay, backup...)
    if ($ScanDrives) {
        $roots = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -and (Test-Path $_.Root) -and $_.DisplayRoot -eq $null } | ForEach-Object Root
        foreach ($root in $roots) {
            $hits = Get-ChildItem -LiteralPath $root -Directory -Recurse -Depth 2 -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^Real ?guide' -and $_.FullName -notlike "$env:APPDATA*" -and $_.FullName -notlike "$env:LOCALAPPDATA*" }
            foreach ($h in $hits) {
                $kind = if (Test-LibraryFolder $h.FullName) { 'Library' } elseif (Test-PatientDbFolder $h.FullName) { 'PatientDb' } elseif (Test-Path -LiteralPath "$($h.FullName)\manifest.json") { 'Backup' } elseif (Test-Path -LiteralPath "$($h.FullName)\bin\RealGUIDE.exe") { 'AppDir' } else { $null }
                if ($kind) { $r.Extra += [pscustomobject]@{ Kind = $kind; Path = $h.FullName } }
            }
        }
    }

    # Mac dinh neu chua thay (may moi chua cai app)
    $r.Found = [ordered]@{ Library = [bool]$r.Library; PatientDb = [bool]$r.PatientDb; QmlCache = [bool]$r.QmlCache; NNT = [bool]$r.NNT }
    if (-not $r.Library)   { $r.Library   = "$env:APPDATA\RealguideZimmerBiomet"; $r.Source.Library = 'mac dinh (chua thay)' }
    if (-not $r.PatientDb) { $r.PatientDb = "$env:APPDATA\RealGUIDE50-DB";        $r.Source.PatientDb = 'mac dinh (chua thay)' }
    if (-not $r.QmlCache)  { $r.QmlCache  = "$env:LOCALAPPDATA\RealGUIDE";        $r.Source.QmlCache = 'mac dinh (chua thay)' }
    if (-not $r.NNT)       { $r.NNT       = 'C:\NNT';                             $r.Source.NNT = 'mac dinh (chua thay)' }

    # Junction hien tai (neu co)
    $r.Targets = [ordered]@{}
    foreach ($k in 'Library', 'PatientDb', 'QmlCache', 'NNT') { $t = Resolve-LinkTarget $r[$k]; if ($t) { $r.Targets[$k] = $t } }

    [pscustomobject]$r
}

# Cache ket qua trong phien de cac script khong quet lai
function Get-RealGuidePaths {
    if (-not $script:RgPaths) { $script:RgPaths = Find-RealGuidePaths }
    $script:RgPaths
}

# Tim cac ban backup thu vien co san tren may (USB, o ngoai, o du lieu)
#   - Dang chuan: <X>\RealGuideLibrary-<ngay>\{manifest.json, RealguideZimmerBiomet\}
#   - Dang cu (phang): <X>\LibraryBackup-<ngay>\{stldb, sleeves.imp}
function Find-ExistingBackups {
    param([string[]]$ExtraRoots = @())
    $roots = @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -and (Test-Path $_.Root) -and -not $_.DisplayRoot } | ForEach-Object Root)
    $roots += $ExtraRoots | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    # Loai thu vien DANG DUNG (khong phai backup)
    $rg = Get-RealGuidePaths
    $live = @($rg.Library, $rg.Targets['Library']) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\').ToLower() }
    $seen = @{}
    foreach ($l in $live) { $seen[$l] = $true }
    $out = @()
    foreach ($root in $roots) {
        # Loc theo TEN truoc (nhanh), roi moi kiem tra noi dung
        $dirs = Get-ChildItem -LiteralPath $root -Directory -Recurse -Depth 2 -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'realguide|librarybackup' -and $_.FullName -notmatch '\\(Windows|Program Files|Program Files \(x86\)|AppData)\\' }
        foreach ($d in $dirs) {
            $full = $d.FullName
            if ($seen[$full.ToLower()]) { continue }
            # Bo qua thu muc con RealguideZimmerBiomet nam TRONG mot backup chuan (da tinh o cha)
            if ($d.Parent -and (Test-Path -LiteralPath (Join-Path $d.Parent.FullName 'manifest.json'))) { continue }
            $isStd = (Test-Path -LiteralPath (Join-Path $full 'manifest.json')) -and (Test-Path -LiteralPath (Join-Path $full 'RealguideZimmerBiomet'))
            $isOld = (Test-Path -LiteralPath (Join-Path $full 'stldb')) -and ((Test-Path -LiteralPath (Join-Path $full 'sleeves.imp')) -or (Test-Path -LiteralPath (Join-Path $full 'models.imp')))
            if (-not ($isStd -or $isOld)) { continue }
            $seen[$full.ToLower()] = $true
            $created = $d.LastWriteTime; $machine = ''
            if ($isStd) {
                try { $m = Get-Content -LiteralPath (Join-Path $full 'manifest.json') -Raw | ConvertFrom-Json; $created = [datetime]$m.created; $machine = $m.sourceMachine } catch {}
            }
            $out += [pscustomobject]@{ Name = $d.Name; Path = $full; Type = $(if ($isStd) { 'chuan' } else { 'cu (phang)' }); Created = $created; Machine = $machine; Drive = $d.PSDrive.Name }
        }
    }
    $out | Sort-Object Created -Descending
}

# Bang anh xa: duong dan ma RealGUIDE ghi cung (Link) -> noi luu that (Target)
# Link lay tu tu phat hien; ten thu muc dich = ten thu muc goc (QML cache doi ten de khong trung)
function Get-RealGuideMappings {
    param([Parameter(Mandatory)][string]$DataRoot)
    $p = Get-RealGuidePaths
    @(
        [pscustomobject]@{ Name = 'Thu vien implant/sleeve'; Link = $p.Library;   Target = Join-Path $DataRoot (Split-Path $p.Library -Leaf) }
        [pscustomobject]@{ Name = 'DB benh nhan';            Link = $p.PatientDb; Target = Join-Path $DataRoot (Split-Path $p.PatientDb -Leaf) }
        [pscustomobject]@{ Name = 'QML cache';               Link = $p.QmlCache;  Target = Join-Path $DataRoot "$(Split-Path $p.QmlCache -Leaf)-QmlCache" }
        [pscustomobject]@{ Name = 'NNT ini';                 Link = $p.NNT;       Target = Join-Path $DataRoot (Split-Path $p.NNT -Leaf) }
    )
}

function Get-LibraryPath   { (Get-RealGuidePaths).Library }
function Get-PatientDbPath { (Get-RealGuidePaths).PatientDb }

# Dong RealGUIDE neu dang chay (nhe nhang truoc, ep buoc sau)
function Stop-RealGuide {
    $p = Get-Process RealGUIDE -ErrorAction SilentlyContinue
    if (-not $p) { Write-Info "RealGUIDE khong chay."; return }
    Write-Warn "RealGUIDE dang chay - dang dong..."
    $p | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Process RealGUIDE -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    Get-Process RealGUIDE -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    Write-Ok "Da dong RealGUIDE."
}

# Goi robocopy va kiem tra ma thoat (0-7 = thanh cong, >=8 = loi)
function Invoke-Robocopy {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [string[]]$Files = @(),
        [string[]]$Options = @('/E')
    )
    $args = @($Source, $Destination) + $Files + $Options + @('/R:2', '/W:2', '/NFL', '/NDL', '/NP', '/NJH', '/NJS')
    & robocopy.exe @args | Out-Null
    $code = $LASTEXITCODE
    if ($code -ge 8) { throw "robocopy loi (ma $code): '$Source' -> '$Destination'" }
    return $code
}

# Thong ke so file / dung luong mot thu muc
function Get-DirStats {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Files = 0; Bytes = 0 } }
    $m = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    [pscustomobject]@{ Files = [int]$m.Count; Bytes = [int64]($m.Sum) }
}

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

# Bo cuc bo cong cu: <ToolRoot>\RealGuide-Migrate.cmd + README.md + scripts\*.ps1 (file nay nam trong scripts\)
$script:ToolRoot = Split-Path $PSScriptRoot -Parent

# Khi bo cong cu nam trong 1 backup (<backup>\RealGuide-Migrate\scripts\Common.ps1) -> tra ve <backup>, khong thi $null
function Get-ContainingBackup {
    $d = $PSScriptRoot
    for ($i = 0; $i -lt 3 -and $d; $i++) {
        $d = Split-Path $d -Parent
        if ($d -and (Test-Path -LiteralPath (Join-Path $d 'manifest.json'))) { return $d }
    }
    return $null
}

# Chep bo cong cu (khong kem .git) vao $Destination\RealGuide-Migrate
function Copy-Tools {
    param([Parameter(Mandatory)][string]$Destination)
    $dst = Join-Path $Destination 'RealGuide-Migrate'
    New-Item -ItemType Directory -Path (Join-Path $dst 'scripts') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:ToolRoot 'RealGuide-Migrate.cmd'), (Join-Path $script:ToolRoot 'README.md') -Destination $dst -Force -ErrorAction SilentlyContinue
    Copy-Item "$PSScriptRoot\*.ps1", "$PSScriptRoot\*.cmd", "$PSScriptRoot\Strings.*.txt" (Join-Path $dst 'scripts') -Force -ErrorAction SilentlyContinue
    return $dst
}

# Va sleeve ket: tmp\decs\<GUID>.part (STL hoan chinh) -> <GUID>.stl.dec
# Chi copy khi xac thuc binary STL: size == 84 + 50 * so_tam_giac
function Repair-StuckSleeves {
    param([Parameter(Mandatory)][string]$LibraryPath)
    $decs = Join-Path $LibraryPath 'tmp\decs'
    if (-not (Test-Path $decs)) { Write-Info "Chua co $decs - bo qua."; return }

    $fixed = 0; $skipped = 0; $invalid = 0
    foreach ($part in Get-ChildItem $decs -Filter '*.part' -File) {
        $guid = $part.BaseName
        $dec  = Join-Path $decs "$guid.stl.dec"
        if (Test-Path $dec) { $skipped++; continue }

        $fs = [System.IO.File]::OpenRead($part.FullName)
        try {
            if ($fs.Length -lt 84) { $invalid++; continue }
            $buf = New-Object byte[] 4
            $fs.Position = 80
            [void]$fs.Read($buf, 0, 4)
            $ntri = [BitConverter]::ToUInt32($buf, 0)
            if ($ntri -eq 0 -or $fs.Length -ne (84 + 50 * [int64]$ntri)) { $invalid++; continue }
        } finally { $fs.Close() }

        Copy-Item $part.FullName $dec
        $fixed++
    }
    Write-Ok "Sleeve: va $fixed | da co san $skipped | do dang bo qua $invalid"
}

# Kiem tra ghi xuyen junction: tao file qua Link, phai thay o Target
function Test-JunctionWrite {
    param([string]$Link, [string]$Target)
    $name = "__junction_test_$([guid]::NewGuid().ToString('N')).tmp"
    try {
        Set-Content -Path (Join-Path $Link $name) -Value 'test' -ErrorAction Stop
        $ok = Test-Path (Join-Path $Target $name)
        Remove-Item (Join-Path $Target $name) -Force -ErrorAction SilentlyContinue
        return $ok
    } catch { return $false }
}

# Xoa junction AN TOAN (chi xoa link, khong dong den du lieu that)
function Remove-JunctionOnly {
    param([Parameter(Mandatory)][string]$Link)
    $item = Get-Item $Link -Force -ErrorAction Stop
    if ($item.LinkType -ne 'Junction') { throw "'$Link' khong phai junction - tu choi xoa." }
    & cmd.exe /c rmdir "$Link" | Out-Null
    if (Test-Path $Link) { throw "Khong xoa duoc junction '$Link'." }
}
