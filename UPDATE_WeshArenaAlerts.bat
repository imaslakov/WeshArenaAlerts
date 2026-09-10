@echo off
setlocal EnableExtensions

title WeshArenaAlerts Updater

set "ADDONS_DIR=D:\World of Warcraft\_anniversary_\Interface\AddOns"
set "ADDON_DIR=%ADDONS_DIR%\WeshArenaAlerts"
set "STAGING_DIR=%ADDONS_DIR%\WeshArenaAlerts.__new"
set "BACKUP_DIR=%ADDONS_DIR%\WeshArenaAlerts.__backup"
set "ZIP_URL=https://github.com/imaslakov/WeshArenaAlerts/archive/refs/heads/main.zip"
set "TEMP_DIR=%TEMP%\WeshArenaAlerts_Update"
set "ZIP_FILE=%TEMP_DIR%\WeshArenaAlerts-main.zip"
set "EXTRACT_DIR=%TEMP_DIR%\extract"

echo ==========================================
echo          WeshArenaAlerts Updater
echo ==========================================
echo.
echo Installing latest version from GitHub main...
echo.

if not exist "%ADDONS_DIR%" (
    echo ERROR: WoW AddOns folder was not found:
    echo %ADDONS_DIR%
    echo.
    pause
    exit /b 1
)

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri $env:ZIP_URL -OutFile $env:ZIP_FILE; Expand-Archive -LiteralPath $env:ZIP_FILE -DestinationPath $env:EXTRACT_DIR -Force"

if errorlevel 1 (
    echo.
    echo ERROR: Could not download or extract the latest version.
    echo Your current addon was NOT changed.
    echo.
    pause
    exit /b 1
)

set "SOURCE_DIR=%EXTRACT_DIR%\WeshArenaAlerts-main"

if not exist "%SOURCE_DIR%\WeshArenaAlerts_TBC.toc" (
    echo.
    echo ERROR: Downloaded package does not contain WeshArenaAlerts_TBC.toc.
    echo Your current addon was NOT changed.
    echo.
    pause
    exit /b 1
)

if exist "%STAGING_DIR%" rmdir /s /q "%STAGING_DIR%"
mkdir "%STAGING_DIR%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $src=$env:SOURCE_DIR; $dst=$env:STAGING_DIR; Get-ChildItem -LiteralPath $src -Force | Where-Object { $_.Name -notin @('.git','.github','tests','README.md','UPDATE_WeshArenaAlerts.bat') } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dst -Recurse -Force }"

if errorlevel 1 (
    echo.
    echo ERROR: Could not prepare the new addon version.
    echo Your current addon was NOT changed.
    echo.
    if exist "%STAGING_DIR%" rmdir /s /q "%STAGING_DIR%"
    pause
    exit /b 1
)

if not exist "%STAGING_DIR%\WeshArenaAlerts_TBC.toc" (
    echo.
    echo ERROR: Staged addon failed verification.
    echo Your current addon was NOT changed.
    echo.
    if exist "%STAGING_DIR%" rmdir /s /q "%STAGING_DIR%"
    pause
    exit /b 1
)

if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%"

if exist "%ADDON_DIR%" (
    move "%ADDON_DIR%" "%BACKUP_DIR%" >nul
    if errorlevel 1 (
        echo.
        echo ERROR: Could not replace the current addon folder.
        echo Close programs that may be using the folder and try again.
        echo.
        rmdir /s /q "%STAGING_DIR%" >nul 2>&1
        pause
        exit /b 1
    )
)

move "%STAGING_DIR%" "%ADDON_DIR%" >nul
if errorlevel 1 (
    echo.
    echo ERROR: Could not install the new version.
    echo Attempting to restore the previous version...
    if exist "%BACKUP_DIR%" move "%BACKUP_DIR%" "%ADDON_DIR%" >nul
    echo.
    pause
    exit /b 1
)

if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%"
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"

echo.
echo ==========================================
echo   WeshArenaAlerts updated successfully!
echo ==========================================
echo.
echo In WoW, type /reload if the game is running.
echo.
pause
exit /b 0
