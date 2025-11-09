# VSCode Portable Installation Script

## Overview
Fully automated unified script for installing a portable VSCode environment on Windows 10/11 with offline support and multi-PC portability.

## Key Features

### Fully Portable
- Works on USB drives, external drives, network drives
- Immune to drive letter changes
- Location-independent execution

### Offline Support
- `.staging` folder backup system for offline installations
- Internet connectivity detection (ping 8.8.8.8)
- Falls back to staged files when offline

### Multi-PC Portability
- PC change detection via `%COMPUTERNAME%`
- Auto-reconfiguration on new PCs
- Same path on different PCs correctly handled (e.g., D:\VSCode on PC1 vs PC2)

### Auto-Update
- VSCode version checking on every launch (online only)
- Automatic download and upgrade
- User data preservation (data folder)

### Relative Paths Only
- No absolute paths used in pip.cmd, python.cmd
- VSCode settings use `${execPath}` variables
- Folder relocation fully supported

## Included Components
1. **Fonts**: 0xProto Nerd Font Mono, DalseoHealing (달서힐링체)
2. **PowerShell 7**: Latest version auto-installed (online only)
3. **Oh My Posh**: Terminal theme engine (online only)
4. **Custom Theme**: tos-term.omp.json
5. **PowerShell Modules**: Terminal-Icons, modern-unix-win, PSFzf
6. **PowerShell Profile**: Custom profile configuration
7. **VSCode Portable**: Latest version auto-downloaded
8. **Python Portable**: Latest Python 3 embedded version
9. **pip**: Python package manager with relative paths

## Installation

### 1. Initial Installation
```cmd
VSCode_Installer.cmd
```

Installation process:
- Default installation path: `C:\VSCode`
- Enter custom path when prompted (or press Enter for default)
- All components installed automatically
- Desktop and Start Menu shortcuts created
- `.staging` folder created with backup files for offline use

### 2. Launch VSCode
```cmd
C:\VSCode\launcher.cmd
```

Or click the "Code" icon on Desktop/Start Menu.

## Portable Usage Scenarios

### Scenario 1: USB Drive Transfer (Same PC)
Copy the VSCode folder to a different location:

```
C:\VSCode  →  D:\VSCode
C:\VSCode  →  E:\MyTools\VSCode
```

On first run at new location:
- Path change detected
- Shortcuts updated to new path
- VSCode launches normally

### Scenario 2: Different PC (Online)
Copy VSCode folder to USB drive and run on a different PC with internet:

```
PC1: C:\VSCode  →  USB: D:\VSCode  →  PC2: D:\VSCode
```

On first run on PC2:
- PC change detected (COMPUTERNAME comparison)
- Environment reconfiguration triggered:
  - Fonts installed from `.staging/fonts/`
  - PowerShell 7 installed via winget (if missing)
  - Oh My Posh installed via winget (if missing)
  - Theme copied from `.staging/theme/`
  - Profile copied from `.staging/profile/`
  - Shortcuts created for current PC
- VSCode update check performed
- VSCode launches

### Scenario 3: Different PC (Offline)
Copy VSCode folder to USB drive and run on a PC without internet:

```
PC1: C:\VSCode  →  USB: E:\VSCode  →  PC3 (offline): E:\VSCode
```

On first run on PC3 (offline):
- Internet connectivity check fails (ping 8.8.8.8)
- Offline mode activated
- Environment reconfiguration using **only** `.staging` files:
  - Fonts installed from `.staging/fonts/`
  - PowerShell 7/Oh My Posh installation skipped (requires internet)
  - Theme copied from `.staging/theme/` (if Oh My Posh exists)
  - Profile copied from `.staging/profile/`
  - Shortcuts created
- VSCode update check skipped
- VSCode launches with existing version

### Scenario 4: N-PC Portability
Same path (e.g., D:\VSCode) on multiple different PCs:

```
PC1: D:\VSCode (COMPUTERNAME=DESKTOP-HOME)
PC2: D:\VSCode (COMPUTERNAME=WORK-PC)
PC3: D:\VSCode (COMPUTERNAME=LAPTOP-OFFICE)
```

Each PC is correctly identified:
- `.install_marker` stores path + COMPUTERNAME
- PC change detection triggers even when path is identical
- Each PC gets proper environment configuration

## File Structure

```
C:\VSCode\
├── Code.exe                      # VSCode executable
├── launcher.cmd                  # Portable launcher with auto-update
├── version.txt                   # Current VSCode version
├── data\                         # Portable data folder
│   ├── .install_marker          # Path + COMPUTERNAME (for change detection)
│   ├── .staging\                # Offline installation files
│   │   ├── fonts\
│   │   │   ├── 0xProto.zip     # 0xProto Nerd Font backup
│   │   │   └── font_ttf2.zip   # DalseoHealing font backup
│   │   ├── theme\
│   │   │   └── tos-term.omp.json
│   │   ├── profile\
│   │   │   └── Microsoft.PowerShell_profile.ps1
│   │   └── modules\            # (Reserved for future use)
│   ├── extensions\              # VSCode extensions
│   ├── user-data\               # VSCode user data
│   │   └── User\
│   │       └── settings.json   # VSCode settings (relative paths)
│   └── lib\
│       └── python\              # Python portable
│           ├── python.exe
│           ├── python.cmd       # Python wrapper
│           ├── pip.cmd          # pip wrapper (relative paths)
│           └── Scripts\
└── bin\
    └── code.cmd                 # VSCode CLI
```

## launcher.cmd Behavior

### 1. Internet Connectivity Detection
```batch
ping -n 1 -w 1000 8.8.8.8 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "ONLINE=1"
) else (
    set "ONLINE=0"
)
```

### 2. Path & PC Change Detection
```batch
# .install_marker format (2 lines):
# Line 1: Last installation path
# Line 2: Last COMPUTERNAME

if /i not "%LastPath%"=="%VSCodeDir%" (
    echo [INFO] Path changed: %LastPath% -> %VSCodeDir%
    set "NeedSetup=1"
)

if /i not "%LastPC%"=="%COMPUTERNAME%" (
    echo [INFO] PC changed: %LastPC% -> %COMPUTERNAME%
    set "NeedSetup=1"
)
```

### 3. Auto-Reconfiguration Logic

When `NeedSetup=1` (path or PC changed):

**Online Mode (ONLINE=1):**
- Install fonts from `.staging/fonts/` (always from staging)
- Install PowerShell 7 via winget (if missing)
- Install Oh My Posh via winget (if missing)
- Copy theme from `.staging/theme/` to Oh My Posh themes folder
- Copy PowerShell profile from `.staging/profile/` to profile directory
- Create/update desktop and start menu shortcuts
- Update `.install_marker` with new path + COMPUTERNAME

**Offline Mode (ONLINE=0):**
- Install fonts from `.staging/fonts/` (always from staging)
- Skip PowerShell 7 installation (requires internet)
- Skip Oh My Posh installation (requires internet)
- Copy theme from `.staging/theme/` (if Oh My Posh already exists)
- Copy PowerShell profile from `.staging/profile/`
- Create/update shortcuts
- Update `.install_marker`

### 4. VSCode Update (Online Only)

When `ONLINE=1`:
- Check latest version from `https://update.code.visualstudio.com/`
- Compare with `version.txt`
- If newer version available:
  - Download new VSCode archive
  - Remove old files (preserve `data/`, `launcher.cmd`, `version.txt`)
  - Extract new version
  - Update `version.txt`

When `ONLINE=0`:
- Skip update check
- Launch existing VSCode version

## .staging Folder System

### Purpose
The `.staging` folder provides offline installation capability by storing backup copies of all downloaded files during initial installation.

### Contents

