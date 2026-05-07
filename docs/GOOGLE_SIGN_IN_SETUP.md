x# Google Sign-In Setup Guide

This document walks through every Firebase / Google Cloud Console step needed to make Google Sign-In work for the Mohaffez apps across all platforms and both environments.

---

## 1. The big picture

We have **two Firebase projects** and **three Flutter apps**:

| Firebase project | Project ID       | Used by                                                 |
|---|---|---|
| Dev              | `mohaffez-dev`   | Local development, internal testing                     |
| Prod             | `mohaffez-ba2ec` | Play Store / App Store / production web                 |

| Flutter app                  | Platforms                | Bundle / package ID (dev → prod)                  |
|---|---|---|
| `packages/mohaffez_mobile`   | Android, iOS, (web for testing only) | `app.mohafezy.dev` → `app.mohafezy`         |
| `packages/mohaffez_web`      | Web (admin / teacher console) | n/a (web origin only)                          |

For each app on each platform on each project you must register the right credentials:

- **Android** → SHA-1/SHA-256 fingerprints
- **iOS** → Bundle ID + reversed client ID URL scheme
- **Web** → Authorized JavaScript origins + redirect URIs

You repeat the same procedure twice: **once for `mohaffez-dev`, once for `mohaffez-ba2ec`**.

---

## 2. Prerequisites

- Owner / Editor access to both Firebase projects
- Owner / Editor access to both linked Google Cloud projects (auto-created with each Firebase project)
- The release keystore at the path declared in `packages/mohaffez_mobile/android/key.properties`
- Play Console access (only needed for the prod release SHA — step 4.4)
- Apple Developer account (only needed for iOS — step 5)

---

## 3. Get your Android SHA fingerprints

You need fingerprints from **three** different signing keys:

1. **Debug keystore** — used by `flutter run` on every developer machine. Each developer has their own.
2. **Release keystore** — your `upload-keystore.jks` referenced by `key.properties`. Used for sideloaded APKs and AAB upload.
3. **Play App Signing key** — Google re-signs your AAB on the Play Store with this key. Only retrievable from Play Console.

### 3.1 Debug + release SHAs (from your machine)

```bash
cd packages/mohaffez_mobile/android
./gradlew signingReport
```

In the output, find:

```
Variant: debug
Config: debug
SHA1: AA:BB:CC:...
SHA-256: ...

Variant: release
Config: release
SHA1: 11:22:33:...
SHA-256: ...
```

Copy both `SHA1` values. (You may also copy `SHA-256` — Firebase accepts both.)

> **Each developer has a different debug SHA.** If a teammate gets `ApiException: 10`, they must register *their own* debug SHA in `mohaffez-dev`.

### 3.2 Play App Signing SHA (from Play Console)

Only required once you've uploaded the app to the Play Console (internal testing is fine).

1. Go to https://play.google.com/console → your app
2. **Setup → App integrity → App signing**
3. Under **App signing key certificate**, copy the `SHA-1 certificate fingerprint`

This SHA is what real Play Store users will hit, so it **must** be in `mohaffez-ba2ec`.

---

## 4. Configure the DEV Firebase project (`mohaffez-dev`)

### 4.1 Enable Google as a sign-in provider

1. Firebase Console → https://console.firebase.google.com/project/mohaffez-dev
2. **Build → Authentication → Sign-in method**
3. Click **Google** → toggle **Enable**
4. Set **Project support email** → Save

### 4.2 Register Android SHA fingerprints

1. https://console.firebase.google.com/project/mohaffez-dev/settings/general
2. Scroll to **Your apps** → find the Android app `app.mohafezy.dev`
3. Click **Add fingerprint**
4. Paste the **debug SHA-1** from step 3.1 → Save
5. Click **Add fingerprint** again → paste **release SHA-1** → Save
6. *(Optional)* Add each teammate's debug SHA-1 the same way

### 4.3 Re-download `google-services.json`

After adding fingerprints, the OAuth client list inside `google-services.json` changes. You **must** redownload:

1. Same Firebase settings page → click the download icon next to the Android app
2. Replace the file at:
   ```
   packages/mohaffez_mobile/android/app/google-services.json
   ```
   *(Or the dev-flavor-specific path if your project uses one — check `android/app/src/dev/google-services.json`.)*
3. Commit the new file (it is committed; values are public client config)

### 4.4 Add web origins (for Flutter web testing of the mobile app)

The Flutter dev server uses a random `localhost` port. To make Google Sign-In work in Chrome:

1. Go to Google Cloud Console → https://console.cloud.google.com/apis/credentials?project=mohaffez-dev
2. Find the OAuth 2.0 Client ID of type **Web client (auto created by Google Service)** — it should match the `client_id` in `packages/mohaffez_mobile/web/index.html`
3. Click Edit:
   - **Authorized JavaScript origins** → add:
     - `http://localhost`
     - `https://mohaffez-dev.web.app` *(if you host dev on Firebase Hosting)*
     - `https://mohaffez-dev.firebaseapp.com`
   - **Authorized redirect URIs** → add:
     - `http://localhost`
     - the same hosted URLs above
4. Save (propagation takes ~5 minutes)

---

## 5. Configure the PROD Firebase project (`mohaffez-ba2ec`)

Repeat **all of section 4** against `mohaffez-ba2ec`, with these differences:

### 5.1 Android fingerprints to register

In `mohaffez-ba2ec` settings → app `app.mohafezy`, add:
- Your **release SHA-1** (for sideloaded release APKs)
- The **Play App Signing SHA-1** from step 3.2 — **critical**, otherwise Play Store users get `ApiException: 10`
- *(Optional but recommended)* the SHA-256 versions of both

You generally do **not** add debug SHAs to prod unless you're testing prod Firebase from a dev build — keep prod clean.

### 5.2 Re-download prod `google-services.json`

Replace `packages/mohaffez_mobile/android/app/google-services.json` with the prod one — but only if your project uses a single file for both flavors. Most flavored setups have:

```
android/app/src/dev/google-services.json    ← from mohaffez-dev
android/app/src/prod/google-services.json   ← from mohaffez-ba2ec
```

Check your `android/app/build.gradle` for the flavor config and place each file in the right folder.

### 5.3 Web origins for prod

In `https://console.cloud.google.com/apis/credentials?project=mohaffez-ba2ec`, add to the prod web OAuth client:

- `https://mohafezy.com` *(or whatever the production web origin is)*
- `https://mohaffez-ba2ec.web.app`
- `https://mohaffez-ba2ec.firebaseapp.com`

For the admin / teacher console (`packages/mohaffez_web`), add its hosted origin too — e.g. `https://admin.mohafezy.com`.

---

## 6. iOS setup (both projects)

For each Firebase project, in `Settings → Your apps → iOS app`:

1. Confirm Bundle ID matches:
   - dev → `app.mohafezy.dev`
   - prod → `app.mohafezy`
2. Download `GoogleService-Info.plist`
3. Place the file at:
   - dev → `packages/mohaffez_mobile/ios/Runner/Firebase/dev/GoogleService-Info.plist`
   - prod → `packages/mohaffez_mobile/ios/Runner/Firebase/prod/GoogleService-Info.plist`

   *(Adjust paths to match your existing folder structure — search `*.plist` under `ios/` to confirm.)*

4. Open `ios/Runner.xcworkspace` in Xcode → Runner target → **Info** → **URL Types** → ensure there is an entry whose URL Scheme equals the **`REVERSED_CLIENT_ID`** value from the plist (it looks like `com.googleusercontent.apps.945631030984-...`). Each flavor needs its own reversed client ID.

5. In Firebase Console → Authentication → Sign-in method → Google → ensure it is **enabled** for the project (you already did this in step 4.1 / 5.1).

> No SHA fingerprints needed for iOS — Apple handles app identity through the bundle ID and provisioning profiles.

---

