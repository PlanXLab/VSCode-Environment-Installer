@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ================================================
echo    VSCode Portable Installation Script
echo    Includes: Fonts, PowerShell 7, Oh My Posh,
echo              VSCode Portable, Python Portable
echo ================================================
echo.

REM ================================================
REM Set installation directory
REM ================================================
set "DEFAULT_DIR=C:\VSCode"
echo [INFO] Default installation directory: %DEFAULT_DIR%
echo.
set /p "VSCodeDir=Enter installation directory (or press ENTER for default): "

if "%VSCodeDir%"=="" (
    set "VSCodeDir=%DEFAULT_DIR%"
    echo [INFO] Using default directory: !VSCodeDir!
) else (
    echo [INFO] Using custom directory: !VSCodeDir!
)

echo.

REM Validate directory
if exist "%VSCodeDir%" (
    echo [ERROR] The path "%VSCodeDir%" already exists.
    echo [ERROR] Please remove it or choose a different location.
    pause
    exit /b 1
)

REM ================================================
REM Set working directories and tools
REM ================================================
set "TempDir=%TEMP%\vscode-full-setup"

if not exist "%TempDir%" mkdir "%TempDir%"

REM Use absolute paths for Windows built-in tools to avoid conflicts
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "CURL=%SystemRoot%\System32\curl.exe"
set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"

REM Check if curl exists
if not exist "%CURL%" (
    echo [WARN] curl.exe not found. Falling back to PowerShell download.
    set "USE_POWERSHELL_CURL=1"
)

REM ================================================
REM Check for winget
REM ================================================
where winget >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 'winget' is not installed on this system.
    echo Please install App Installer from the Microsoft Store:
    echo https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1
    exit /b 1
)

REM ================================================
REM STEP 1: Install Fonts
REM ================================================
echo.
echo ================================================
echo STEP 1: Installing Fonts
echo ================================================
echo.

echo [INFO] Checking installed fonts...
for /f "tokens=1,2 delims=," %%A in ('"%POWERSHELL%" -NoProfile -Command ^
  "$fonts1 = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';" ^
  "$fonts2 = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';" ^
  "$all = $fonts1.PSObject.Properties + $fonts2.PSObject.Properties;" ^
  "$names = $all | ForEach-Object { $_.Name };" ^
  "$hasNerd = $names | Where-Object { $_ -like '*0xProto Nerd Font Mono*' };" ^
  "$hasDalseo = $names | Where-Object { $_ -like '*달서힐링체*' };" ^
  "[string]::Join(',', [bool]($hasNerd), [bool]($hasDalseo))"') do (
    set "hasNerd=%%A"
    set "hasDalseo=%%B"
)

if /i "%hasNerd%"=="True" if /i "%hasDalseo%"=="True" (
    echo [INFO] Required fonts already installed.
    goto :SKIP_FONTS
)

echo [INFO] Installing missing fonts...
set "FontsDir=%TempDir%\fonts"
mkdir "%FontsDir%" 2>nul
pushd "%FontsDir%"

if /i "%hasNerd%"=="False" (
    echo [INFO] Downloading 0xProto Nerd Font...
    if defined USE_POWERSHELL_CURL (
        "%POWERSHELL%" -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/0xProto.zip' -OutFile '0xProto.zip' -UseBasicParsing" || exit /b 1
    ) else (
        "%CURL%" -L -o "0xProto.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/0xProto.zip" || exit /b 1
    )
    
    REM Save to staging for offline installation
    if exist "%VSCodeDir%\data\.staging\fonts" (
        echo [INFO] Saving to staging folder...
        copy /Y "0xProto.zip" "%VSCodeDir%\data\.staging\fonts\0xProto.zip" >nul
    )
    
    "%POWERSHELL%" -NoProfile -Command "Expand-Archive -Path '0xProto.zip' -DestinationPath '.' -Force"
    del /f /q "0xProto.zip"
    "%POWERSHELL%" -NoProfile -Command "Get-ChildItem . -File | Where-Object { $_.Name -notlike '*Regular.ttf' } | Remove-Item -Force"
)

if /i "%hasDalseo%"=="False" (
    echo [INFO] Downloading DalseoHealing font...
    if defined USE_POWERSHELL_CURL (
        "%POWERSHELL%" -NoProfile -Command "Invoke-WebRequest -Uri 'https://dalseo.daegu.kr/cmsh/dalseo.daegu.kr/images/content/font_ttf2.zip' -OutFile 'font_ttf2.zip' -UseBasicParsing" || exit /b 1
    ) else (
        "%CURL%" -L -o "font_ttf2.zip" "https://dalseo.daegu.kr/cmsh/dalseo.daegu.kr/images/content/font_ttf2.zip" || exit /b 1
    )
    
    REM Save to staging for offline installation
    if exist "%VSCodeDir%\data\.staging\fonts" (
        echo [INFO] Saving to staging folder...
        copy /Y "font_ttf2.zip" "%VSCodeDir%\data\.staging\fonts\font_ttf2.zip" >nul
    )
    
    "%POWERSHELL%" -NoProfile -Command "Expand-Archive -Path 'font_ttf2.zip' -DestinationPath '.' -Force"
    del /f /q "font_ttf2.zip"
    "%POWERSHELL%" -NoProfile -Command "Get-ChildItem . -File | Where-Object { $_.Name -notlike '*DalseoHealingMedium.ttf' } | Remove-Item -Force"
)

"%POWERSHELL%" -NoProfile -Command ^
 "$ErrorActionPreference = 'Stop';" ^
 "try {" ^
 "    $shell = New-Object -ComObject Shell.Application;" ^
 "    $fonts = $shell.Namespace(0x14);" ^
 "    Get-ChildItem . -Filter '*.ttf' | ForEach-Object {" ^
 "        Write-Host \"Installing font: $($_.Name)\";" ^
 "        $fonts.CopyHere($_.FullName, 4 + 16);" ^
 "        Start-Sleep -Milliseconds 500" ^
 "    }" ^
 "} catch {" ^
 "    Write-Error \"Font installation failed: $_\";" ^
 "    exit 1" ^
 "}"

if errorlevel 1 (
    echo [ERROR] Font installation failed.
    popd
    exit /b 1
)

popd
rmdir /s /q "%FontsDir%"
echo [INFO] Fonts installation complete.

:SKIP_FONTS

REM ================================================
REM STEP 2: Install PowerShell 7
REM ================================================
echo.
echo ================================================
echo STEP 2: Installing PowerShell 7
echo ================================================
echo.

