@echo off
title Mohaffez - Build Release AAB (Play Store)
color 0A

echo.
echo ============================================================
echo   Mohaffez App - Release App Bundle (Play Store)
echo ============================================================
echo.

REM Check .env exists
if not exist ".env" (
    echo [ERROR] .env file not found in project root.
    echo         Create it from the template and add your API keys.
    pause
    exit /b 1
)

REM Check key.properties exists
if not exist "android\key.properties" (
    echo [ERROR] android\key.properties not found.
    echo         Copy android\key.properties.template to android\key.properties
    echo         and fill in your keystore details.
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
echo [2/3] Building release App Bundle...
call flutter build appbundle --dart-define-from-file=.env --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed. Check the output above.
    pause
    exit /b 1
)

echo.
echo [3/3] Done!
echo.
echo ============================================================
echo   Output: build\app\outputs\bundle\release\app-release.aab
echo   Upload this file to Google Play Console.
echo ============================================================
echo.
pause
