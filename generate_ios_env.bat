@echo off
REM Generates ios/Runner/EnvConfig.swift from repo root .env
setlocal enabledelayedexpansion

set REPO_ROOT=%~dp0
set ENV_FILE=%REPO_ROOT%.env
set OUTPUT=%REPO_ROOT%packages\mohaffez_mobile\ios\Runner\EnvConfig.swift

if not exist "%ENV_FILE%" (
    echo [ERROR] .env not found at repo root.
    exit /b 1
)

for /f "tokens=2 delims==" %%a in ('findstr /B "GOOGLE_MAPS_API_KEY=" "%ENV_FILE%"') do (
    set API_KEY=%%a
)

if "!API_KEY!"=="" (
    echo [ERROR] GOOGLE_MAPS_API_KEY not found in .env
    exit /b 1
)

echo // Auto-generated from repo root .env — run generate_ios_env.bat to regenerate > "%OUTPUT%"
echo import Foundation >> "%OUTPUT%"
echo. >> "%OUTPUT%"
echo enum EnvConfig { >> "%OUTPUT%"
echo     static let googleMapsApiKey = "!API_KEY!" >> "%OUTPUT%"
echo } >> "%OUTPUT%"

echo [OK] Generated ios/Runner/EnvConfig.swift
