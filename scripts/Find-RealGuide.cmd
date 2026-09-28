@echo off
:: Tu tim RealGUIDE luu file o dau (app, thu vien, DB benh nhan, cache, junction)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Find-RealGuide.ps1" -ScanDrives
pause
