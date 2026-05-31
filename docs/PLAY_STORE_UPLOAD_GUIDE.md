# Play Store Upload Guide — Mohafezy (محفظي)

## Prerequisites

Before starting, make sure you have:

- A **Google Play Developer account** (one-time $25 registration fee at [play.google.com/console](https://play.google.com/console))
- The **release keystore** file and its credentials (`key.properties`)
- The `.env` file with production secrets (`GOOGLE_MAPS_API_KEY`, etc.)
- Android SDK and Flutter installed and configured
- Access to the Firebase prod project (`mohaffez-ba2ec`)

---

## Step 1 — Build the Release AAB

Run the build script from the repo root on Windows:

```bat
build_release_aab.bat
```

The script validates `.env` and `key.properties` before building. On success it outputs the signed AAB to:

```
packages/mohaffez_mobile/build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

To build manually instead:

```bash
cd packages/mohaffez_mobile
flutter build appbundle \
  --flavor prod \
  --dart-define-from-file=../../.env \
  -t lib/main.dart \
  --release
```

---

## Step 2 — Open Google Play Console

1. Go to [play.google.com/console](https://play.google.com/console)
2. Sign in with the developer account
3. Click **Mohafezy** in the app list (or **Create app** if uploading for the first time)

---

## Step 3 — Create a New Release

1. In the left sidebar go to **Release → Production** (or Internal / Closed testing for pre-release)
2. Click **Create new release**
3. Under **App bundles**, click **Upload** and select the `.aab` file from Step 1
4. Wait for the upload and processing to complete (usually 1–3 minutes)

---

## Step 4 — Fill in Release Details

| Field | What to enter |
|---|---|
| **Release name** | Auto-filled from `versionName` in `build.gradle` (e.g. `1.0.0`) |
| **Release notes** | Arabic release notes describing what's new (see template below) |

### Release notes template (Arabic)

```
ar-EG:
تحديثات هذا الإصدار:
- [اذكر الميزة أو الإصلاح الأول]
- [اذكر الميزة أو الإصلاح الثاني]
- تحسينات في الأداء والاستقرار
```

---

## Step 5 — Review and Roll Out

1. Click **Next** to go to the review screen
2. Fix any **errors** (warnings can usually be ignored)
3. Click **Save** then **Review release**
4. Choose rollout percentage:
   - **100%** for a full release
   - **10–20%** for a staged rollout (recommended for major updates)
5. Click **Start rollout to Production**

Google typically reviews new apps within **3–7 days**. Updates to existing apps are usually reviewed within **a few hours to 1 day**.

---

## Step 6 — Monitor the Release

After publishing:

- Check **Android vitals** in Play Console for crash rates and ANRs
- Monitor **Firebase Crashlytics** at [console.firebase.google.com](https://console.firebase.google.com) → `mohaffez-ba2ec`
- Watch **Release dashboard** for install funnel and rating changes

---

## First Upload Only — Store Listing Setup

If this is the first time uploading, complete the store listing before Step 3:

### App content (left sidebar → Policy → App content)
- Fill out the **privacy policy URL**: `https://mohafezy.com/privacy`
- Complete the **target audience** (select age group)
- Answer the **data safety** questionnaire (the app collects name, email, location)

### Main store listing (left sidebar → Grow → Store presence → Main store listing)

| Field | Value |
|---|---|
| App name | محفظي – Mohafezy |
| Short description | Max 80 chars — brief Arabic tagline |
| Full description | Max 4000 chars — Arabic app description |
| App icon | 512×512 px PNG, no alpha |
| Feature graphic | 1024×500 px JPG/PNG |
| Phone screenshots | At least 2, recommended 4–8 (Arabic UI, portrait) |

### Categorization
- **Category**: Education
- **Tags**: Quran, Islamic education, memorization

---

## Version Code Management

The `versionCode` must be incremented for every upload. It is set in:

```
packages/mohaffez_mobile/android/app/build.gradle
```

```gradle
android {
    defaultConfig {
        versionCode 5          // increment this each upload
        versionName "1.2.0"    // update for user-facing version
    }
}
```

> Never reuse a `versionCode` — Play Store rejects bundles with a code already used.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Upload failed — version code already exists" | Increment `versionCode` in `build.gradle` and rebuild |
| "Unsigned bundle" | Verify `key.properties` paths and passwords are correct |
| "Missing permissions declaration" | Add any new permissions to the data safety form in Play Console |
| App rejected for policy violation | Read the rejection email carefully; common causes are missing privacy policy or incorrect content rating |
| Build fails with `dart-define` errors | Ensure `.env` file exists in repo root and contains all required keys |