echo [INFO] Checking PowerShell 7...
if not exist "%PWSH_EXE%" (
    echo [INFO] Installing PowerShell 7...
    winget install --id Microsoft.PowerShell -s winget --accept-package-agreements --accept-source-agreements || (
        echo [ERROR] PowerShell 7 installation failed.
        exit /b 1
    )
    timeout /t 5 >nul
    if not exist "%PWSH_EXE%" (
        echo [ERROR] PowerShell 7 installation completed but pwsh.exe was not found.
        echo [ERROR] Please restart your system and run this script again.
        exit /b 1
    )
) else (
    echo [INFO] PowerShell 7 is already installed.
)
echo [INFO] PowerShell 7 path: %PWSH_EXE%

REM ================================================
REM STEP 3: Install Oh My Posh
REM ================================================
echo.
echo ================================================
echo STEP 3: Installing Oh My Posh
echo ================================================
echo.

where oh-my-posh >nul 2>nul
if errorlevel 1 (
    echo [INFO] Installing Oh My Posh...
    winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Oh My Posh is already installed.
)

REM ================================================
REM STEP 4: Install Oh My Posh Theme
REM ================================================
echo.
echo ================================================
echo STEP 4: Installing Oh My Posh Theme
echo ================================================
echo.

set "ThemesPath=%LocalAppData%\Programs\oh-my-posh\themes"
if not exist "%ThemesPath%\tos-term.omp.json" (
    echo [INFO] Downloading custom theme...
    mkdir "%ThemesPath%" >nul 2>nul
    if defined USE_POWERSHELL_CURL (
        "%POWERSHELL%" -NoProfile -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/atticle/tos/main/win/oh-my-posh/tos-term.omp.json' -OutFile '%ThemesPath%\tos-term.omp.json' -UseBasicParsing"
    ) else (
        "%CURL%" -L -o "%ThemesPath%\tos-term.omp.json" "https://raw.githubusercontent.com/atticle/tos/main/win/oh-my-posh/tos-term.omp.json"
    )
    
    REM Save to staging for offline installation
    if exist "%VSCodeDir%\data\.staging\theme" (
        echo [INFO] Saving theme to staging folder...
        copy /Y "%ThemesPath%\tos-term.omp.json" "%VSCodeDir%\data\.staging\theme\tos-term.omp.json" >nul
    )
) else (
    echo [INFO] Custom theme already exists.
)

REM ================================================
REM STEP 5: Install PowerShell Modules and Profile
REM ================================================
echo.
echo ================================================
echo STEP 5: Installing PowerShell Modules and Profile
echo ================================================
echo.

echo [INFO] Installing PowerShell modules and profile...
set "PS1_FILE=%TempDir%\install-posh-modules.ps1"
del "%PS1_FILE%" >nul 2>nul

>>"%PS1_FILE%" echo Write-Host "[INFO] Checking PowerShell modules..."
>>"%PS1_FILE%" echo $mods = 'Terminal-Icons','modern-unix-win','PSFzf'
>>"%PS1_FILE%" echo $missing = @()
>>"%PS1_FILE%" echo foreach ($m in $mods) {
>>"%PS1_FILE%" echo     if (-not (Get-Module -ListAvailable -Name $m)) {
>>"%PS1_FILE%" echo         Write-Host "[INFO] Module '$m' not found. Will install."
>>"%PS1_FILE%" echo         $missing += $m
>>"%PS1_FILE%" echo     } else {
>>"%PS1_FILE%" echo         Write-Host "[INFO] Module '$m' is already installed."
>>"%PS1_FILE%" echo     }
>>"%PS1_FILE%" echo }
>>"%PS1_FILE%" echo if ($missing.Count -gt 0) {
>>"%PS1_FILE%" echo     Write-Host "[INFO] Installing missing modules: $($missing -join ', ')"
>>"%PS1_FILE%" echo     Install-Module -Name $missing -Scope CurrentUser -Force -AllowClobber
>>"%PS1_FILE%" echo } else {
>>"%PS1_FILE%" echo     Write-Host "[INFO] All required modules are already installed."
>>"%PS1_FILE%" echo }
>>"%PS1_FILE%" echo.
>>"%PS1_FILE%" echo Write-Host "[INFO] Downloading PowerShell profile (overwriting if exists)..."
>>"%PS1_FILE%" echo if (-not (Test-Path (Split-Path $PROFILE -Parent))) {
>>"%PS1_FILE%" echo     New-Item -ItemType Directory -Path (Split-Path $PROFILE -Parent) -Force ^| Out-Null
>>"%PS1_FILE%" echo }
>>"%PS1_FILE%" echo Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/atticle/tos/main/win/pwsh7/Microsoft.PowerShell_profile.ps1' -OutFile $PROFILE -UseBasicParsing
>>"%PS1_FILE%" echo.
>>"%PS1_FILE%" echo # Save profile to staging
>>"%PS1_FILE%" echo $stagingProfile = '%VSCodeDir%\data\.staging\profile\Microsoft.PowerShell_profile.ps1'
>>"%PS1_FILE%" echo if (Test-Path (Split-Path $stagingProfile -Parent)) {
>>"%PS1_FILE%" echo     Write-Host "[INFO] Saving profile to staging folder..."
>>"%PS1_FILE%" echo     Copy-Item $PROFILE $stagingProfile -Force
>>"%PS1_FILE%" echo }
>>"%PS1_FILE%" echo Write-Host "[INFO] PowerShell profile has been configured."

if exist "%PWSH_EXE%" (
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1_FILE%"
) else (
    echo [WARN] PowerShell 7 not found at expected location. Attempting to use installed pwsh...
    where pwsh >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] Cannot find PowerShell 7. Please restart your terminal or system.
        exit /b 1
    )
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS1_FILE%"
)
del "%PS1_FILE%"

REM ================================================
REM STEP 6: Install VSCode Portable
REM ================================================
echo.
echo ================================================
echo STEP 6: Installing VSCode Portable
echo ================================================
echo.

if exist "%VSCodeDir%" (
    echo [ERROR] The path "%VSCodeDir%" already exists.
    echo [ERROR] Please remove it or choose a different location.
    exit /b 1
)

REM Create VSCode directory structure first
mkdir "%VSCodeDir%" >nul 2>nul
mkdir "%VSCodeDir%\data" >nul 2>nul
mkdir "%VSCodeDir%\data\extensions" >nul 2>nul
mkdir "%VSCodeDir%\data\user-data" >nul 2>nul
mkdir "%VSCodeDir%\data\lib" >nul 2>nul

