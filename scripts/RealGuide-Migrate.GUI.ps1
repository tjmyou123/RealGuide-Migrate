<#
.SYNOPSIS
  Giao dien (WinForms) gom toan bo bo cong cu RealGuide-Migrate: tim duong dan, backup,
  tao junction, khoi phuc, va sleeve, kiem tra. Chay qua RealGuide-Migrate.cmd (tu xin Admin).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
. "$PSScriptRoot\Common.ps1"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')

# Chuoi giao dien tieng Viet co dau: doc tu Strings.vi.txt (UTF-8). File .ps1 nay giu ASCII de PS 5.1 doc dung.
$strFile = Join-Path $PSScriptRoot 'Strings.vi.txt'
if (-not (Test-Path -LiteralPath $strFile)) { [System.Windows.Forms.MessageBox]::Show("Thieu file $strFile", 'RealGuide-Migrate', 'OK', 'Error') | Out-Null; exit 1 }
$S = Get-Content -LiteralPath $strFile -Raw -Encoding UTF8 | ConvertFrom-StringData
function T { param([string]$Key, [object[]]$Vals = @()) $v = $script:S[$Key]; if ($null -eq $v) { return "[$Key]" }; if ($Vals.Count) { $v -f $Vals } else { $v } }

# ---------------------------------------------------------------- helpers
function New-Ctl {
    param([string]$Type, [hashtable]$P = @{}, $Parent)
    $c = New-Object "System.Windows.Forms.$Type"
    foreach ($k in $P.Keys) { $c.$k = $P[$k] }
    if ($Parent) { $Parent.Controls.Add($c) }
    $c
}
function Pt { param($x, $y) New-Object System.Drawing.Point($x, $y) }
function Sz { param($w, $h) New-Object System.Drawing.Size($w, $h) }
function Q  { param([string]$Path) if ($Path.EndsWith('\')) { $Path += '\' }; '"' + $Path + '"' }   # quote cho dong lenh
$boldFont = New-Object System.Drawing.Font('Segoe UI', [single]9, [System.Drawing.FontStyle]::Bold)

function Pick-Folder {
    param([string]$Desc, [string]$Initial)
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $Desc; $d.ShowNewFolderButton = $true
    if ($Initial -and (Test-Path $Initial)) { $d.SelectedPath = $Initial }
    if ($d.ShowDialog($form) -eq 'OK') { return $d.SelectedPath }
    return $null
}
function Msg  { param($Text, $Title = 'RealGuide-Migrate', $Icon = 'Information') [System.Windows.Forms.MessageBox]::Show($form, $Text, $Title, 'OK', $Icon) | Out-Null }
function Ask  { param($Text, $Title = $S.Confirm) ([System.Windows.Forms.MessageBox]::Show($form, $Text, $Title, 'YesNo', 'Question') -eq 'Yes') }

# ---------------------------------------------------------------- form
$form = New-Ctl Form @{
    Text = (T Title $script:ToolVersion) + $(if (-not $isAdmin) { $S.NoAdmin })
    Size = (Sz 900 740); MinimumSize = (Sz 900 740); StartPosition = 'CenterScreen'
    Font = (New-Object System.Drawing.Font('Segoe UI', 9))
}

# --- Trang thai
$grpStatus = New-Ctl GroupBox @{ Text = $S.GrpStatus; Location = (Pt 10 8); Size = (Sz 866 190); Anchor = 'Top,Left,Right' } $form
$lv = New-Ctl ListView @{ View = 'Details'; FullRowSelect = $true; GridLines = $true; Location = (Pt 10 22); Size = (Sz 846 128); Anchor = 'Top,Left,Right' } $grpStatus
[void]$lv.Columns.Add($S.ColItem, 150)
[void]$lv.Columns.Add($S.ColLink, 300)
[void]$lv.Columns.Add($S.ColTarget, 260)
[void]$lv.Columns.Add($S.ColSize, 120)
$btnRefresh = New-Ctl Button @{ Text = $S.BtnRefresh; Location = (Pt 10 156); Size = (Sz 100 26) } $grpStatus
$btnOpenLib = New-Ctl Button @{ Text = $S.BtnOpenLib; Location = (Pt 116 156); Size = (Sz 150 26) } $grpStatus
$btnOpenData = New-Ctl Button @{ Text = $S.BtnOpenData; Location = (Pt 272 156); Size = (Sz 150 26) } $grpStatus
$lblApp = New-Ctl Label @{ Text = ''; Location = (Pt 430 161); Size = (Sz 426 20); ForeColor = 'DimGray'; Anchor = 'Top,Left,Right' } $grpStatus

# --- Tabs
$tabs = New-Ctl TabControl @{ Location = (Pt 10 204); Size = (Sz 866 215); Anchor = 'Top,Left,Right' } $form
$tabBackup = New-Ctl TabPage @{ Text = $S.Tab1 }; $tabs.TabPages.Add($tabBackup)
$tabExist  = New-Ctl TabPage @{ Text = $S.Tab2 }; $tabs.TabPages.Add($tabExist)
$tabNew    = New-Ctl TabPage @{ Text = $S.Tab3 }; $tabs.TabPages.Add($tabNew)
$tabMaint  = New-Ctl TabPage @{ Text = $S.Tab4 }; $tabs.TabPages.Add($tabMaint)

# Tab 1
New-Ctl Label @{ Text = $S.LblDest; Location = (Pt 12 16); AutoSize = $true } $tabBackup | Out-Null
$txtDest = New-Ctl TextBox @{ Location = (Pt 12 36); Size = (Sz 700 24) } $tabBackup
$btnDest = New-Ctl Button @{ Text = $S.BtnBrowse; Location = (Pt 720 34); Size = (Sz 90 26) } $tabBackup
$chkBkDb    = New-Ctl CheckBox @{ Text = $S.ChkBkDb; Location = (Pt 12 70); AutoSize = $true } $tabBackup
$chkBkCfg   = New-Ctl CheckBox @{ Text = $S.ChkBkCfg; Location = (Pt 12 94); AutoSize = $true } $tabBackup
$chkBkClose = New-Ctl CheckBox @{ Text = $S.ChkBkClose; Location = (Pt 12 118); AutoSize = $true; Checked = $true } $tabBackup
$btnBackup = New-Ctl Button @{ Text = $S.BtnBackup; Location = (Pt 12 150); Size = (Sz 200 30); Font = $boldFont } $tabBackup
New-Ctl Label @{ Text = $S.HintBackup; Location = (Pt 225 157); AutoSize = $true; ForeColor = 'DimGray' } $tabBackup | Out-Null

# Tab 2 - thu vien (backup) co san
New-Ctl Label @{ Text = $S.LblExist; Location = (Pt 12 10); AutoSize = $true } $tabExist | Out-Null
$lvBk = New-Ctl ListView @{ View = 'Details'; FullRowSelect = $true; GridLines = $true; MultiSelect = $false; HideSelection = $false; Location = (Pt 12 30); Size = (Sz 830 108) } $tabExist
[void]$lvBk.Columns.Add($S.ColCreated, 120)
[void]$lvBk.Columns.Add($S.ColName, 230)
[void]$lvBk.Columns.Add($S.ColType, 75)
[void]$lvBk.Columns.Add($S.ColSize, 130)
[void]$lvBk.Columns.Add($S.ColPath, 270)
$btnBkScan   = New-Ctl Button @{ Text = $S.BtnBkScan; Location = (Pt 12 146); Size = (Sz 100 30) } $tabExist
$btnBkUse    = New-Ctl Button @{ Text = $S.BtnBkUse; Location = (Pt 118 146); Size = (Sz 170 30); Font = $boldFont } $tabExist
$btnBkExport = New-Ctl Button @{ Text = $S.BtnBkExport; Location = (Pt 294 146); Size = (Sz 200 30) } $tabExist
$btnBkOpen   = New-Ctl Button @{ Text = $S.BtnBkOpen; Location = (Pt 500 146); Size = (Sz 110 30) } $tabExist
New-Ctl Label @{ Text = $S.HintExist; Location = (Pt 618 153); AutoSize = $true; ForeColor = 'DimGray' } $tabExist | Out-Null

# Tab 3
New-Ctl Label @{ Text = $S.LblRoot; Location = (Pt 12 12); AutoSize = $true } $tabNew | Out-Null
$txtRoot = New-Ctl TextBox @{ Location = (Pt 12 32); Size = (Sz 700 24) } $tabNew
$btnRoot = New-Ctl Button @{ Text = $S.BtnBrowse; Location = (Pt 720 30); Size = (Sz 90 26) } $tabNew
New-Ctl Label @{ Text = $S.LblBk; Location = (Pt 12 60); AutoSize = $true } $tabNew | Out-Null
$txtBk = New-Ctl TextBox @{ Location = (Pt 12 80); Size = (Sz 700 24) } $tabNew
$btnBk = New-Ctl Button @{ Text = $S.BtnBrowse; Location = (Pt 720 78); Size = (Sz 90 26) } $tabNew
$chkRsDb  = New-Ctl CheckBox @{ Text = $S.ChkRsDb; Location = (Pt 12 110); AutoSize = $true } $tabNew
$chkRsCfg = New-Ctl CheckBox @{ Text = $S.ChkRsCfg; Location = (Pt 200 110); AutoSize = $true } $tabNew
$chkSkipJ = New-Ctl CheckBox @{ Text = $S.ChkSkipJ; Location = (Pt 400 110); AutoSize = $true } $tabNew
$btnSetupAll = New-Ctl Button @{ Text = $S.BtnSetupAll; Location = (Pt 12 145); Size = (Sz 360 30); Font = $boldFont } $tabNew
$btnJunction = New-Ctl Button @{ Text = $S.BtnJunction; Location = (Pt 380 145); Size = (Sz 150 30) } $tabNew
$btnRestore  = New-Ctl Button @{ Text = $S.BtnRestore; Location = (Pt 536 145); Size = (Sz 170 30) } $tabNew

# Tab 4
$btnFind   = New-Ctl Button @{ Text = $S.BtnFind; Location = (Pt 12 16); Size = (Sz 280 30) } $tabMaint
$btnVerify = New-Ctl Button @{ Text = $S.BtnVerify; Location = (Pt 12 52); Size = (Sz 280 30) } $tabMaint
$btnRepair = New-Ctl Button @{ Text = $S.BtnRepair; Location = (Pt 12 88); Size = (Sz 280 30) } $tabMaint
$btnUndo   = New-Ctl Button @{ Text = $S.BtnUndo; Location = (Pt 12 134); Size = (Sz 380 30); ForeColor = 'Firebrick' } $tabMaint
New-Ctl Label @{ Text = $S.HintMaint; Location = (Pt 310 16); Size = (Sz 530 110); ForeColor = 'DimGray' } $tabMaint | Out-Null

# --- Log
$log = New-Ctl RichTextBox @{ Location = (Pt 10 426); Size = (Sz 866 240); ReadOnly = $true; BackColor = 'Black'; ForeColor = 'Gainsboro'; Font = (New-Object System.Drawing.Font('Consolas', 9)); Anchor = 'Top,Bottom,Left,Right'; WordWrap = $false; ScrollBars = 'Both' } $form
$progress = New-Ctl ProgressBar @{ Location = (Pt 10 672); Size = (Sz 200 20); Anchor = 'Bottom,Left'; MarqueeAnimationSpeed = 30 } $form
$status = New-Ctl Label @{ Text = $S.Ready; Location = (Pt 220 674); Size = (Sz 656 20); Anchor = 'Bottom,Left,Right' } $form

# ---------------------------------------------------------------- logic
$script:Paths = $null
$script:Proc = $null
$script:OutFile = Join-Path $env:TEMP "rgm-out-$PID.log"
$script:ErrFile = Join-Path $env:TEMP "rgm-err-$PID.log"
$script:OutPos = 0; $script:ErrPos = 0

function Append-Log {
    param([string]$Text, [string]$Color = 'Gainsboro')
    $log.SelectionStart = $log.TextLength; $log.SelectionLength = 0
    $log.SelectionColor = [System.Drawing.Color]::FromName($Color)
    $log.AppendText($Text)
    $log.ScrollToCaret()
}

function Get-DataRootGuess {
    $p = $script:Paths
    if ($p -and $p.Targets.Library) { return (Split-Path $p.Targets.Library -Parent) }
    if ($p -and $p.Targets.PatientDb) { return (Split-Path $p.Targets.PatientDb -Parent) }
    $d = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'C' -and $_.Free -gt 20GB -and -not $_.DisplayRoot } | Select-Object -First 1
    if ($d) { return "$($d.Name):\RealGuideData" }
    return 'C:\RealGuideData'
}

function Refresh-Status {
    $status.Text = $S.Finding; $form.Refresh()
    try { $script:Paths = Find-RealGuidePaths } catch { Append-Log ((T ErrFind $_) + "`r`n") 'Salmon'; return }
    $p = $script:Paths
    $lv.Items.Clear()
    $rows = @(
        @($S.RowLibrary,   $p.Library,   'Library'),
        @($S.RowPatientDb, $p.PatientDb, 'PatientDb'),
        @($S.RowQml,       $p.QmlCache,  'QmlCache'),
        @($S.RowNnt,       $p.NNT,       'NNT')
    )
    foreach ($r in $rows) {
        $name, $link, $key = $r
        $it = New-Object System.Windows.Forms.ListViewItem($name)
        [void]$it.SubItems.Add($link)
        if (-not (Test-Path $link)) {
            [void]$it.SubItems.Add($S.StNotExist); [void]$it.SubItems.Add('-'); $it.ForeColor = 'Gray'
        } elseif ($p.Targets[$key]) {
            $st = Get-DirStats $p.Targets[$key]
            [void]$it.SubItems.Add((T StJunction $p.Targets[$key])); [void]$it.SubItems.Add((T FilesSize $st.Files, (Format-Bytes $st.Bytes))); $it.ForeColor = 'DarkGreen'
        } else {
            $st = Get-DirStats $link
            [void]$it.SubItems.Add($S.StRealDir); [void]$it.SubItems.Add((T FilesSize $st.Files, (Format-Bytes $st.Bytes))); $it.ForeColor = 'DarkOrange'
        }
        [void]$lv.Items.Add($it)
    }
    $lblApp.Text = if ($p.Exe) { T AppAt $p.Exe } else { $S.AppNone }
    if (-not $txtRoot.Text) { $txtRoot.Text = Get-DataRootGuess }
    if (-not $txtBk.Text) {
        $guess = Get-ContainingBackup
        if ($guess) { $txtBk.Text = $guess }
        elseif ($p.Extra) { $b = $p.Extra | Where-Object Kind -eq 'Backup' | Select-Object -Last 1; if ($b) { $txtBk.Text = $b.Path } }
        else {
            # Backup moi nhat trong <DataRoot>\Backups (vi tri Backup-Library thuong ghi)
            $bkDir = Join-Path $txtRoot.Text 'Backups'
            $latest = Get-ChildItem $bkDir -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'manifest.json') } | Sort-Object Name -Descending | Select-Object -First 1
            if ($latest) { $txtBk.Text = $latest.FullName }
        }
    }
    $status.Text = $S.Ready
}

