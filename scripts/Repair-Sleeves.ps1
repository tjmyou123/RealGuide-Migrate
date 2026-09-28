<#
.SYNOPSIS
  Va sleeve ket (.part -> .stl.dec) khi RealGUIDE bao "Polygon count is zero". Chay duoc khi app dang mo.
#>
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"
Write-Step "Va sleeve ket trong $(Get-LibraryPath)\tmp\decs"
Repair-StuckSleeves -LibraryPath (Get-LibraryPath)
Write-Host "Mo lai ca trong RealGUIDE de kiem tra."
