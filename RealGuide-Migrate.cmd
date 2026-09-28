@echo off
:: RealGuide-Migrate - GIAO DIEN (double-click). Tu xin quyen Administrator.
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0RealGuide-Migrate.GUI.ps1"
