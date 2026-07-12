@echo off
setlocal EnableExtensions
title Mohaffez - Start Dev Firebase Test
color 0B

set "PROJECT_ID=mohaffez-dev"
set "FIREBASE_ALIAS=dev"
set "REPO_ROOT=%~dp0"

cd /d "%REPO_ROOT%"

echo.
echo ============================================================
echo   Mohaffez Dev Test - Prepare Firebase Dev Project
echo ============================================================
echo.
echo Safety target: %PROJECT_ID%
echo.

echo Checking dev web App Check configuration...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$envFile = '.env'; if (-not (Test-Path $envFile)) { Write-Host '[WARN] .env file was not found. Web App Check key cannot be checked.'; exit 0 }; $line = Get-Content $envFile | Where-Object { $_ -match '^\s*APP_CHECK_RECAPTCHA_KEY\s*=' } | Select-Object -First 1; if (-not $line -or $line -match '^\s*APP_CHECK_RECAPTCHA_KEY\s*=\s*$') { Write-Host '[WARN] APP_CHECK_RECAPTCHA_KEY is missing/empty in .env.'; Write-Host '       If Cloud Functions App Check is enforced in mohaffez-dev, web callable calls will fail before function code runs.'; Write-Host '       Fix one of these before testing web:'; Write-Host '       1. Add a dev reCAPTCHA/App Check site key to APP_CHECK_RECAPTCHA_KEY, or'; Write-Host '       2. Set Cloud Functions App Check enforcement to Unenforced in Firebase Console for mohaffez-dev only.' } else { Write-Host '[OK] APP_CHECK_RECAPTCHA_KEY exists for web App Check.' }"
echo.

where firebase >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Firebase CLI was not found in PATH.
    echo         Install it or open a terminal where firebase is available.
    pause
    exit /b 1
)

where gcloud >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Google Cloud CLI was not found in PATH.
    echo         Install it or open a terminal where gcloud is available.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = (Get-Content '.firebaserc' -Raw | ConvertFrom-Json).projects.dev; if ($p -ne '%PROJECT_ID%') { Write-Host '[ERROR] .firebaserc dev alias points to' $p 'instead of %PROJECT_ID%.'; exit 1 }"
if %ERRORLEVEL% neq 0 (
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
echo Firebase CLI account:
call firebase login:list

echo.
echo [1/6] Selecting Firebase alias: %FIREBASE_ALIAS%
call firebase use "%FIREBASE_ALIAS%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Could not switch Firebase alias to %FIREBASE_ALIAS%.
    pause
    exit /b 1
)

echo.
echo [2/6] Linking billing if MOHAFFEZ_DEV_BILLING_ACCOUNT is set...
if "%MOHAFFEZ_DEV_BILLING_ACCOUNT%"=="" (
    echo [WARN] MOHAFFEZ_DEV_BILLING_ACCOUNT is not set. Skipping billing link.
    echo        If billing is currently disabled, functions deploy may fail.
    echo        Current session example:
    echo        set MOHAFFEZ_DEV_BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX
) else (
    call gcloud billing projects link "%PROJECT_ID%" --billing-account="%MOHAFFEZ_DEV_BILLING_ACCOUNT%"
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to link billing for %PROJECT_ID%.
        pause
        exit /b 1
    )
)

echo.
echo [3/6] Ensuring required Google APIs are enabled on %PROJECT_ID%...
call gcloud services enable cloudfunctions.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com cloudscheduler.googleapis.com secretmanager.googleapis.com firestore.googleapis.com firebasestorage.googleapis.com --project="%PROJECT_ID%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to enable required Google APIs.
    pause
    exit /b 1
)

