@echo off
REM Build script for Flutter web deployment (Windows)
REM Usage: scripts\build_web.bat [SENTRY_DSN]

echo Building Mohaffez Web for production...

REM Clean previous build
call flutter clean

REM Get dependencies
call flutter pub get

REM Build for production
if "%~1"=="" (
    call flutter build web --release --pwa-strategy offline-first
) else (
    call flutter build web --release --pwa-strategy offline-first --dart-define=SENTRY_DSN="%~1"
)

if %ERRORLEVEL% neq 0 (
    echo Build failed. Check the output above.
    pause
    exit /b 1
)

echo.
echo Build complete!
echo Output: packages\mohaffez_web\build\web
echo.
pause
