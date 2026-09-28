@echo off
:: RealGuide-Migrate - GIAO DIEN (double-click). Tu xin quyen Administrator.
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
:: Bo co "tai tu Internet" (Zone.Identifier) neu tai ZIP tu GitHub, tranh bi chan script
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0scripts' -File | Unblock-File -ErrorAction SilentlyContinue"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0scripts\RealGuide-Migrate.GUI.ps1"
