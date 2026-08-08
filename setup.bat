@echo off
chcp 65001 > nul
title Go M3U8 Downloader CLI Setup
cd /d "%~dp0"

echo ==================================================
echo       Go M3U8 High-Speed Downloader Setup      
echo ==================================================
echo.

REM 1. If pre-compiled binary exists, jump to menu
if exist "go-m3u8-downloader.exe" goto menu

REM 2. Check if Go is in PATH
where go >nul 2>nul
if %errorlevel% equ 0 goto go_found_path

REM 3. Check if Go is in default Program Files directory
if exist "C:\Program Files\Go\bin\go.exe" goto go_found_programfiles

REM 4. Check if Go is in 32-bit Program Files directory
if exist "C:\Program Files (x86)\Go\bin\go.exe" goto go_found_programfiles86

REM 5. Go is NOT installed anywhere on this system -> Go to installer
goto go_missing

:go_found_path
echo [OK] Go compiler is already installed on this machine:
go version
echo.
goto build

:go_found_programfiles
set "PATH=%PATH%;C:\Program Files\Go\bin"
echo [OK] Go compiler found at C:\Program Files\Go\bin:
go version
echo.
goto build

:go_found_programfiles86
set "PATH=%PATH%;C:\Program Files (x86)\Go\bin"
echo [OK] Go compiler found at C:\Program Files (x86)\Go\bin:
go version
echo.
goto build

:go_missing
echo [!] Go compiler was not found on your system!
echo [*] Reference: https://go.dev/doc/install
echo.
set DO_INSTALL=Y
set /p DO_INSTALL="[?] Would you like to automatically install Go compiler now? (Y/N) [Default: Y]: "
if "%DO_INSTALL%"=="" set DO_INSTALL=Y

if /i not "%DO_INSTALL%"=="Y" goto manual_install_instructions

echo.
echo [*] Attempting to install Go compiler automatically...

where winget >nul 2>nul
if %errorlevel% equ 0 (
    echo [*] Installing Go via winget...
    winget install --id GoLang.Go -e --accept-source-agreements --accept-package-agreements
    if exist "C:\Program Files\Go\bin\go.exe" set "PATH=%PATH%;C:\Program Files\Go\bin"
    goto verify_install
)

echo [*] Downloading official Go installer from https://go.dev/dl/...
curl -Lo go_installer.msi https://go.dev/dl/go1.22.5.windows-amd64.msi
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download Go installer.
    goto manual_install_instructions
)

echo [*] Running Go MSI Installer...
msiexec /i go_installer.msi /qb
del /f /q go_installer.msi >nul 2>nul
if exist "C:\Program Files\Go\bin\go.exe" set "PATH=%PATH%;C:\Program Files\Go\bin"

:verify_install
if exist "C:\Program Files\Go\bin\go.exe" set "PATH=%PATH%;C:\Program Files\Go\bin"
where go >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Go compiler successfully installed!
    echo.
    goto build
)

echo.
echo [OK] Go installation completed!
echo [!] Please close this Command Prompt window and open setup.bat again to activate Go environment variables.
echo [*] Manual download link if needed: https://go.dev/doc/install
echo.
pause
exit /b 0

:manual_install_instructions
echo.
echo ==================================================
echo [!] Go Compiler Required
echo ==================================================
echo Please download and install Go manually from:
echo -> https://go.dev/doc/install
echo.
echo After installing Go, please open setup.bat again.
echo ==================================================
echo.
pause
exit /b 1

:build
if not exist "go.mod" (
    echo [ERROR] go.mod file was not found in %CD%!
    echo Please ensure setup.bat is located inside the project directory alongside go.mod and main.go.
    echo.
    pause
    exit /b 1
)

echo ==================================================
echo [*] Building go-m3u8-downloader.exe...
echo ==================================================

go build -o go-m3u8-downloader.exe .
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed!
    echo Please ensure Go (>= 1.18) is installed correctly from https://go.dev/doc/install
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
