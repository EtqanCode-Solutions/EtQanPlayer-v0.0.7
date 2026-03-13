@echo off
echo Starting installer builder...
timeout /t 2 >nul

cd /d "%~dp0"
echo Current folder: %CD%
echo.

REM البحث عن Inno Setup
set INNO_PATH=
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set INNO_PATH=C:\Program Files\Inno Setup 6\ISCC.exe

if "%INNO_PATH%"=="" (
    echo ERROR: Inno Setup not found!
    echo Install from: https://jrsoftware.org/isdl.php
    pause
    exit /b 1
)

echo Found Inno Setup: %INNO_PATH%
echo.

REM التحقق من وجود exe
if not exist "..\build\windows\x64\runner\Release\etqan_player.exe" (
    echo ERROR: Application not built!
    echo Run: flutter build windows --release
    pause
    exit /b 1
)

echo Application found!
echo.

REM إنشاء output
if not exist "output" mkdir output

REM بناء التثبيت
echo Building installer...
"%INNO_PATH%" "etqan_player_setup.iss"

if exist "output\samy_player_installer.exe" (
    echo.
    echo SUCCESS! Installer created in: output\
) else (
    echo.
    echo FAILED! Check errors above.
)

echo.
pause