REM Create staging folders for offline installation
echo [INFO] Creating staging folders for offline support...
set "StagingDir=%VSCodeDir%\data\.staging"
mkdir "%StagingDir%" >nul 2>nul
mkdir "%StagingDir%\fonts" >nul 2>nul
mkdir "%StagingDir%\theme" >nul 2>nul
mkdir "%StagingDir%\modules" >nul 2>nul
mkdir "%StagingDir%\profile" >nul 2>nul

set "VersionFile=%VSCodeDir%\version.txt"
set "SettingsDir=%VSCodeDir%\data\user-data\User"
set "SettingsJson=%SettingsDir%\settings.json"

echo [INFO] Fetching latest VSCode version...
for /f "usebackq tokens=*" %%A in (`"%POWERSHELL%" -NoProfile -Command "$r = [System.Net.HttpWebRequest]::Create('https://update.code.visualstudio.com/latest/win32-x64-archive/stable'); $r.Method = 'HEAD'; $r.AllowAutoRedirect = $false; $res = $r.GetResponse(); $loc = $res.Headers['Location']; $res.Close(); if ($loc -match 'VSCode-win32-x64-([\d\.]+)\.zip') { $matches[1] }"`) do (
    set "WebVersion=%%A"
)

if "!WebVersion!"=="" (
    echo [ERROR] Failed to retrieve the latest VSCode version.
    exit /b 1
)

echo [INFO] Downloading VSCode version !WebVersion!...
set "ZipPath=%TempDir%\VSCode-win-x64.zip"

if defined USE_POWERSHELL_CURL (
    "%POWERSHELL%" -NoProfile -Command "Invoke-WebRequest -Uri 'https://update.code.visualstudio.com/!WebVersion!/win32-x64-archive/stable' -OutFile '%ZipPath%' -UseBasicParsing" || (
        echo [ERROR] Failed to download VSCode.
        exit /b 1
    )
) else (
    "%CURL%" -L -o "%ZipPath%" "https://update.code.visualstudio.com/!WebVersion!/win32-x64-archive/stable" || (
        echo [ERROR] Failed to download VSCode.
        exit /b 1
    )
)

echo [INFO] Extracting VSCode...
taskkill /f /im code-tunnel.exe >nul 2>nul
if not exist "%VSCodeDir%" mkdir "%VSCodeDir%"

if exist "%SystemRoot%\System32\tar.exe" (
    "%SystemRoot%\System32\tar.exe" -xf "%ZipPath%" -C "%VSCodeDir%" || (
        echo [ERROR] Failed to extract VSCode with tar.exe.
        exit /b 1
    )
) else (
    "%POWERSHELL%" -NoProfile -Command "Expand-Archive -Path '%ZipPath%' -DestinationPath '%VSCodeDir%'" || (
        echo [ERROR] Failed to extract VSCode.
        exit /b 1
    )
)
del /f /q "%ZipPath%"

REM Create version.txt
echo !WebVersion! > "%VersionFile%"

echo [INFO] VSCode extracted successfully.

REM ================================================
REM STEP 7: Create Portable Launcher
REM ================================================
echo.
echo ================================================
echo STEP 7: Creating Portable Launcher
echo ================================================
echo.

call :CREATE_LAUNCHER

REM ================================================
REM STEP 8: Create Desktop and Start Menu Shortcuts
REM ================================================
echo.
echo ================================================
echo STEP 8: Creating Shortcuts
echo ================================================
echo.

call :CREATE_SHORTCUTS "%VSCodeDir%"

REM ================================================
REM STEP 9: Install VSCode Extensions
REM ================================================
echo.
echo ================================================
echo STEP 9: Installing VSCode Extensions
echo ================================================
echo.

set "INSTALL_SCRIPT=%TempDir%\install-extensions.ps1"

