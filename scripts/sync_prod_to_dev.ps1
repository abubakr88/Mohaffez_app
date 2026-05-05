# Sync PROD -> DEV
# Copies Firestore data, security rules, indexes, storage rules, and Cloud Functions
# from mohaffez-ba2ec (prod) to mohaffez-dev (dev).
#
# Auth users are NOT copied automatically (Firebase doesn't expose passwords).
# Use the auth-export/import section at the bottom if you need user accounts.
#
# Run from repo root:  pwsh ./scripts/sync_prod_to_dev.ps1

$ErrorActionPreference = "Stop"

$PROD       = "mohaffez-ba2ec"
$DEV        = "mohaffez-dev"
$DEV_NUMBER = "389775667878"
$PROD_BUCKET = "$PROD.firebasestorage.app"
$IMPORT_BUCKET = "mohaffez-dev-import-tmp"
$REGION = "us-central1"
$STAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$EXPORT_PATH = "exports/sync-$STAMP"

Write-Host "=== Sync PROD -> DEV ($STAMP) ===" -ForegroundColor Cyan

# 1. Export Firestore from PROD
Write-Host "`n[1/5] Exporting Firestore from $PROD..." -ForegroundColor Yellow
gcloud firestore export "gs://$PROD_BUCKET/$EXPORT_PATH" --project=$PROD

# 2. Ensure regional import bucket exists in DEV
Write-Host "`n[2/5] Preparing import bucket gs://$IMPORT_BUCKET ($REGION)..." -ForegroundColor Yellow
$bucketExists = gcloud storage buckets describe "gs://$IMPORT_BUCKET" --project=$DEV 2>$null
if (-not $bucketExists) {
    gcloud storage buckets create "gs://$IMPORT_BUCKET" --location=$REGION --project=$DEV
}

# 3. Copy export PROD bucket -> DEV regional bucket
Write-Host "`n[3/5] Copying export to DEV bucket..." -ForegroundColor Yellow
gcloud storage cp -r "gs://$PROD_BUCKET/$EXPORT_PATH" "gs://$IMPORT_BUCKET/$EXPORT_PATH"

# 4. Import into DEV Firestore
Write-Host "`n[4/5] Importing into $DEV Firestore..." -ForegroundColor Yellow
gcloud firestore import "gs://$IMPORT_BUCKET/$EXPORT_PATH" --project=$DEV

# 5. Deploy rules / indexes / functions to DEV
Write-Host "`n[5/5] Deploying rules, indexes, and functions to $DEV..." -ForegroundColor Yellow
firebase use dev
firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project=$DEV
firebase use prod

Write-Host "`nDone. Export kept at: gs://$IMPORT_BUCKET/$EXPORT_PATH" -ForegroundColor Green
Write-Host "To delete it later: gcloud storage rm -r gs://$IMPORT_BUCKET/$EXPORT_PATH" -ForegroundColor DarkGray

# --- Optional: copy Auth users (uncomment to enable) ---
# Note: password hashes export only; you must re-import with matching hash params.
# firebase auth:export auth_prod.json --project=$PROD
# firebase auth:import auth_prod.json --project=$DEV --hash-algo=SCRYPT --hash-key=... --salt-separator=... --rounds=... --mem-cost=...
