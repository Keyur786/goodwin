# Windows Desktop Setup & Distribution Guide

This guide explains how to build and distribute the standalone **`Goodwin_Windows_Setup.exe`** installer for Windows users without affecting Android, iOS, or Web builds.

---

## What Was Added

1. **Inno Setup Script** (`windows/installer/goodwin_setup.iss`):
   - Packages the Flutter Windows release (`goodwin.exe`, runtime DLLs, `data/` assets, icons).
   - Generates a single installer file: `Goodwin_Windows_Setup.exe`.
   - Automatically adds Desktop and Start Menu shortcuts and registers the uninstaller in Windows *Add or remove programs*.
2. **One-Click Local Windows Build Scripts**:
   - `windows/build_installer.bat` (Command Prompt / Double-click)
   - `windows/build_installer.ps1` (PowerShell)
3. **Automated Cloud Build Workflow** (`.github/workflows/build_windows_setup.yml`):
   - Builds and packages `Goodwin_Windows_Setup.exe` on GitHub's cloud Windows runners.
   - Download the installer directly from GitHub Actions without needing a Windows PC!
4. **Cross-Platform Firebase Options** (`lib/firebase_options.dart`):
   - Keeps all mobile and web configurations intact while gracefully supporting Windows desktop.

---

## Method 1: Download from GitHub Actions (No Windows PC Required)

Since you develop on macOS, GitHub Actions can automatically compile the Windows installer on a cloud Windows machine for you:

1. **Push your code to GitHub**:
   ```bash
   git add .
   git commit -m "feat: add windows setup installer support"
   git push origin main
   ```
2. In your GitHub repository, click the **Actions** tab.
3. In the left sidebar, click **Build Windows Setup Installer**.
4. Click **Run workflow** -> Select `main` -> Click **Run workflow**.
5. When the build completes (~4-6 minutes), scroll down to the **Artifacts** section.
6. Click on **`Goodwin_Windows_Setup`** to download your ready-to-distribute setup `.exe`!

*(Tip: When you create a git release tag like `git tag v1.0.0 && git push origin v1.0.0`, the workflow will automatically publish the `.exe` directly under GitHub Releases!)*

---

## Method 2: Build Locally on a Windows Machine

If you or a team member are working on a Windows PC:

### Prerequisites:
1. Flutter SDK for Windows installed (`flutter doctor`).
2. Visual Studio 2022 with **"Desktop development with C++"** installed.
3. **Inno Setup 6**:
   - Install via Windows Terminal / winget:
     ```powershell
     winget install JRSoftware.InnoSetup
     ```
   - Or download installer from: https://jrsoftware.org/isdl.php

### One-Click Build:
Double-click `windows/build_installer.bat` or run in PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File .\windows\build_installer.ps1
```

The script will automatically:
1. Run `flutter pub get`
2. Run `flutter build windows --release`
3. Compile with Inno Setup Compiler (`ISCC.exe`)
4. Output: `build\windows\installer\Goodwin_Windows_Setup.exe`

---

## End-User Installation Experience

When you send `Goodwin_Windows_Setup.exe` to a customer or team member:

1. They double-click `Goodwin_Windows_Setup.exe`.
2. The modern setup wizard guides them through the installation (no administrator rights strictly required; installs to local user profile or program files).
3. A desktop shortcut and Start Menu shortcut are created automatically.
4. The user clicks **Finish** to launch Goodwin Wholesale.
5. To uninstall, they can simply search "Goodwin Wholesale" in Windows Settings -> Installed Apps -> Uninstall.

