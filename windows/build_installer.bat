@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo        Goodwin Wholesale - Windows Installer Builder
echo =======================================================
echo.

:: 1. Navigate to project root
cd /d "%~dp0\.."

:: 2. Check for Flutter
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter is not found in your PATH.
    echo Please install Flutter and make sure flutter is in your PATH.
    pause
    exit /b 1
)

echo [1/3] Resolving Flutter dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)

echo.
echo [2/3] Building Flutter Windows Release package...
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter build windows failed.
    pause
    exit /b 1
)

echo.
echo [3/3] Locating Inno Setup Compiler (ISCC)...

set "ISCC_PATH="
where iscc >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "ISCC_PATH=iscc"
) else if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=%ProgramFiles%\Inno Setup 6\ISCC.exe"
) else if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
)

if "%ISCC_PATH%"=="" (
    echo [WARNING] Inno Setup 6 was not found automatically.
    echo Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php
    echo Or install via Windows Terminal / winget: winget install JRSoftware.InnoSetup
    echo.
    echo Release binaries are available in: build\windows\x64\runner\Release\
    pause
    exit /b 1
)

echo Compiling Setup Executable using: "!ISCC_PATH!"
"!ISCC_PATH!" "windows\installer\goodwin_setup.iss"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Inno Setup compilation failed.
    pause
    exit /b 1
)

echo.
echo =======================================================
echo [SUCCESS] Windows Setup Installer generated successfully!
echo Location: build\windows\installer\Goodwin_Windows_Setup.exe
echo =======================================================
echo.

pause

