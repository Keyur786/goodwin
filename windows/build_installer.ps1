<#
.SYNOPSIS
    Builds the Flutter Windows desktop release and packages it into Goodwin_Windows_Setup.exe using Inno Setup.
.DESCRIPTION
    Run this script on a Windows machine:
        powershell -ExecutionPolicy Bypass -File .\windows\build_installer.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "       Goodwin Wholesale - Windows Installer Builder    " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ProjectRoot

# 1. Check Flutter command
Write-Host "[1/3] Checking Flutter..." -ForegroundColor Yellow
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter command was not found on PATH. Please ensure Flutter is installed and added to your system PATH."
}

Write-Host "Fetching dependencies..." -ForegroundColor Gray
flutter pub get

# 2. Build Windows Release
Write-Host "`n[2/3] Building Flutter Windows Release..." -ForegroundColor Yellow
flutter build windows --release

# 3. Locate Inno Setup Compiler (ISCC)
Write-Host "`n[3/3] Packaging installer with Inno Setup..." -ForegroundColor Yellow

$IsccCmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
$PossiblePaths = @(
    "$env:ProgramFiles (x86)\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$IsccPath = $null
if ($IsccCmd) {
    $IsccPath = $IsccCmd.Source
} else {
    foreach ($path in $PossiblePaths) {
        if (Test-Path $path) {
            $IsccPath = $path
            break
        }
    }
}

if (-not $IsccPath) {
    Write-Warning "Inno Setup Compiler (ISCC.exe) was not found."
    Write-Host "To install Inno Setup, run:" -ForegroundColor Cyan
    Write-Host "  winget install JRSoftware.InnoSetup" -ForegroundColor White
    Write-Host "Or download from: https://jrsoftware.org/isdl.php" -ForegroundColor White
    Write-Host "`nRelease files are ready at: build\windows\x64\runner\Release\" -ForegroundColor Gray
    exit 1
}

Write-Host "Using Inno Setup compiler: $IsccPath" -ForegroundColor Gray
$IssFile = Join-Path $PSScriptRoot "installer\goodwin_setup.iss"

& "$IsccPath" "$IssFile"

$SetupExe = Join-Path $ProjectRoot "build\windows\installer\Goodwin_Windows_Setup.exe"
if (Test-Path $SetupExe) {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "[SUCCESS] Installer created successfully!" -ForegroundColor Green
    Write-Host "File: $SetupExe" -ForegroundColor White
    Write-Host "Size: $([math]::Round((Get-Item $SetupExe).Length / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Green
} else {
    Write-Error "Setup executable was not found after compilation."
}

