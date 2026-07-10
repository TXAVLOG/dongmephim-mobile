@echo off
title DongMePhim - Build Setup Installer
echo ============================================
echo   DongMePhim v5.0.0 - Build Setup
echo   Tac gia: TXA TEAM
echo ============================================
echo.

:: Check if Inno Setup is installed
set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
    set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
)
if not exist "%ISCC%" (
    echo [ERROR] Inno Setup 6 not found!
    echo Please install Inno Setup 6 from: https://jrsoftware.org/isinfo.php
    pause
    exit /b 1
)

echo [INFO] Using Inno Setup: %ISCC%
echo [INFO] Compiling ISS script...
echo.

"%ISCC%" "DongMePhim_v5.0.0.iss"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo   BUILD SUCCESSFUL!
    echo   Output: roots\Output\DongMePhim_v5.0.0_Setup.exe
    echo ============================================
) else (
    echo.
    echo [ERROR] Build failed! Check the output above.
)

pause