echo.
echo.
echo [4/6] Ensuring required function secrets exist on %PROJECT_ID%...
echo        Existing accessible latest versions are kept.
echo        A new version is added only when missing/broken or when the matching PAYMOB_* env var is set.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$project = '%PROJECT_ID%'; $defaults = @{ PAYMOB_HMAC_SECRET='dev-hmac-secret-not-for-payments'; PAYMOB_SECRET_KEY='dev-secret-key-not-for-payments'; PAYMOB_PUBLIC_KEY='dev-public-key-not-for-payments'; PAYMOB_CARD_INTEGRATION_ID='0'; PAYMOB_API_KEY='dev-api-key-not-for-payments' }; foreach ($name in $defaults.Keys) { $envValue = [Environment]::GetEnvironmentVariable($name); $hasEnvValue = -not [string]::IsNullOrWhiteSpace($envValue); if (-not $hasEnvValue) { & gcloud secrets versions access latest --secret=$name --project=$project 1>$null 2>$null; if ($LASTEXITCODE -eq 0) { Write-Host '[OK] Latest secret version accessible:' $name; continue } }; if ($hasEnvValue) { $value = $envValue; Write-Host '[OK] Adding secret version from environment variable:' $name } else { $value = $defaults[$name]; Write-Host '[WARN] Adding dummy dev secret version:' $name }; $secretExists = & gcloud secrets describe $name --project=$project --format='value(name)' 2>$null; if ($LASTEXITCODE -ne 0 -or -not $secretExists) { & gcloud secrets create $name --project=$project --replication-policy='automatic' | Out-Host; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }; $tmp = New-TemporaryFile; Set-Content -LiteralPath $tmp -Value $value -NoNewline; & gcloud secrets versions add $name --project=$project --data-file=$tmp | Out-Host; Remove-Item -LiteralPath $tmp -Force; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; & gcloud secrets versions access latest --secret=$name --project=$project 1>$null 2>$null; if ($LASTEXITCODE -ne 0) { Write-Host '[ERROR] Could not access latest version for' $name; exit $LASTEXITCODE } }"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to prepare required function secrets.
    pause
    exit /b 1
)

echo.
echo [5/6] Deploying functions, Firestore rules, and Storage rules to %PROJECT_ID%...
call firebase deploy --project "%PROJECT_ID%" --only functions,firestore:rules,storage
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Firebase deploy failed.
    echo         Check missing Firebase secrets, permissions, or billing status.
    pause
    exit /b 1
)

echo.
echo Checking client-callable function invoker IAM on %PROJECT_ID%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$project = '%PROJECT_ID%'; $region = 'us-central1'; $names = @('mohaffezConfirmDirectPayment'); foreach ($name in $names) { $policyJson = & gcloud functions get-iam-policy $name --project=$project --region=$region --format=json 2>$null; if ($LASTEXITCODE -ne 0) { Write-Host '[WARN] Could not read IAM policy for' $name; continue }; $policy = $policyJson | ConvertFrom-Json; $hasInvoker = $false; if ($policy.bindings) { foreach ($binding in $policy.bindings) { if ($binding.role -eq 'roles/cloudfunctions.invoker' -and $binding.members -contains 'allUsers') { $hasInvoker = $true } } }; if ($hasInvoker) { Write-Host '[OK] Client invoker IAM exists:' $name } else { Write-Host '[WARN] Missing allUsers invoker on' $name '- adding dev binding.'; & gcloud functions add-iam-policy-binding $name --project=$project --region=$region --member='allUsers' --role='roles/cloudfunctions.invoker' | Out-Host; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } }"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to verify callable invoker IAM.
    pause
    exit /b 1
)

echo.
echo [6/6] Deploying Firestore indexes to %PROJECT_ID%...
call firebase deploy --project "%PROJECT_ID%" --only firestore:indexes
if %ERRORLEVEL% neq 0 (
    echo [WARN] Firestore indexes deploy failed once. Waiting 30 seconds, then retrying...
    timeout /T 30 /NOBREAK >nul
    call firebase deploy --project "%PROJECT_ID%" --only firestore:indexes
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Firestore indexes deploy failed after retry.
        echo         Firestore database exists and billing may be enabled, but the indexes API call failed.
        echo         Try this diagnostic command:
        echo         firebase deploy --project "%PROJECT_ID%" --only firestore:indexes --debug
        pause
        exit /b 1
    )
)

echo.
echo ============================================================
echo   Dev backend is ready.
echo.
echo   Run the app against dev with:
echo     cd packages\mohaffez_mobile
echo     flutter run -d chrome --flavor dev -t lib/main_dev.dart --dart-define-from-file ../../.env
echo.
echo   After testing, run:
echo     dev_test_stop.bat
echo ============================================================
echo.
pause
endlocal
