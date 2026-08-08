@echo off
title Go M3U8 Downloader CLI Setup

REM Change working directory to the directory where this script is located
cd /d "%~dp0"

REM Check if executable already exists
if exist "go-m3u8-downloader.exe" goto menu

echo ==================================================
echo Building go-m3u8-downloader.exe...
echo ==================================================

where go >nul 2>nul
if errorlevel 1 (
    echo Error: Go compiler not found! Please install Go or copy go-m3u8-downloader.exe to this directory.
    echo.
    pause
    exit /b 1
)

go build -o go-m3u8-downloader.exe .
if errorlevel 1 (
    echo Error: Build failed! Please check your source code and dependencies.
    echo.
    pause
    exit /b 1
)

echo Build completed successfully!
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
    echo Error: URL cannot be empty! Please try again.
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
