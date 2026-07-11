@echo off
setlocal EnableExtensions
title Mohaffez - Stop Dev Firebase Test
color 0C

set "PROJECT_ID=mohaffez-dev"

echo.
echo ============================================================
echo   Mohaffez Dev Test - Disable Dev Billing
echo ============================================================
echo.
echo Safety target: %PROJECT_ID%
echo.
echo This unlinks billing from the dev Firebase project.
echo Billable services in %PROJECT_ID% may stop working after this.
echo Do not use this for production.
echo.

where gcloud >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Google Cloud CLI was not found in PATH.
    pause
    exit /b 1
)

echo Active Google Cloud account:
call gcloud auth list --filter=status:ACTIVE --format="value(account)"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Could not read active Google Cloud account.
    pause
    exit /b 1
)

echo.
echo Current billing state:
call gcloud billing projects describe "%PROJECT_ID%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Could not read billing state for %PROJECT_ID%.
    pause
    exit /b 1
)

echo.
set /p CONFIRM=Type %PROJECT_ID% to unlink billing now: 
if /I not "%CONFIRM%"=="%PROJECT_ID%" (
    echo Cancelled. Billing was not changed.
    pause
    exit /b 0
)

echo.
echo Unlinking billing from %PROJECT_ID%...
call gcloud billing projects unlink "%PROJECT_ID%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to unlink billing from %PROJECT_ID%.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   Billing has been unlinked from %PROJECT_ID%.
echo   Dev billable resources should stop consuming cost.
echo ============================================================
echo.
pause
endlocal
