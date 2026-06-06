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

echo [1/4] Getting dependencies...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)

echo.
echo [2/4] Building release web admin...

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
echo [3/4] Cache-busting entry bundle (content-hashed main.dart.js)...
call node tool\cache_bust.js
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Cache-bust step failed. Is Node.js installed and on PATH?
    pause
    exit /b 1
)

echo.
echo [4/4] Deploying to Firebase Hosting (admin target)...

REM firebase.json lives in the repo root, so deploy from there.
cd /d "%REPO_ROOT%"
call firebase use prod
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Could not select the 'prod' Firebase project.
    echo         Are you logged in? Run: firebase login
    pause
    exit /b 1
)
call firebase deploy --only hosting:admin
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Firebase deploy failed. Check the output above.
    echo         Ensure the Firebase CLI is installed and you are logged in.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   Done! Deployed to Firebase Hosting (admin).
echo.
echo   Live URL  : https://mohaffez-admin.web.app
echo   Custom    : https://admin.mohafezy.com
echo.
echo   Reminder: admin.mohafezy.com must be listed under
echo   Firebase Auth authorized domains:
echo     Firebase Console ^> Authentication ^> Settings ^> Authorized domains
echo ============================================================
echo.
pause