function Refresh-Backups {
    $status.Text = $S.Scanning; $form.Refresh()
    $lvBk.Items.Clear()
    $roots = @(); if ($txtRoot.Text) { $roots += (Join-Path $txtRoot.Text 'Backups') }
    try { $list = @(Find-ExistingBackups -ExtraRoots $roots) } catch { Append-Log ((T ErrScan $_) + "`r`n") 'Salmon'; $list = @() }
    foreach ($b in $list) {
        $st = Get-DirStats $b.Path
        $it = New-Object System.Windows.Forms.ListViewItem($b.Created.ToString('yyyy-MM-dd HH:mm'))
        [void]$it.SubItems.Add($b.Name); [void]$it.SubItems.Add($(if ($b.Type -eq 'chuan') { $S.TypeStd } else { $S.TypeOld }))
        [void]$it.SubItems.Add((T FilesSize $st.Files, (Format-Bytes $st.Bytes))); [void]$it.SubItems.Add($b.Path)
        $it.Tag = $b.Path
        if ($b.Type -ne 'chuan') { $it.ForeColor = 'DarkOrange' }
        [void]$lvBk.Items.Add($it)
    }
    if ($lvBk.Items.Count) { $lvBk.Items[0].Selected = $true }
    $status.Text = T FoundBackups $list.Count
}
function Get-SelectedBackup { if ($lvBk.SelectedItems.Count) { $lvBk.SelectedItems[0].Tag } else { $null } }

