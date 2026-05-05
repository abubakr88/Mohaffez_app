# Publish DEV -> PROD
# Deploys code artifacts (rules, indexes, functions, hosting) from your local
# repo to PROD. Firestore DATA is NOT copied dev->prod (would overwrite real
# user data). This script publishes:
#   - Firestore security rules + indexes
#   - Storage rules
#   - Cloud Functions
#   - Hosting (web app + marketing site)
#
# Run from repo root:  pwsh ./scripts/publish_dev_to_prod.ps1

$ErrorActionPreference = "Stop"

$PROD = "mohaffez-ba2ec"
$DEV  = "mohaffez-dev"

Write-Host "=== Publish DEV -> PROD ===" -ForegroundColor Cyan
Write-Host "This will deploy local rules/indexes/functions/hosting to $PROD."
Write-Host "It will NOT copy Firestore data (prod data is preserved)." -ForegroundColor Yellow
$confirm = Read-Host "`nType 'PUBLISH' to continue"
if ($confirm -ne "PUBLISH") {
    Write-Host "Aborted." -ForegroundColor Red
    exit 1
}

# 1. Sanity: build functions first so we fail fast on TS errors
Write-Host "`n[1/4] Building Cloud Functions..." -ForegroundColor Yellow
Push-Location functions
npm install
npm run build
Pop-Location

# 2. (Optional) Run flutter analyze to catch issues before publishing web/mobile
Write-Host "`n[2/4] Analyzing Flutter code..." -ForegroundColor Yellow
flutter analyze

# 3. Build web release for hosting deploy
Write-Host "`n[3/4] Building Flutter web release..." -ForegroundColor Yellow
Push-Location packages/mohaffez_web
flutter build web --release
Pop-Location

# 4. Deploy everything to PROD
Write-Host "`n[4/4] Deploying to $PROD..." -ForegroundColor Yellow
firebase use prod
firebase deploy --only firestore:rules,firestore:indexes,storage,functions,hosting --project=$PROD

Write-Host "`nDone. Published to $PROD." -ForegroundColor Green
Write-Host "Mobile app releases (APK/AAB) must be built and uploaded to Play Store separately:" -ForegroundColor DarkGray
Write-Host "  ./build_release_aab.bat" -ForegroundColor DarkGray
