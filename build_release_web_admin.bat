@echo off
title Mohafezy - Build Release Web Admin
color 0B

echo.
echo ============================================================
echo   Mohafezy - Admin Dashboard Build (admin.mohafezy.com)
echo ============================================================
echo.

REM Store repo root
set REPO_ROOT=%~dp0

REM Switch to the web admin package
cd /d "%REPO_ROOT%packages\mohaffez_web"

echo [1/3] Getting dependencies...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)

echo.
echo [2/3] Building release web admin...

REM Pass .env if it exists (for optional SENTRY_DSN etc.) — not strictly required
if exist "%REPO_ROOT%.env" (
    call flutter build web --release --pwa-strategy=none --source-maps --dart-define-from-file="%REPO_ROOT%.env"
) else (
    call flutter build web --release --pwa-strategy=none --source-maps
)

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed. Check the output above.
    pause
    exit /b 1
)

echo.
echo [3/3] Done!
echo.
echo ============================================================
echo   Output: packages\mohaffez_web\build\web\
echo.
echo   Deploy to admin.mohafezy.com on Hostinger:
echo.
echo   1. In hPanel, go to Domains ^> Subdomains
echo      - Make sure admin.mohafezy.com exists and points to
echo        a directory like /public_html/admin (or its own root)
echo.
echo   2. Open File Manager (or connect via FTP/SFTP)
echo      - Navigate to the subdomain root folder
echo      - Upload ALL contents of packages\mohaffez_web\build\web\
echo        (including hidden .htaccess — check "show hidden files")
echo.
echo   3. Verify the .htaccess file is uploaded:
echo      - Required for SPA deep-link routing
echo      - Without it, refreshing any page other than / returns 404
echo.
echo   4. Add admin.mohafezy.com to Firebase Auth authorized domains:
echo      Firebase Console ^> Authentication ^> Settings ^> Authorized domains
echo.
echo ============================================================
echo.
pause