## 7. Web setup — `packages/mohaffez_web` (admin console)

The admin web app currently has **no Google Sign-In button**. If you want to add it:

1. Add `google_sign_in: ^6.2.1` to `packages/mohaffez_web/pubspec.yaml`
2. Add the meta tag to `packages/mohaffez_web/web/index.html` inside `<head>`:
   ```html
   <meta name="google-signin-client_id"
         content="<WEB_CLIENT_ID_FROM_GOOGLE_CLOUD_CONSOLE>.apps.googleusercontent.com">
   ```
   Use the **dev** client ID for the dev build of the web app, and the **prod** client ID for the prod build. (Easiest: have two `index.html` files or inject via build step.)
3. Authorize the admin's web origin in Google Cloud Console (steps 4.4 / 5.3) — origins like `https://admin.mohafezy.com`, `http://localhost`, etc.

---

## 8. Verification checklist

After every change, run:

```bash
flutter clean
flutter run --flavor dev --dart-define-from-file=../../.env -t lib/main_dev.dart
```

Then tap **"تسجيل الدخول بحساب Google"** and confirm:

- [ ] Native Google account picker opens (Android dev build)
- [ ] After picking an account, the app proceeds to the role-selection screen for **new** users, or to the home shell for **existing** users
- [ ] No `PlatformException(sign_in_failed, ApiException: 10, ...)`
- [ ] No `popup_closed` / `origin_mismatch` on web

Repeat for:
- [ ] Android **prod** flavor (release APK sideload)
- [ ] iOS **dev** flavor (simulator + real device)
- [ ] iOS **prod** flavor (TestFlight)
- [ ] Web (mobile app on Chrome, dev origin)
- [ ] Play Store internal testing track (catches the Play App Signing SHA issue)

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ApiException: 10` (DEVELOPER_ERROR) | SHA-1 not registered for that project + bundle | Add SHA via section 4.2 / 5.1 + redownload `google-services.json` + `flutter clean` |
| `ApiException: 12500` | Generic GMS error, often outdated `google-services.json` | Redownload the JSON; ensure Google provider is **enabled** in Firebase Auth |
| `popup_closed` (web) | User closed the popup, *or* origin not authorized | Verify origin in Google Cloud Console (section 4.4 / 5.3) |
| `origin_mismatch` (web) | The `localhost:<random>` origin isn't whitelisted | Add bare `http://localhost` (no port) to Authorized JavaScript origins |
| `Sign in with Google temporarily disabled for this app` | Google provider toggle off in Firebase Auth | Section 4.1 / 5.1 — enable + set support email |
| Sign-in works in dev but fails in production Play Store install | Missing **Play App Signing SHA-1** in prod project | Add it (section 3.2 + 5.1) — wait ~5 min for propagation |

---

## 10. Quick reference — what goes where

```
mohaffez-dev (Firebase project)
├── Android app: app.mohafezy.dev
│   ├── SHA-1: <each developer's debug SHA>
│   └── SHA-1: <release keystore SHA>          ← optional, only if you sideload dev release builds
├── iOS app: app.mohafezy.dev
│   └── GoogleService-Info.plist → ios/Runner/Firebase/dev/
└── Web client (auto)
    └── Authorized origins:
        ├── http://localhost
        ├── https://mohaffez-dev.web.app
        └── https://mohaffez-dev.firebaseapp.com

mohaffez-ba2ec (Firebase project)
├── Android app: app.mohafezy
│   ├── SHA-1: <release keystore SHA>          ← sideload release APKs
│   └── SHA-1: <Play App Signing SHA>          ← REQUIRED for Play Store users
├── iOS app: app.mohafezy
│   └── GoogleService-Info.plist → ios/Runner/Firebase/prod/
└── Web client (auto)
    └── Authorized origins:
        ├── https://mohafezy.com
        ├── https://admin.mohafezy.com
        ├── https://mohaffez-ba2ec.web.app
        └── https://mohaffez-ba2ec.firebaseapp.com
```
