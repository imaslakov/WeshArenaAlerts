@echo off
setlocal EnableExtensions EnableDelayedExpansion

title WeshArenaAlerts - One-Click Updater
mode con cols=82 lines=32 >nul 2>&1
color 0B

set "ADDONS_DIR=D:\World of Warcraft\_anniversary_\Interface\AddOns"
set "ADDON_DIR=%ADDONS_DIR%\WeshArenaAlerts"
set "STAGING_DIR=%ADDONS_DIR%\WeshArenaAlerts.__new"
set "BACKUP_DIR=%ADDONS_DIR%\WeshArenaAlerts.__backup"
set "BUILD_FILE=%ADDON_DIR%\.wesh_build"
set "REPO_API=https://api.github.com/repos/imaslakov/WeshArenaAlerts/commits/main"
set "ZIP_URL=https://github.com/imaslakov/WeshArenaAlerts/archive/refs/heads/main.zip"
set "SELF_UPDATE_URL=https://raw.githubusercontent.com/imaslakov/WeshArenaAlerts/main/UPDATE_WeshArenaAlerts.bat"
set "SELF_PATH=%~f0"
set "TEMP_DIR=%TEMP%\WeshArenaAlerts_Update"
set "ZIP_FILE=%TEMP_DIR%\WeshArenaAlerts-main.zip"
set "EXTRACT_DIR=%TEMP_DIR%\extract"
set "SOURCE_DIR=%EXTRACT_DIR%\WeshArenaAlerts-main"
set "SELF_UPDATED=0"

if /I "%~1"=="--self-updated" set "SELF_UPDATED=1"

if "!SELF_UPDATED!"=="0" (
    cls
    call :HEADER
    echo.
    echo   Checking updater...
    call :SELF_UPDATE
    if "!SELF_UPDATE_ACTION!"=="RESTART" exit /b 0
)

set "MODE=FIRST INSTALL"
set "HAD_ADDON=0"
set "CURRENT_SHA="
set "CURRENT_SHORT=unknown"
set "LATEST_SHA="
set "LATEST_SHORT=unknown"
set "ERROR_MSG=Unknown error."

if exist "%ADDON_DIR%" (
    set "MODE=UPDATE"
    set "HAD_ADDON=1"
)

if exist "%BUILD_FILE%" (
    set /p CURRENT_SHA=<"%BUILD_FILE%"
    if defined CURRENT_SHA set "CURRENT_SHORT=!CURRENT_SHA:~0,7!"
)

cls
call :HEADER
echo.
if "!SELF_UPDATED!"=="1" echo   UPDATER     : SELF-UPDATED SUCCESSFULLY
echo   MODE        : !MODE!
echo   CURRENT     : !CURRENT_SHORT!
echo   CHANNEL     : GitHub main
if "!HAD_ADDON!"=="1" (
    echo   INSTALL TO  : %ADDON_DIR%
) else (
    echo   INSTALL TO  : %ADDON_DIR%  ^(new^)
)
echo.
echo   ------------------------------------------------------------------------
echo.

if not exist "%ADDONS_DIR%" (
    set "ERROR_MSG=WoW AddOns folder was not found: %ADDONS_DIR%"
    goto :FAIL
)

echo   [1/5] Checking the newest addon build on GitHub...
for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $r=Invoke-RestMethod -UseBasicParsing -Headers @{'User-Agent'='WeshArenaAlerts-Updater'} -Uri $env:REPO_API; Write-Output $r.sha" 2^>nul`) do set "LATEST_SHA=%%S"

if not defined LATEST_SHA (
    set "ERROR_MSG=Could not reach GitHub or read the latest build. Check your internet connection."
    goto :FAIL
)

set "LATEST_SHORT=!LATEST_SHA:~0,7!"
echo         Latest build: !LATEST_SHORT!

if defined CURRENT_SHA if /I "!CURRENT_SHA!"=="!LATEST_SHA!" goto :UP_TO_DATE

echo.
echo   [2/5] Downloading WeshArenaAlerts...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1
mkdir "%TEMP_DIR%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not create a temporary update folder."
    goto :FAIL
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='WeshArenaAlerts-Updater'} -Uri $env:ZIP_URL -OutFile $env:ZIP_FILE; Expand-Archive -LiteralPath $env:ZIP_FILE -DestinationPath $env:EXTRACT_DIR -Force" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Download or extraction failed. Your installed addon was not changed."
    goto :FAIL
)
echo         Download complete.

echo.
echo   [3/5] Verifying package...
if not exist "%SOURCE_DIR%\WeshArenaAlerts_TBC.toc" (
    set "ERROR_MSG=Downloaded package is invalid: WeshArenaAlerts_TBC.toc was not found."
    goto :FAIL
)
echo         Package verified.

echo.
echo   [4/5] Preparing clean addon files...
if exist "%STAGING_DIR%" rmdir /s /q "%STAGING_DIR%" >nul 2>&1
mkdir "%STAGING_DIR%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not create the staging folder."
    goto :FAIL
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $src=$env:SOURCE_DIR; $dst=$env:STAGING_DIR; Get-ChildItem -LiteralPath $src -Force | Where-Object { $_.Name -notin @('.git','.github','tests','README.md','UPDATE_WeshArenaAlerts.bat','.wesh_build') } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dst -Recurse -Force }" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not prepare the new addon files."
    goto :FAIL
)