function Read-NewText {
    param([string]$File, [ref]$Pos)
    if (-not (Test-Path $File)) { return '' }
    $fs = [System.IO.File]::Open($File, 'Open', 'Read', 'ReadWrite')
    try {
        if ($fs.Length -le $Pos.Value) { return '' }
        $fs.Position = $Pos.Value
        $buf = New-Object byte[] ($fs.Length - $Pos.Value)
        $n = $fs.Read($buf, 0, $buf.Length); $Pos.Value += $n
        return [System.Text.Encoding]::Default.GetString($buf, 0, $n)
    } finally { $fs.Close() }
}

function Set-Busy {
    param([bool]$Busy)
    $tabs.Enabled = -not $Busy; $btnRefresh.Enabled = -not $Busy
    if ($Busy) { $progress.Style = 'Marquee' } else { $progress.Style = 'Blocks'; $progress.Value = 0 }
}

function Invoke-Tool {
    param([string]$Script, [string[]]$Arguments = @(), [string]$Title)
    if ($script:Proc -and -not $script:Proc.HasExited) { Msg $S.Busy; return }
    Set-Content $script:OutFile ''; Set-Content $script:ErrFile ''
    $script:OutPos = 0; $script:ErrPos = 0
    $log.Clear(); Append-Log ">>> $Title`r`n>>> $Script $($Arguments -join ' ')`r`n`r`n" 'DeepSkyBlue'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Q (Join-Path $PSScriptRoot $Script))) + $Arguments
    $script:Proc = Start-Process powershell.exe -ArgumentList ($argList -join ' ') -RedirectStandardOutput $script:OutFile -RedirectStandardError $script:ErrFile -WindowStyle Hidden -PassThru
    Set-Busy $true; $status.Text = T Running $Title
    $timer.Start()
}