> "%INSTALL_SCRIPT%" (
    echo $ErrorActionPreference = 'Continue'
    echo $codeExe = '%VSCodeDir%\bin\code.cmd'
    echo $extensionsDir = '%VSCodeDir%\data\extensions'
    echo(
    echo $extensions = @^(
    echo     'ms-vscode-remote.remote-ssh',
    echo     'ms-python.python',
    echo     'ms-toolsai.jupyter',
    echo     'KevinRose.vsc-python-indent',
    echo     'GitHub.copilot',
    echo     'usernamehw.errorlens',
    echo     'Gerrnperl.outline-map',
    echo     'zhuangtongfa.material-theme',
    echo     'teabyii.ayu'
    echo ^)
    echo(
    echo foreach ^($ext in $extensions^) {
    echo     Write-Host "[INFO] Installing extension: $ext"
    echo     ^& $codeExe --install-extension $ext --force --extensions-dir $extensionsDir
    echo     if ^($LASTEXITCODE -ne 0^) {
    echo         Write-Warning "[WARN] Failed to install extension: $ext"
    echo     }
    echo }
)

if exist "%PWSH_EXE%" (
    echo [INFO] Using PowerShell 7 for extension installation...
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_SCRIPT%"
) else (
    echo [WARN] PowerShell 7 not found. Using PowerShell 5.x...
    "%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_SCRIPT%"
)

del "%INSTALL_SCRIPT%" >nul 2>nul

REM ================================================
REM STEP 10: Create VSCode Settings
REM ================================================
echo.
echo ================================================
echo STEP 10: Creating VSCode Settings
echo ================================================
echo.

echo [INFO] Creating settings.json...
mkdir "%SettingsDir%" >nul 2>nul

> "%SettingsJson%" (
    echo {
    echo     "files.autoSave": "onFocusChange",
    echo     "files.autoSaveDelay": 500,
    echo     "files.exclude": {
    echo         "**/largeFolder": true,
    echo         "**/__pycache__": true,
    echo         "**/.venv": true
    echo     },
    echo     "editor.mouseWheelZoom": true,
    echo     "editor.fontFamily": "'0xProto Nerd Font Mono', DalseoHealing, Consolas, 'Courier New', monospace",
    echo     "editor.minimap.enabled": false,
    echo     "editor.renderWhitespace": "boundary",
    echo     "editor.cursorSmoothCaretAnimation": "on",
    echo     "editor.smoothScrolling": true,
    echo     "workbench.colorTheme": "One Dark Pro Darker",
    echo     "workbench.iconTheme": "ayu",
    echo     "workbench.startupEditor": "none",
    echo     "security.workspace.trust.untrustedFiles": "newWindow",
    echo     "window.commandCenter": false,
    echo     "terminal.integrated.mouseWheelZoom": true,
    echo     "terminal.integrated.fontSize": 14,
    echo     "terminal.integrated.defaultProfile.windows": "PowerShell",
    echo     "terminal.integrated.profiles.windows": {
    echo         "PowerShell": {
    echo             "source": "PowerShell",
    echo             "icon": "terminal-powershell",
    echo             "path": "%ProgramFiles%\\PowerShell\\7\\pwsh.exe"
    echo         }
    echo     },
    echo     "terminal.explorerKind": "integrated",
    echo     "terminal.integrated.env.windows": {
    echo         "PATH": "${execPath}\\..\\bin;${execPath}\\..\\data\\lib\\python;${execPath}\\..\\data\\lib\\python\\Scripts;${env:PATH}"
    echo     },
    echo     "python.defaultInterpreterPath": "${execPath}\\..\\data\\lib\\python\\python.exe",
    echo     "python.createEnvironment.trigger": "off",
    echo     "explorer.confirmDelete": false,
    echo     "explorer.confirmPasteNative": false
    echo }
)

echo [INFO] settings.json created successfully.

REM ================================================
REM STEP 11: Install Python Portable
REM ================================================
echo.
echo ================================================
echo STEP 11: Installing Python Portable
echo ================================================
echo.

pushd "%TempDir%"
set "PyDir=%VSCodeDir%\data\lib\python"

echo [INFO] Fetching latest Python 3 version...
"%CURL%" -s --compressed https://www.python.org/downloads/windows/ > latest.html || (
    echo [ERROR] Failed to download Python versions page.
    popd
    exit /b 1
)

if exist "%PWSH_EXE%" (
    "%PWSH_EXE%" -NoProfile -Command ^
        "$html=Get-Content -Raw 'latest.html'; ^
         $pat='Latest Python 3 Release - Python\s+(\d+\.\d+\.\d+)'; ^
         if ($html -match $pat) {Write-Output $matches[1]} else {exit 1}" > tempver.txt || (
        echo [ERROR] Failed to extract Python version.
        del latest.html >nul 2>nul
        popd
        exit /b 1
    )
) else (
    "%POWERSHELL%" -NoProfile -Command ^
        "$html=Get-Content -Raw 'latest.html'; ^
         $pat='Latest Python 3 Release - Python\s+(\d+\.\d+\.\d+)'; ^
         if ($html -match $pat) {Write-Output $matches[1]} else {exit 1}" > tempver.txt || (
        echo [ERROR] Failed to extract Python version.
        del latest.html >nul 2>nul
        popd
        exit /b 1
    )
)

set /p PyVer=<tempver.txt
del latest.html
del tempver.txt

if "!PyVer!"=="" (
    echo [ERROR] Python version not detected.
    popd
    exit /b 1
)

echo [INFO] Latest Python version is: !PyVer!

set "DownloadURL=https://www.python.org/ftp/python/!PyVer!/python-!PyVer!-embed-amd64.zip"
echo [INFO] Downloading Python from: !DownloadURL!
"%CURL%" -L "!DownloadURL!" -o python.zip || (
    echo [ERROR] Failed to download Python embed package.
    popd
    exit /b 1
)

echo [INFO] Extracting Python to: %PyDir%
mkdir "%PyDir%" >nul 2>nul

if exist "%PWSH_EXE%" (
    "%PWSH_EXE%" -NoProfile -Command "Expand-Archive -Path 'python.zip' -DestinationPath '%PyDir%' -Force" || (
        echo [ERROR] Failed to extract Python.
        popd
        exit /b 1
    )
) else (
    "%POWERSHELL%" -NoProfile -Command "Expand-Archive -Path 'python.zip' -DestinationPath '%PyDir%' -Force" || (
        echo [ERROR] Failed to extract Python.
        popd
        exit /b 1
    )
)
del python.zip

REM Adjust Python _pth file if needed
for %%F in ("%PyDir%\python*.?_pth") do (
    echo [INFO] Renaming pth file: %%~nxF
    ren "%%~fF" "__%%~nxF"
)

REM Install pip
echo [INFO] Installing pip...
"%CURL%" -L -o get-pip.py https://bootstrap.pypa.io/get-pip.py || (
    echo [ERROR] Failed to download get-pip.py
    popd
    exit /b 1
)

"%PyDir%\python.exe" get-pip.py --no-warn-script-location || (
    echo [ERROR] Failed to install pip.
    del get-pip.py
    popd
    exit /b 1
)
del get-pip.py

REM Create pip.cmd with relative path support
echo [INFO] Creating pip.cmd wrapper...
(
    echo @echo off
    echo setlocal
    echo rem Portable pip wrapper - works regardless of VSCode location
    echo set "SCRIPT_DIR=%%~dp0"
    echo if "%%SCRIPT_DIR:~-1%%"=="\" set "SCRIPT_DIR=%%SCRIPT_DIR:~0,-1%%"
    echo "%%SCRIPT_DIR%%\python.exe" -m pip %%*
    echo exit /b %%ERRORLEVEL%%
) > "%PyDir%\pip.cmd"

echo [INFO] Creating python.cmd wrapper for convenience...
(
    echo @echo off
    echo setlocal
    echo rem Portable Python wrapper
    echo set "SCRIPT_DIR=%%~dp0"
    echo if "%%SCRIPT_DIR:~-1%%"=="\" set "SCRIPT_DIR=%%SCRIPT_DIR:~0,-1%%"
    echo "%%SCRIPT_DIR%%\python.exe" %%*
    echo exit /b %%ERRORLEVEL%%
) > "%PyDir%\python.cmd"

REM Clean up pip executables in Scripts folder
del /f /q "%PyDir%\Scripts\pip*.exe" >nul 2>nul

popd

echo [INFO] Python portable installation complete.

REM ================================================
REM Save Installation Marker
REM ================================================
echo [INFO] Creating installation marker...
set "InstallMarker=%VSCodeDir%\data\.install_marker"
(
    echo %VSCodeDir%
    echo %COMPUTERNAME%
) > "%InstallMarker%"

