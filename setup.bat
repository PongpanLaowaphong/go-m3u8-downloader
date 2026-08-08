@echo off
title Go M3U8 Downloader CLI Setup
cd /d "%~dp0"

echo ==================================================
echo       🎬 Go M3U8 High-Speed Downloader Setup      
echo ==================================================
echo.

:: Check Go Compiler Installation
where go >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%v in ('go version') do set GO_VERSION=%%v
    echo ✔ Go compiler is already installed on this machine:
    echo   %GO_VERSION% (Compatible ^>= 1.18)
    echo.
    goto check_binary
)

echo ⚠️  Go compiler was not found on your system!
echo 🌐 Reference: https://go.dev/doc/install
echo.
set /p "DO_INSTALL=👉 Would you like to automatically install Go compiler now? (Y/N) [Default: Y]: "
if "%DO_INSTALL%"=="" set "DO_INSTALL=Y"

if /i not "%DO_INSTALL%"=="Y" (
    echo ❌ Go compiler is required to build the program. Exiting.
    pause
    exit /b 1
)

echo.
echo 🚀 Installing Go compiler...
where winget >nul 2>nul
if %errorlevel% equ 0 (
    winget install --id GoLang.Go -e --accept-source-agreements --accept-package-agreements
    set "PATH=%PATH%;C:\Program Files\Go\bin"
) else (
    echo 📥 Downloading official Go installer from https://go.dev/dl/...
    curl -Lo go_installer.msi https://go.dev/dl/go1.22.5.windows-amd64.msi
    echo ⚙ Running Go MSI Installer...
    msiexec /i go_installer.msi /qb
    del /f /q go_installer.msi >nul 2>nul
    set "PATH=%PATH%;C:\Program Files\Go\bin"
)

where go >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo ⚠️  Go installed! Please restart Command Prompt / Terminal and run setup.bat again.
    echo 🌐 Manual installation guide: https://go.dev/doc/install
    pause
    exit /b 1
)

echo ✔ Go compiler successfully installed!
echo.

:check_binary
if exist "go-m3u8-downloader.exe" goto menu

echo ==================================================
echo 🔧 Building go-m3u8-downloader.exe...
echo ==================================================

go build -o go-m3u8-downloader.exe .
if %errorlevel% neq 0 (
    echo ❌ Error: Build failed! Please check your source code and dependencies.
    echo.
    pause
    exit /b 1
)

echo ✔ Build completed successfully!
echo.

:menu
cls
echo ==================================================
echo       🎬 Go M3U8 High-Speed Downloader Setup      
echo ==================================================
echo.

set M3U8_URL=
set OUT_DIR=
set OUT_FILE=
set CONCURRENCY=

:input_url
set /p M3U8_URL="Enter .m3u8 Playlist URL: "
if "%M3U8_URL%"=="" (
    echo ❌ Error: URL cannot be empty! Please try again.
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
echo 📋 Summary Configuration:
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
echo 👋 Thank you for using Go M3U8 Downloader!
echo.
pause
