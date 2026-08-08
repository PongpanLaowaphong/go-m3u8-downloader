@echo off
chcp 65001 > nul
title Go M3U8 Downloader CLI Setup
cd /d "%~dp0"

echo ==================================================
echo       Go M3U8 High-Speed Downloader Setup      
echo ==================================================
echo.

REM Check if executable already exists
if exist "go-m3u8-downloader.exe" goto menu

REM Check Go Compiler Installation in PATH
where go >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%v in ('go version') do set GO_VERSION=%%v
    echo [OK] Go compiler is already installed on this machine:
    echo      %GO_VERSION% (Compatible ^>= 1.18)
    echo.
    goto build
)

REM Check if Go exists in standard installation directory
if exist "C:\Program Files\Go\bin\go.exe" (
    set "PATH=%PATH%;C:\Program Files\Go\bin"
    for /f "tokens=*" %%v in ('"C:\Program Files\Go\bin\go.exe" version') do set GO_VERSION=%%v
    echo [OK] Go compiler found at C:\Program Files\Go\bin:
    echo      %GO_VERSION%
    echo.
    goto build
)

echo [!] Go compiler was not found on your system!
echo [*] Installation reference: https://go.dev/doc/install
echo.
set /p DO_INSTALL="[?] Would you like to automatically install Go compiler now? (Y/N) [Default: Y]: "
if "%DO_INSTALL%"=="" set DO_INSTALL=Y

if /i not "%DO_INSTALL%"=="Y" (
    echo [ERROR] Go compiler is required to build the program. Exiting.
    echo.
    pause
    exit /b 1
)

echo.
echo [*] Installing Go compiler...
where winget >nul 2>nul
if %errorlevel% equ 0 (
    echo [*] Installing via winget...
    winget install --id GoLang.Go -e --accept-source-agreements --accept-package-agreements
    set "PATH=%PATH%;C:\Program Files\Go\bin"
) else (
    echo [*] Downloading official Go MSI installer from https://go.dev/dl/...
    curl -Lo go_installer.msi https://go.dev/dl/go1.22.5.windows-amd64.msi
    if errorlevel 1 (
        echo [ERROR] Failed to download Go installer. Please install Go manually from https://go.dev/doc/install
        echo.
        pause
        exit /b 1
    )
    echo [*] Running Go MSI Installer...
    msiexec /i go_installer.msi /qb
    del /f /q go_installer.msi >nul 2>nul
    set "PATH=%PATH%;C:\Program Files\Go\bin"
)

REM Verify installation
if exist "C:\Program Files\Go\bin\go.exe" (
    set "PATH=%PATH%;C:\Program Files\Go\bin"
)

where go >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo [OK] Go installation completed!
    echo [!] Please close this Command Prompt window and open setup.bat again to refresh system environment variables.
    echo.
    pause
    exit /b 0
)

echo [OK] Go compiler successfully installed!
echo.

:build
echo ==================================================
echo [*] Building go-m3u8-downloader.exe...
echo ==================================================

go build -o go-m3u8-downloader.exe .
if %errorlevel% neq 0 (
    echo [ERROR] Build failed! Please check your source code and dependencies.
    echo.
    pause
    exit /b 1
)

echo [OK] Build completed successfully!
echo.

:menu
cls
echo ==================================================
echo       Go M3U8 High-Speed Downloader Setup      
echo ==================================================
echo.

set M3U8_URL=
set OUT_DIR=
set OUT_FILE=
set CONCURRENCY=

:input_url
set /p M3U8_URL="Enter .m3u8 Playlist URL: "
if "%M3U8_URL%"=="" (
    echo [ERROR] URL cannot be empty! Please try again.
    echo.
    goto input_url
)

echo.
set /p OUT_DIR="Enter output directory location [Default: .\output]: "
if "%OUT_DIR%"=="" set OUT_DIR=.\output

echo.
set /p OUT_FILE="Enter output filename [Default: output.mp4]: "
if "%OUT_FILE%"=="" set OUT_FILE=output.mp4

echo.
set /p CONCURRENCY="Enter concurrent threads count (1-50) [Default: 10]: "
if "%CONCURRENCY%"=="" set CONCURRENCY=10

echo.
echo ==================================================
echo Summary Configuration:
echo   - M3U8 URL     : %M3U8_URL%
echo   - Output Dir   : %OUT_DIR%
echo   - Filename     : %OUT_FILE%
echo   - Concurrency  : %CONCURRENCY% threads
echo ==================================================
echo.

.\go-m3u8-downloader.exe -u "%M3U8_URL%" -d "%OUT_DIR%" -o "%OUT_FILE%" -c %CONCURRENCY%

echo.
echo ==================================================
set /p RETRY="Do you want to download another video? (Y/N) [Default: N]: "
if /i "%RETRY%"=="Y" goto menu

echo.
echo Thank you for using Go M3U8 Downloader!
echo.
pause