REM ================================================
REM Installation Complete
REM ================================================
echo.
echo ================================================
echo    INSTALLATION COMPLETE!
echo ================================================
echo.
echo [SUCCESS] VSCode Portable Environment is ready!
echo.
echo [INFO] VSCode Version: !WebVersion!
echo [INFO] Python Version: !PyVer!
echo [INFO] Installation Directory: %VSCodeDir%
echo [INFO] Computer Name: %COMPUTERNAME%
echo.
echo [INFO] You can now:
echo   - Use desktop or start menu shortcut to launch VSCode
echo   - Move the entire VSCode folder to another location/drive
echo   - The launcher will auto-configure on first run from new location
echo   - Python and pip are accessible via relative paths in VSCode
echo   - Offline installation supported via .staging folder
echo.
echo [INFO] To start VSCode, run: %VSCodeDir%\launcher.cmd
echo.

REM Clean up temp directory
rmdir /s /q "%TempDir%" >nul 2>nul

exit /b 0

REM ================================================
REM SUBROUTINE: Create Portable Launcher
REM ================================================
:CREATE_LAUNCHER
echo [INFO] Creating portable launcher with offline support...
set "LAUNCHER_FILE=%VSCodeDir%\launcher.cmd"

> "%LAUNCHER_FILE%" (
    rem Create launcher file
)

setlocal DisableDelayedExpansion

