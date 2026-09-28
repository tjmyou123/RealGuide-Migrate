@echo off
:: MAY CU - Backup thu vien RealGUIDE de mang sang may khac (double-click de chay)
setlocal
set /p DEST=Nhap thu muc dich (VD: F:\RealGuideBackup): 
if "%DEST%"=="" ( echo Chua nhap dich. & pause & exit /b 1 )
set /p WITHDB=Kem DB benh nhan (co the hang chuc GB)? [y/N]: 
set ARGS=-Destination "%DEST%" -CloseApp
if /i "%WITHDB%"=="y" set ARGS=%ARGS% -IncludePatientDb
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Backup-Library.ps1" %ARGS%
pause
