@echo off
title Mohaffez - Build Release Web
color 0B

echo.
echo ============================================================
echo   Mohaffez App - Release Web Build (Browser / Hosting)
echo ============================================================
echo.

REM Store repo root for .env reference
set REPO_ROOT=%~dp0

REM Switch to the mobile package (web target)
cd /d "%REPO_ROOT%packages\mohaffez_mobile"

REM Check .env exists (in repo root)
if not exist "%REPO_ROOT%.env" (
    echo [ERROR] .env file not found in project root.
    echo         Create it and add your API keys / dart-define values.
    pause
    exit /b 1
)

echo [1/3] Getting dependencies...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)

echo.
echo [2/3] Building release web app...
if exist "build\web" (
    echo Removing previous web build...
    rmdir /S /Q "build\web"
)
call flutter build web --release --pwa-strategy none --source-maps --dart-define-from-file="%REPO_ROOT%.env"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed. Check the output above.
    pause
    exit /b 1
)

echo.
echo Ensuring SPA rewrite file is included...
if exist "%REPO_ROOT%packages\mohaffez_mobile\web\.htaccess" (
    copy /Y "%REPO_ROOT%packages\mohaffez_mobile\web\.htaccess" "build\web\.htaccess" >nul
)

echo.
echo [3/3] Done!
echo.
echo ============================================================
echo   Output: packages\mohaffez_mobile\build\web
echo.
echo   To deploy to Hostinger:
echo     1. Open hPanel ^> File Manager (or connect via FTP)
echo     2. Upload ALL contents of build\web\ to public_html\
echo        (replace existing files)
echo     3. Make sure .htaccess is uploaded (hidden file) ^-^-
echo        required for SPA deep-link routing.
echo ============================================================
echo.
pause