>>"%LAUNCHER_FILE%" echo @echo off
>>"%LAUNCHER_FILE%" echo setlocal EnableDelayedExpansion
>>"%LAUNCHER_FILE%" echo chcp 65001 ^>nul 2^>^&1
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem ================================================
>>"%LAUNCHER_FILE%" echo rem VSCode Portable Launcher
>>"%LAUNCHER_FILE%" echo rem - Auto-detects PC changes
>>"%LAUNCHER_FILE%" echo rem - Supports online/offline installation
>>"%LAUNCHER_FILE%" echo rem - Auto-updates VSCode when online
>>"%LAUNCHER_FILE%" echo rem ================================================
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo set "VSCodeDir=%%~dp0"
>>"%LAUNCHER_FILE%" echo if "%%VSCodeDir:~-1%%"=="\" set "VSCodeDir=%%VSCodeDir:~0,-1%%"
>>"%LAUNCHER_FILE%" echo set "VersionFile=%%VSCodeDir%%\version.txt"
>>"%LAUNCHER_FILE%" echo set "InstallMarker=%%VSCodeDir%%\data\.install_marker"
>>"%LAUNCHER_FILE%" echo set "StagingDir=%%VSCodeDir%%\data\.staging"
>>"%LAUNCHER_FILE%" echo set "TempDir=%%TEMP%%\vscode-portable-setup"
>>"%LAUNCHER_FILE%" echo set "POWERSHELL=%%SystemRoot%%\System32\WindowsPowerShell\v1.0\powershell.exe"
>>"%LAUNCHER_FILE%" echo set "CURL=%%SystemRoot%%\System32\curl.exe"
>>"%LAUNCHER_FILE%" echo set "PWSH=%%ProgramFiles%%\PowerShell\7\pwsh.exe"
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo if not exist "%%TempDir%%" mkdir "%%TempDir%%"
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem === Check internet connection ===
>>"%LAUNCHER_FILE%" echo set "ONLINE=0"
>>"%LAUNCHER_FILE%" echo ping -n 1 -w 1000 8.8.8.8 ^>nul 2^>^&1
>>"%LAUNCHER_FILE%" echo if %%ERRORLEVEL%% EQU 0 (
>>"%LAUNCHER_FILE%" echo     set "ONLINE=1"
>>"%LAUNCHER_FILE%" echo     echo [INFO] Internet connection: ONLINE
>>"%LAUNCHER_FILE%" echo ) else (
>>"%LAUNCHER_FILE%" echo     echo [INFO] Internet connection: OFFLINE
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem === Read install marker ===
>>"%LAUNCHER_FILE%" echo set "LastPath="
>>"%LAUNCHER_FILE%" echo set "LastPC="
>>"%LAUNCHER_FILE%" echo if exist "%%InstallMarker%%" (
>>"%LAUNCHER_FILE%" echo     for /f "usebackq tokens=1 delims=" %%%%L in ^("%%InstallMarker%%"^) do (
>>"%LAUNCHER_FILE%" echo         if not defined LastPath set "LastPath=%%%%L"
>>"%LAUNCHER_FILE%" echo         if defined LastPath if not defined LastPC set "LastPC=%%%%L"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem === Detect PC or path change ===
>>"%LAUNCHER_FILE%" echo set "NeedSetup=0"
>>"%LAUNCHER_FILE%" echo if not defined LastPath (
>>"%LAUNCHER_FILE%" echo     echo [INFO] First run detected.
>>"%LAUNCHER_FILE%" echo     set "NeedSetup=1"
>>"%LAUNCHER_FILE%" echo ) else (
>>"%LAUNCHER_FILE%" echo     if /i not "%%LastPath%%"=="%%VSCodeDir%%" (
>>"%LAUNCHER_FILE%" echo         echo [INFO] Path changed: %%LastPath%% -^> %%VSCodeDir%%
>>"%LAUNCHER_FILE%" echo         set "NeedSetup=1"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo     if /i not "%%LastPC%%"=="%%COMPUTERNAME%%" (
>>"%LAUNCHER_FILE%" echo         echo [INFO] PC changed: %%LastPC%% -^> %%COMPUTERNAME%%
>>"%LAUNCHER_FILE%" echo         set "NeedSetup=1"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem === Run setup if needed ===
>>"%LAUNCHER_FILE%" echo if "!NeedSetup!"=="1" (
>>"%LAUNCHER_FILE%" echo     echo [INFO] Running environment setup...
>>"%LAUNCHER_FILE%" echo     call :SETUP_ENVIRONMENT
>>"%LAUNCHER_FILE%" echo     echo %%VSCodeDir%% ^> "%%InstallMarker%%"
>>"%LAUNCHER_FILE%" echo     echo %%COMPUTERNAME%% ^>^> "%%InstallMarker%%"
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem === Check for VSCode updates (only if online) ===
>>"%LAUNCHER_FILE%" echo if "!ONLINE!"=="1" (
>>"%LAUNCHER_FILE%" echo     set "LocalVer="
>>"%LAUNCHER_FILE%" echo     if exist "%%VersionFile%%" (
>>"%LAUNCHER_FILE%" echo         for /f "usebackq delims=" %%%%V in ^("%%VersionFile%%"^) do set "LocalVer=%%%%V"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo     if defined LocalVer (
>>"%LAUNCHER_FILE%" echo         set "WebVer="
>>"%LAUNCHER_FILE%" echo         if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo             for /f "usebackq delims=" %%%%A in ^(`"%%PWSH%%" -NoProfile -Command "$r=[System.Net.HttpWebRequest]::Create('https://update.code.visualstudio.com/latest/win32-x64-archive/stable');$r.Method='HEAD';$r.AllowAutoRedirect=$false;$res=$r.GetResponse();$loc=$res.Headers['Location'];$res.Close();if($loc -match 'VSCode-win32-x64-([0-9.]+)\.zip'){$matches[1]}"^`) do set "WebVer=%%%%A"
>>"%LAUNCHER_FILE%" echo         ) else (
>>"%LAUNCHER_FILE%" echo             for /f "usebackq delims=" %%%%A in ^(`"%%POWERSHELL%%" -NoProfile -Command "$r=[System.Net.HttpWebRequest]::Create('https://update.code.visualstudio.com/latest/win32-x64-archive/stable');$r.Method='HEAD';$r.AllowAutoRedirect=$false;$res=$r.GetResponse();$loc=$res.Headers['Location'];$res.Close();if($loc -match 'VSCode-win32-x64-([0-9.]+)\.zip'){$matches[1]}"^`) do set "WebVer=%%%%A"
>>"%LAUNCHER_FILE%" echo         )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo         if defined WebVer (
>>"%LAUNCHER_FILE%" echo             if not "!LocalVer!"=="!WebVer!" (
>>"%LAUNCHER_FILE%" echo                 echo [INFO] VSCode update available: !LocalVer! -^> !WebVer!
>>"%LAUNCHER_FILE%" echo                 call :UPDATE_VSCODE !WebVer!
>>"%LAUNCHER_FILE%" echo             ) else (
>>"%LAUNCHER_FILE%" echo                 echo [INFO] VSCode is up to date ^(!LocalVer!^)
>>"%LAUNCHER_FILE%" echo             )
>>"%LAUNCHER_FILE%" echo         )
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo ) else (
>>"%LAUNCHER_FILE%" echo     echo [INFO] Skipping VSCode update check (offline mode)
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem === Launch VSCode ===
>>"%LAUNCHER_FILE%" echo :run
>>"%LAUNCHER_FILE%" echo start "" "%%VSCodeDir%%\Code.exe"
>>"%LAUNCHER_FILE%" echo exit /b 0
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem ================================================
>>"%LAUNCHER_FILE%" echo rem SUBROUTINE: Setup Environment ^(Offline/Online^)
>>"%LAUNCHER_FILE%" echo rem ================================================
>>"%LAUNCHER_FILE%" echo :SETUP_ENVIRONMENT
>>"%LAUNCHER_FILE%" echo echo [INFO] Setting up environment for %%COMPUTERNAME%%...
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem Install fonts from .staging
>>"%LAUNCHER_FILE%" echo if exist "%%StagingDir%%\fonts\0xProto.zip" (
>>"%LAUNCHER_FILE%" echo     echo [INFO] Installing 0xProto Nerd Font...
>>"%LAUNCHER_FILE%" echo     if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo         "%%PWSH%%" -NoProfile -Command "Expand-Archive -Path '%%StagingDir%%\fonts\0xProto.zip' -DestinationPath '%%TempDir%%\0xProto' -Force; $fonts=(New-Object -ComObject Shell.Application).Namespace(0x14); Get-ChildItem '%%TempDir%%\0xProto' -Filter *.ttf | ForEach-Object { $fonts.CopyHere($_.FullName, 0x10) }; Remove-Item '%%TempDir%%\0xProto' -Recurse -Force"
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         "%%POWERSHELL%%" -NoProfile -Command "Expand-Archive -Path '%%StagingDir%%\fonts\0xProto.zip' -DestinationPath '%%TempDir%%\0xProto' -Force; $fonts=(New-Object -ComObject Shell.Application).Namespace(0x14); Get-ChildItem '%%TempDir%%\0xProto' -Filter *.ttf | ForEach-Object { $fonts.CopyHere($_.FullName, 0x10) }; Remove-Item '%%TempDir%%\0xProto' -Recurse -Force"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo if exist "%%StagingDir%%\fonts\font_ttf2.zip" (
>>"%LAUNCHER_FILE%" echo     echo [INFO] Installing DalseoHealing font...
>>"%LAUNCHER_FILE%" echo     if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo         "%%PWSH%%" -NoProfile -Command "Expand-Archive -Path '%%StagingDir%%\fonts\font_ttf2.zip' -DestinationPath '%%TempDir%%\dalseo' -Force; $fonts=(New-Object -ComObject Shell.Application).Namespace(0x14); Get-ChildItem '%%TempDir%%\dalseo' -Filter *.ttf | ForEach-Object { $fonts.CopyHere($_.FullName, 0x10) }; Remove-Item '%%TempDir%%\dalseo' -Recurse -Force"
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         "%%POWERSHELL%%" -NoProfile -Command "Expand-Archive -Path '%%StagingDir%%\fonts\font_ttf2.zip' -DestinationPath '%%TempDir%%\dalseo' -Force; $fonts=(New-Object -ComObject Shell.Application).Namespace(0x14); Get-ChildItem '%%TempDir%%\dalseo' -Filter *.ttf | ForEach-Object { $fonts.CopyHere($_.FullName, 0x10) }; Remove-Item '%%TempDir%%\dalseo' -Recurse -Force"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem Install PowerShell 7 ^(online only^)
>>"%LAUNCHER_FILE%" echo if not exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo     if %%ONLINE%%==1 (
>>"%LAUNCHER_FILE%" echo         echo [INFO] PowerShell 7 not found. Installing via winget...
>>"%LAUNCHER_FILE%" echo         where winget ^>nul 2^>nul
>>"%LAUNCHER_FILE%" echo         if not errorlevel 1 (
>>"%LAUNCHER_FILE%" echo             winget install --id Microsoft.PowerShell -s winget --accept-package-agreements --accept-source-agreements
>>"%LAUNCHER_FILE%" echo         ) else (
>>"%LAUNCHER_FILE%" echo             echo [WARN] winget not available. PowerShell 7 installation skipped.
>>"%LAUNCHER_FILE%" echo         )
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         echo [WARN] Offline mode: PowerShell 7 installation skipped.
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem Install Oh My Posh ^(online only^)
>>"%LAUNCHER_FILE%" echo where oh-my-posh ^>nul 2^>nul
>>"%LAUNCHER_FILE%" echo if errorlevel 1 (
>>"%LAUNCHER_FILE%" echo     if %%ONLINE%%==1 (
>>"%LAUNCHER_FILE%" echo         echo [INFO] Oh My Posh not found. Installing via winget...
>>"%LAUNCHER_FILE%" echo         where winget ^>nul 2^>nul
>>"%LAUNCHER_FILE%" echo         if not errorlevel 1 (
>>"%LAUNCHER_FILE%" echo             winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements
>>"%LAUNCHER_FILE%" echo         )
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         echo [WARN] Offline mode: Oh My Posh installation skipped.
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem Copy theme from .staging
>>"%LAUNCHER_FILE%" echo if exist "%%StagingDir%%\theme\tos-term.omp.json" (
>>"%LAUNCHER_FILE%" echo     set "ThemeDir=%%LocalAppData%%\Programs\oh-my-posh\themes"
>>"%LAUNCHER_FILE%" echo     if not exist "%%ThemeDir%%" mkdir "%%ThemeDir%%"
>>"%LAUNCHER_FILE%" echo     copy /y "%%StagingDir%%\theme\tos-term.omp.json" "%%ThemeDir%%\" ^>nul
>>"%LAUNCHER_FILE%" echo     echo [INFO] Theme installed to %%ThemeDir%%
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem Copy PowerShell profile from .staging
>>"%LAUNCHER_FILE%" echo if exist "%%StagingDir%%\profile\Microsoft.PowerShell_profile.ps1" (
>>"%LAUNCHER_FILE%" echo     if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo         for /f "usebackq delims=" %%%%P in ^(`"%%PWSH%%" -NoProfile -Command "Split-Path $PROFILE -Parent"^`) do set "ProfileDir=%%%%P"
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         for /f "usebackq delims=" %%%%P in ^(`"%%POWERSHELL%%" -NoProfile -Command "Split-Path $PROFILE -Parent"^`) do set "ProfileDir=%%%%P"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo     if not exist "%%ProfileDir%%" mkdir "%%ProfileDir%%"
>>"%LAUNCHER_FILE%" echo     copy /y "%%StagingDir%%\profile\Microsoft.PowerShell_profile.ps1" "%%ProfileDir%%\" ^>nul
>>"%LAUNCHER_FILE%" echo     echo [INFO] PowerShell profile installed to %%ProfileDir%%
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem Create/Update shortcuts
>>"%LAUNCHER_FILE%" echo echo [INFO] Creating shortcuts...
>>"%LAUNCHER_FILE%" echo if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo     "%%PWSH%%" -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%%USERPROFILE%%\Desktop\Code.lnk');$s.TargetPath='%%VSCodeDir%%\launcher.cmd';$s.IconLocation='%%VSCodeDir%%\Code.exe,0';$s.WorkingDirectory='%%VSCodeDir%%';$s.Save()"
>>"%LAUNCHER_FILE%" echo     "%%PWSH%%" -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\Code.lnk');$s.TargetPath='%%VSCodeDir%%\launcher.cmd';$s.IconLocation='%%VSCodeDir%%\Code.exe,0';$s.WorkingDirectory='%%VSCodeDir%%';$s.Save()"
>>"%LAUNCHER_FILE%" echo ) else (
>>"%LAUNCHER_FILE%" echo     "%%POWERSHELL%%" -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%%USERPROFILE%%\Desktop\Code.lnk');$s.TargetPath='%%VSCodeDir%%\launcher.cmd';$s.IconLocation='%%VSCodeDir%%\Code.exe,0';$s.WorkingDirectory='%%VSCodeDir%%';$s.Save()"
>>"%LAUNCHER_FILE%" echo     "%%POWERSHELL%%" -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\Code.lnk');$s.TargetPath='%%VSCodeDir%%\launcher.cmd';$s.IconLocation='%%VSCodeDir%%\Code.exe,0';$s.WorkingDirectory='%%VSCodeDir%%';$s.Save()"
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo echo [INFO] Environment setup complete.
>>"%LAUNCHER_FILE%" echo goto :EOF
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo rem ================================================
>>"%LAUNCHER_FILE%" echo rem SUBROUTINE: Update VSCode ^(Online Only^)
>>"%LAUNCHER_FILE%" echo rem ================================================
>>"%LAUNCHER_FILE%" echo :UPDATE_VSCODE
>>"%LAUNCHER_FILE%" echo set "LocalVer="
>>"%LAUNCHER_FILE%" echo if exist "%%VersionFile%%" (
>>"%LAUNCHER_FILE%" echo     for /f "usebackq delims=" %%%%V in ^("%%VersionFile%%"^) do set "LocalVer=%%%%V"
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo if not defined LocalVer (
>>"%LAUNCHER_FILE%" echo     echo [WARN] version.txt not found. Skipping update check.
>>"%LAUNCHER_FILE%" echo     goto :EOF
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo echo [INFO] Checking for VSCode updates...
>>"%LAUNCHER_FILE%" echo set "WebVer="
>>"%LAUNCHER_FILE%" echo if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo     for /f "usebackq delims=" %%%%A in ^(`"%%PWSH%%" -NoProfile -Command "$r=[System.Net.HttpWebRequest]::Create('https://update.code.visualstudio.com/latest/win32-x64-archive/stable');$r.Method='HEAD';$r.AllowAutoRedirect=$false;$res=$r.GetResponse();$loc=$res.Headers['Location'];$res.Close();if($loc -match 'VSCode-win32-x64-([0-9.]+)\.zip'){$matches[1]}"^`) do set "WebVer=%%%%A"
>>"%LAUNCHER_FILE%" echo ) else (
>>"%LAUNCHER_FILE%" echo     for /f "usebackq delims=" %%%%A in ^(`"%%POWERSHELL%%" -NoProfile -Command "$r=[System.Net.HttpWebRequest]::Create('https://update.code.visualstudio.com/latest/win32-x64-archive/stable');$r.Method='HEAD';$r.AllowAutoRedirect=$false;$res=$r.GetResponse();$loc=$res.Headers['Location'];$res.Close();if($loc -match 'VSCode-win32-x64-([0-9.]+)\.zip'){$matches[1]}"^`) do set "WebVer=%%%%A"
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo if not defined WebVer (
>>"%LAUNCHER_FILE%" echo     echo [WARN] Could not check online version. Skipping update.
>>"%LAUNCHER_FILE%" echo     goto :EOF
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo if "%%LocalVer%%" NEQ "%%WebVer%%" (
>>"%LAUNCHER_FILE%" echo     echo [INFO] New version available: %%LocalVer%% -^> %%WebVer%%
>>"%LAUNCHER_FILE%" echo     echo [INFO] Updating VSCode...
>>"%LAUNCHER_FILE%" echo     set "ZipFile=%%TempDir%%\vscode-%%WebVer%%.zip"
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo     echo [INFO] Downloading VSCode %%WebVer%%...
>>"%LAUNCHER_FILE%" echo     if exist "%%CURL%%" (
>>"%LAUNCHER_FILE%" echo         "%%CURL%%" -L -o "%%ZipFile%%" "https://update.code.visualstudio.com/%%WebVer%%/win32-x64-archive/stable"
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo             "%%PWSH%%" -NoProfile -Command "Invoke-WebRequest -Uri 'https://update.code.visualstudio.com/%%WebVer%%/win32-x64-archive/stable' -OutFile '%%ZipFile%%' -UseBasicParsing"
>>"%LAUNCHER_FILE%" echo         ) else (
>>"%LAUNCHER_FILE%" echo             "%%POWERSHELL%%" -NoProfile -Command "Invoke-WebRequest -Uri 'https://update.code.visualstudio.com/%%WebVer%%/win32-x64-archive/stable' -OutFile '%%ZipFile%%' -UseBasicParsing"
>>"%LAUNCHER_FILE%" echo         )
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo     if not exist "%%ZipFile%%" (
>>"%LAUNCHER_FILE%" echo         echo [ERROR] Download failed. Skipping update.
>>"%LAUNCHER_FILE%" echo         goto :EOF
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo     echo [INFO] Removing old VSCode files...
>>"%LAUNCHER_FILE%" echo     if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo         "%%PWSH%%" -NoProfile -Command "Get-ChildItem -LiteralPath '%%VSCodeDir%%' -Force | Where-Object { $_.Name -notin @('launcher.cmd','data','version.txt') } | Remove-Item -Recurse -Force"
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         "%%POWERSHELL%%" -NoProfile -Command "Get-ChildItem -LiteralPath '%%VSCodeDir%%' -Force | Where-Object { $_.Name -notin @('launcher.cmd','data','version.txt') } | Remove-Item -Recurse -Force"
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo     echo [INFO] Extracting new version...
>>"%LAUNCHER_FILE%" echo     if exist "%%SystemRoot%%\System32\tar.exe" (
>>"%LAUNCHER_FILE%" echo         "%%SystemRoot%%\System32\tar.exe" -xf "%%ZipFile%%" -C "%%VSCodeDir%%"
>>"%LAUNCHER_FILE%" echo     ) else (
>>"%LAUNCHER_FILE%" echo         if exist "%%PWSH%%" (
>>"%LAUNCHER_FILE%" echo             "%%PWSH%%" -NoProfile -Command "Expand-Archive -Path '%%ZipFile%%' -DestinationPath '%%VSCodeDir%%' -Force"
>>"%LAUNCHER_FILE%" echo         ) else (
>>"%LAUNCHER_FILE%" echo             "%%POWERSHELL%%" -NoProfile -Command "Expand-Archive -Path '%%ZipFile%%' -DestinationPath '%%VSCodeDir%%' -Force"
>>"%LAUNCHER_FILE%" echo         )
>>"%LAUNCHER_FILE%" echo     )
>>"%LAUNCHER_FILE%" echo(
>>"%LAUNCHER_FILE%" echo     echo %%WebVer%% ^> "%%VersionFile%%"
>>"%LAUNCHER_FILE%" echo     del /f /q "%%ZipFile%%" 2^>nul
>>"%LAUNCHER_FILE%" echo     echo [SUCCESS] VSCode updated to %%WebVer%%
>>"%LAUNCHER_FILE%" echo ) else (
>>"%LAUNCHER_FILE%" echo     echo [INFO] VSCode is up to date ^(%%LocalVer%%^)
>>"%LAUNCHER_FILE%" echo )
>>"%LAUNCHER_FILE%" echo goto :EOF

endlocal

echo [INFO] Launcher created successfully.
goto :EOF

REM ================================================
REM SUBROUTINE: Create Shortcuts
REM ================================================
:CREATE_SHORTCUTS
set "VSCODE_PATH=%~1"

if not exist "%USERPROFILE%\Desktop" mkdir "%USERPROFILE%\Desktop"
if not exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs" mkdir "%APPDATA%\Microsoft\Windows\Start Menu\Programs"

echo [INFO] Creating desktop shortcut...
if exist "%PWSH_EXE%" (
    "%PWSH_EXE%" -NoProfile -Command ^
     "$s=(New-Object -COM WScript.Shell).CreateShortcut('%USERPROFILE%\Desktop\Code.lnk');" ^
     "$s.TargetPath='%VSCODE_PATH%\launcher.cmd';" ^
     "$s.IconLocation='%VSCODE_PATH%\Code.exe,0';" ^
     "$s.WorkingDirectory='%VSCODE_PATH%';" ^
     "$s.Save()"
) else (
    "%POWERSHELL%" -NoProfile -Command ^
     "$s=(New-Object -COM WScript.Shell).CreateShortcut('%USERPROFILE%\Desktop\Code.lnk');" ^
     "$s.TargetPath='%VSCODE_PATH%\launcher.cmd';" ^
     "$s.IconLocation='%VSCODE_PATH%\Code.exe,0';" ^
     "$s.WorkingDirectory='%VSCODE_PATH%';" ^
     "$s.Save()"
)

echo [INFO] Creating start menu shortcut...
if exist "%PWSH_EXE%" (
    "%PWSH_EXE%" -NoProfile -Command ^
     "$s=(New-Object -COM WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Code.lnk');" ^
     "$s.TargetPath='%VSCODE_PATH%\launcher.cmd';" ^
     "$s.IconLocation='%VSCODE_PATH%\Code.exe,0';" ^
     "$s.WorkingDirectory='%VSCODE_PATH%';" ^
     "$s.Save()"
) else (
    "%POWERSHELL%" -NoProfile -Command ^
     "$s=(New-Object -COM WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Code.lnk');" ^
     "$s.TargetPath='%VSCODE_PATH%\launcher.cmd';" ^
     "$s.IconLocation='%VSCODE_PATH%\Code.exe,0';" ^
     "$s.WorkingDirectory='%VSCODE_PATH%';" ^
     "$s.Save()"
)

echo [INFO] Shortcuts created successfully.
goto :EOF