$timer = New-Object System.Windows.Forms.Timer; $timer.Interval = 400
$timer.Add_Tick({
    $t = Read-NewText $script:OutFile ([ref]$script:OutPos); if ($t) { Append-Log $t }
    $e = Read-NewText $script:ErrFile ([ref]$script:ErrPos); if ($e) { Append-Log $e 'Salmon' }
    if ($script:Proc.HasExited) {
        $timer.Stop()
        $t = Read-NewText $script:OutFile ([ref]$script:OutPos); if ($t) { Append-Log $t }
        $e = Read-NewText $script:ErrFile ([ref]$script:ErrPos); if ($e) { Append-Log $e 'Salmon' }
        $code = $script:Proc.ExitCode
        if ($code -eq 0) { Append-Log "`r`n$($S.DoneLog)`r`n" 'LightGreen'; $status.Text = $S.Done }
        else { Append-Log "`r`n$(T FailLog $code)`r`n" 'Salmon'; $status.Text = T Fail $code }
        Set-Busy $false
        Refresh-Status
    }
})

# ---------------------------------------------------------------- events
$btnRefresh.Add_Click({ Refresh-Status })
$btnOpenLib.Add_Click({ $p = $script:Paths.Library; if (Test-Path $p) { Start-Process explorer.exe $p } else { Msg $S.NoLib } })
$btnOpenData.Add_Click({ $r = $txtRoot.Text; if ($r -and (Test-Path $r)) { Start-Process explorer.exe $r } else { Msg $S.NoData } })