if not exist "%STAGING_DIR%\WeshArenaAlerts_TBC.toc" (
    set "ERROR_MSG=Prepared addon failed verification."
    goto :FAIL
)
echo         Files ready.

echo.
echo   [5/5] Installing build !LATEST_SHORT!...
if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%" >nul 2>&1

if exist "%ADDON_DIR%" (
    move "%ADDON_DIR%" "%BACKUP_DIR%" >nul 2>&1
    if errorlevel 1 (
        set "ERROR_MSG=Could not replace the current addon folder. Close any program using it and try again."
        goto :FAIL
    )
)

move "%STAGING_DIR%" "%ADDON_DIR%" >nul 2>&1
if errorlevel 1 (
    if exist "%BACKUP_DIR%" if not exist "%ADDON_DIR%" move "%BACKUP_DIR%" "%ADDON_DIR%" >nul 2>&1
    set "ERROR_MSG=Installation failed. The previous version was restored when possible."
    goto :FAIL
)

>"%BUILD_FILE%" echo !LATEST_SHA!

if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%" >nul 2>&1
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1

color 0A
cls
call :HEADER
echo.
if "!MODE!"=="FIRST INSTALL" (
    echo                         FIRST INSTALL COMPLETE
) else (
    echo                            UPDATE COMPLETE
)
echo.
echo   ------------------------------------------------------------------------
echo.
echo   BUILD       : !LATEST_SHORT!
echo   CHANNEL     : GitHub main
echo   INSTALLED   : %ADDON_DIR%
echo.
echo   WeshArenaAlerts is ready to test.
echo.
echo   If World of Warcraft is already running, type:  /reload
echo.
echo   ------------------------------------------------------------------------
echo.
pause
exit /b 0

:UP_TO_DATE
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1
color 0A
cls
call :HEADER
echo.
echo                           ALREADY UP TO DATE
echo.
echo   ------------------------------------------------------------------------
echo.
echo   BUILD       : !LATEST_SHORT!
echo   CHANNEL     : GitHub main
echo.
echo   You already have the newest WeshArenaAlerts build.
echo   Nothing was changed.
echo.
echo   ------------------------------------------------------------------------
echo.
pause
exit /b 0

:FAIL
if exist "%BACKUP_DIR%" if not exist "%ADDON_DIR%" move "%BACKUP_DIR%" "%ADDON_DIR%" >nul 2>&1
if exist "%STAGING_DIR%" rmdir /s /q "%STAGING_DIR%" >nul 2>&1
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1
color 0C
cls
call :HEADER
echo.
echo                              UPDATE FAILED
echo.
echo   ------------------------------------------------------------------------
echo.
echo   !ERROR_MSG!
echo.
if "!HAD_ADDON!"=="1" (
    echo   Your previous WeshArenaAlerts installation was kept intact.
) else (
    echo   WeshArenaAlerts was not installed.
)
echo.
echo   You can close this window and run the updater again.
echo.
echo   ------------------------------------------------------------------------
echo.
pause
exit /b 1

:SELF_UPDATE
set "SELF_UPDATE_ACTION=CONTINUE"
set "UPDATER_REMOTE=%TEMP%\WeshArenaAlerts_Updater_latest_%RANDOM%_%RANDOM%.bat"
set "SELF_HELPER=%TEMP%\WeshArenaAlerts_SelfUpdate_%RANDOM%_%RANDOM%.cmd"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='WeshArenaAlerts-Updater'} -Uri $env:SELF_UPDATE_URL -OutFile $env:UPDATER_REMOTE" >nul 2>&1
if errorlevel 1 (
    echo         Could not check updater version - continuing with this copy.
    exit /b 0
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$a=(Get-FileHash -Algorithm SHA256 -LiteralPath $env:SELF_PATH).Hash; $b=(Get-FileHash -Algorithm SHA256 -LiteralPath $env:UPDATER_REMOTE).Hash; if ($a -eq $b) { exit 0 } else { exit 10 }" >nul 2>&1
set "HASH_RESULT=!ERRORLEVEL!"

if "!HASH_RESULT!"=="0" (
    del /q "%UPDATER_REMOTE%" >nul 2>&1
    echo         Updater is current.
    exit /b 0
)

if not "!HASH_RESULT!"=="10" (
    del /q "%UPDATER_REMOTE%" >nul 2>&1
    echo         Could not compare updater versions - continuing with this copy.
    exit /b 0
)

echo         New updater found.
echo         Updating updater and restarting...

>"%SELF_HELPER%" echo @echo off
>>"%SELF_HELPER%" echo ping 127.0.0.1 -n 2 ^>nul
>>"%SELF_HELPER%" echo copy /y "%UPDATER_REMOTE%" "%SELF_PATH%" ^>nul
>>"%SELF_HELPER%" echo if errorlevel 1 exit /b 1
>>"%SELF_HELPER%" echo del /q "%UPDATER_REMOTE%" ^>nul 2^>^&1
>>"%SELF_HELPER%" echo start "" "%SELF_PATH%" --self-updated
>>"%SELF_HELPER%" echo del /q "%%~f0" ^>nul 2^>^&1

start "" /min cmd.exe /c ""%SELF_HELPER%""
set "SELF_UPDATE_ACTION=RESTART"
exit /b 0

:HEADER
echo   ========================================================================
echo.
echo                    W E S H   A R E N A   A L E R T S
echo.
echo                         O N E - C L I C K   U P D A T E R
echo.
echo   ========================================================================
exit /b 0
