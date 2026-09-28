@echo off
:: MAY MOI - Tao junction + khoi phuc thu vien tu backup (tu xin quyen Admin)
setlocal
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Dang xin quyen Administrator...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
set /p ROOT=Nhap thu muc luu du lieu tren may nay (VD: D:\RealGuideData): 
if "%ROOT%"=="" ( echo Chua nhap. & pause & exit /b 1 )
set /p WITHDB=Khoi phuc DB benh nhan tu backup (neu co)? [y/N]: 
set ARGS=-DataRoot "%ROOT%"
if /i "%WITHDB%"=="y" set ARGS=%ARGS% -RestorePatientDb
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-NewMachine.ps1" %ARGS%
pause