$btnDest.Add_Click({ $f = Pick-Folder $S.PickDest $txtDest.Text; if ($f) { $txtDest.Text = $f } })
$btnRoot.Add_Click({ $f = Pick-Folder $S.PickRoot $txtRoot.Text; if ($f) { $txtRoot.Text = $f } })
$btnBk.Add_Click({
    $f = Pick-Folder $S.PickBk $txtBk.Text
    if (-not $f) { return }
    if (-not (Test-Path (Join-Path $f 'manifest.json'))) {
        # Chon thu muc cha -> tu lay backup moi nhat ben trong
        $latest = Get-ChildItem $f -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'manifest.json') } | Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) { $f = $latest.FullName; $status.Text = T LatestPicked $latest.Name }
        else { Msg $S.NotBackup $S.Warning 'Warning' }
    }
    $txtBk.Text = $f
})

$btnBackup.Add_Click({
    if (-not $txtDest.Text) { Msg $S.NoDest $S.Missing 'Warning'; return }
    $a = @('-Destination', (Q $txtDest.Text))
    if ($chkBkDb.Checked)    { $a += '-IncludePatientDb' }
    if ($chkBkCfg.Checked)   { $a += '-IncludeConfig' }
    if ($chkBkClose.Checked) { $a += '-CloseApp' }
    Invoke-Tool 'Backup-Library.ps1' $a $S.TaskBackup
})