**fonts/**: Font installation files
- `0xProto.zip`: 0xProto Nerd Font Mono v3.3.0
- `font_ttf2.zip`: DalseoHealing (달서힐링체)

**theme/**: Oh My Posh theme
- `tos-term.omp.json`: Custom terminal theme

**profile/**: PowerShell configuration
- `Microsoft.PowerShell_profile.ps1`: PowerShell profile with Oh My Posh initialization

**modules/**: (Reserved for PowerShell modules - future enhancement)

### Update Behavior

During online installation:
1. Files are downloaded from the internet
2. Copies are saved to `.staging/` subdirectories
3. Files are installed from `.staging/` (not directly from download)

This ensures `.staging/` always contains the most recent files for offline use.

## Technical Details

### Relative Path Handling

**settings.json**:
```json
{
  "python.defaultInterpreterPath": "${execPath}\\..\\data\\lib\\python\\python.exe",
  "terminal.integrated.env.windows": {
    "PATH": "${execPath}\\..\\bin;${execPath}\\..\\data\\lib\\python;${env:PATH}"
  }
}
```

**pip.cmd**:
```batch
@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
"%SCRIPT_DIR%\python.exe" -m pip %*
endlocal
```

**python.cmd**:
```batch
@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
"%SCRIPT_DIR%\python.exe" %*
endlocal
```

### Absolute Paths for System Tools

To avoid conflicts with user-installed tools (e.g., Cygwin), the installer uses absolute paths:

```batch
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "CURL=%SystemRoot%\System32\curl.exe"
set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
```

## Usage Examples

### Example 1: Initial Installation
```cmd
# Run installer
VSCode_Installer.cmd

# Enter installation path (or press Enter for C:\VSCode)
Enter installation path (default: C:\VSCode): D:\MyTools\VSCode

# Installation completes with:
# - VSCode installed to D:\MyTools\VSCode
# - .staging folder created with backup files
# - Shortcuts created on desktop and start menu
# - .install_marker created with path + COMPUTERNAME

# Launch VSCode
D:\MyTools\VSCode\launcher.cmd
```

### Example 2: Transfer to USB (Same PC)
```cmd
# Copy entire VSCode folder to USB drive
xcopy D:\MyTools\VSCode E:\VSCode /E /I /H

# Launch from USB
E:\VSCode\launcher.cmd

# First run behavior:
# - Path change detected (D:\ -> E:\)
# - COMPUTERNAME matches (same PC)
# - Shortcuts updated to E:\VSCode\launcher.cmd
# - .install_marker updated
# - VSCode launches
```

### Example 3: Different PC with Internet
```cmd
# On PC2 (online), run from USB
E:\VSCode\launcher.cmd

# First run behavior:
# - PC change detected (COMPUTERNAME differs)
# - Internet connection detected (ONLINE=1)
# - Fonts installed from .staging/fonts/
# - PowerShell 7 installed via winget
# - Oh My Posh installed via winget
# - Theme copied from .staging/theme/
# - Profile copied from .staging/profile/
# - Shortcuts created for PC2
# - VSCode update checked (latest version downloaded if available)
# - .install_marker updated with PC2's COMPUTERNAME
# - VSCode launches
```

### Example 4: Different PC without Internet
```cmd
# On PC3 (offline), run from USB
F:\VSCode\launcher.cmd

# First run behavior:
# - PC change detected (COMPUTERNAME differs)
# - Internet connection check fails (ONLINE=0)
# - Fonts installed from .staging/fonts/
# - PowerShell 7 installation skipped (offline)
# - Oh My Posh installation skipped (offline)
# - Theme copied from .staging/theme/ (if Oh My Posh already installed)
# - Profile copied from .staging/profile/
# - Shortcuts created for PC3
# - VSCode update skipped (offline)
# - .install_marker updated with PC3's COMPUTERNAME
# - VSCode launches with existing version
```

### Example 5: Python Usage
```cmd
# In VSCode integrated terminal
cd F:\VSCode\data\lib\python

# Install packages using pip (relative paths work)
pip.cmd install numpy pandas matplotlib

# Run Python scripts
python.cmd my_script.py

# VSCode recognizes Python interpreter automatically
# (configured via settings.json relative path)
```

## Advantages

### True Portability
- Copy entire folder anywhere (local drives, USB, network shares)
- Works across different Windows machines
- No registry modifications
- No system PATH modifications required

### Offline Capable
- Initial installation downloads and stages all files
- Subsequent installations on offline PCs use staged files
- No internet dependency after first install

### Multi-PC Support
- Automatic detection of PC changes via COMPUTERNAME
- Each PC gets proper environment configuration
- Shortcuts point to correct paths on each PC

### Auto-Update (Online)
- VSCode automatically checks for updates on launch
- Background update without user intervention
- User data always preserved

### ⚡ Performance
- Native Windows commands (ping, tar, curl)
- PowerShell used only when necessary
- Minimal startup overhead

## Troubleshooting

### Issue: Fonts not installed on new PC
**Cause**: Offline mode skips font installation if `.staging/fonts/` is missing.

**Solution**: Ensure `.staging/fonts/` contains:
- `0xProto.zip`
- `font_ttf2.zip`

### Issue: PowerShell 7 not available
**Cause**: Offline installation cannot install PowerShell 7.

**Solution**: 
- Connect to internet and re-run launcher.cmd, or
- Manually install PowerShell 7 from https://aka.ms/powershell

### Issue: VSCode not updating
**Cause**: Offline mode or update check failed.

**Solution**: 
- Verify internet connection (ping 8.8.8.8)
- Check `version.txt` exists in VSCode directory
- Manually delete `version.txt` to force re-check

### Issue: Python not recognized in VSCode
**Cause**: settings.json not created or corrupted.

**Solution**: 
- Check `data\user-data\User\settings.json` exists
- Verify it contains `"python.defaultInterpreterPath": "${execPath}\\..\\data\\lib\\python\\python.exe"`

## Requirements

- **OS**: Windows 10 or Windows 11
- **Disk Space**: ~2GB (VSCode + Python + fonts + staging files)
- **Internet** (initial install only): Required for downloading VSCode, Python, fonts, theme
- **Winget** (optional): For PowerShell 7 and Oh My Posh installation on new PCs

## License

This script is provided as-is for personal and educational use.

## Credits

- **Fonts**: 
  - 0xProto Nerd Font: https://github.com/ryanoasis/nerd-fonts
  - DalseoHealing: Daegu Metropolitan City Dalseo-gu
- **Oh My Posh**: https://ohmyposh.dev/
- **PowerShell Modules**: Terminal-Icons, modern-unix-win, PSFzf
- **VSCode**: Microsoft Corporation
- **Python**: Python Software Foundation

**pip.cmd**:
```batch
@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
"%SCRIPT_DIR%\python.exe" -m pip %*
exit /b %ERRORLEVEL%
```

### Path Change Detection
The `.install_marker` file stores the last installation path and COMPUTERNAME:
```batch
C:\VSCode
DESKTOP-HOME
```

launcher.cmd compares current path and PC name to detect changes.

## Additional Notes

### Terminal Profile Reload
To apply PowerShell profile changes without restarting VSCode:
```
Ctrl+Shift+P → "Terminal: Select Default Profile" → PowerShell
```

### Font Configuration
Verify font settings in VSCode settings.json:
```json
"editor.fontFamily": "'0xProto Nerd Font Mono', DalseoHealing, Consolas"
```

### Manual PowerShell 7 Installation
If automatic installation fails, install manually:
```cmd
winget install Microsoft.PowerShell
```

## License
This script is provided as-is for personal and educational use.

Components used:
- VSCode: MIT License
- Python: PSF License
- PowerShell: MIT License
- Oh My Posh: MIT License
- Nerd Fonts: MIT License

## Author
- GitHub: @atticle
- Repository: https://github.com/PlanXLab/VSCode-Environment-Instasller