$btnBkScan.Add_Click({ Refresh-Backups })
$btnBkUse.Add_Click({
    $b = Get-SelectedBackup
    if (-not $b) { Msg $S.NoBkSel $S.Missing 'Warning'; return }
    $txtBk.Text = $b; $tabs.SelectedTab = $tabNew
    $status.Text = T BkChosen $b
})
$btnBkExport.Add_Click({
    $b = Get-SelectedBackup
    if (-not $b) { Msg $S.NoBkSel $S.Missing 'Warning'; return }
    $f = Pick-Folder $S.PickUsb ''
    if (-not $f) { return }
    $st = Get-DirStats $b
    if (-not (Ask (T AskExport $b, (Format-Bytes $st.Bytes), $f))) { return }
    Invoke-Tool 'Export-Backup.ps1' @('-BackupPath', (Q $b), '-Destination', (Q $f)) $S.TaskExport
})
$btnBkOpen.Add_Click({ $b = Get-SelectedBackup; if ($b) { Start-Process explorer.exe $b } })
$tabs.Add_SelectedIndexChanged({ if ($tabs.SelectedTab -eq $tabExist -and $lvBk.Items.Count -eq 0) { Refresh-Backups } })

$btnSetupAll.Add_Click({
    if (-not $txtRoot.Text) { Msg $S.NoRoot $S.Missing 'Warning'; return }
    if (-not $txtBk.Text -or -not (Test-Path $txtBk.Text)) { Msg $S.NoBk $S.Missing 'Warning'; return }
    $jLine = if ($chkSkipJ.Checked) { '' } else { T AskSetupJunctionLine $txtRoot.Text }
    if (-not (Ask (T AskSetupAll $jLine, $txtBk.Text))) { return }
    $a = @('-DataRoot', (Q $txtRoot.Text), '-BackupPath', (Q $txtBk.Text))
    if ($chkRsDb.Checked)  { $a += '-RestorePatientDb' }
    if ($chkRsCfg.Checked) { $a += '-RestoreConfig' }
    if ($chkSkipJ.Checked) { $a += '-SkipJunctions' }
    Invoke-Tool 'Setup-NewMachine.ps1' $a $S.TaskSetupAll
})
$btnJunction.Add_Click({
    if (-not $txtRoot.Text) { Msg $S.NoRoot $S.Missing 'Warning'; return }
    if (-not (Ask (T AskJunction $txtRoot.Text))) { return }
    Invoke-Tool 'Setup-Junctions.ps1' @('-DataRoot', (Q $txtRoot.Text)) $S.TaskJunction
})
$btnRestore.Add_Click({
    if (-not $txtBk.Text -or -not (Test-Path $txtBk.Text)) { Msg $S.NoBk $S.Missing 'Warning'; return }
    if (-not (Ask (T AskRestore $txtBk.Text))) { return }
    $a = @('-BackupPath', (Q $txtBk.Text))
    if ($chkRsDb.Checked)  { $a += '-RestorePatientDb' }
    if ($chkRsCfg.Checked) { $a += '-RestoreConfig' }
    Invoke-Tool 'Restore-Library.ps1' $a $S.TaskRestore
})

$btnFind.Add_Click({ Invoke-Tool 'Find-RealGuide.ps1' @('-ScanDrives') $S.TaskFind })
$btnVerify.Add_Click({ $a = @(); if ($txtRoot.Text) { $a = @('-DataRoot', (Q $txtRoot.Text)) }; Invoke-Tool 'Verify-Setup.ps1' $a $S.TaskVerify })
$btnRepair.Add_Click({ Invoke-Tool 'Repair-Sleeves.ps1' @() $S.TaskRepair })
$btnUndo.Add_Click({
    if (-not $txtRoot.Text) { Msg $S.NoRoot $S.Missing 'Warning'; return }
    if (-not (Ask (T AskUndo $txtRoot.Text))) { return }
    Invoke-Tool 'Setup-Junctions.ps1' @('-DataRoot', (Q $txtRoot.Text), '-Undo') $S.TaskUndo
})

$form.Add_Shown({ Refresh-Status; if ($env:RGM_TAB) { $tabs.SelectedIndex = [int]$env:RGM_TAB } })
$form.Add_FormClosing({
    if ($script:Proc -and -not $script:Proc.HasExited) {
        if (-not (Ask $S.AskClose)) { $_.Cancel = $true }
    }
    Remove-Item $script:OutFile, $script:ErrFile -Force -ErrorAction SilentlyContinue
})

[void]$form.ShowDialog()
