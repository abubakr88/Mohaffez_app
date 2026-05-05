# Mohaffez Web

Flutter web application for Al-Mohaffez (المحفظ) - Quran tutoring platform.

## Quick Start

```bash
# Run in Chrome
flutter run -d chrome

# Run in release mode (recommended for testing)
flutter run -d chrome --release
```

## Build for Production

### Using Build Script

```bash
# Bash (Linux/Mac)
./scripts/build_web.sh

# Or with Sentry DSN
./scripts/build_web.sh "your-sentry-dsn"

# Windows
scripts\build_web.bat
```

### Manual Build

```bash
flutter build web --release --web-renderer canvaskit --pwa-strategy offline-first
```

## Deploy

### Manual Deploy (Production)

```bash
firebase deploy --only hosting:app
```

### Deploy Marketing Site

```bash
firebase deploy --only hosting:marketing
```

### Deploy Both

```bash
firebase deploy --only hosting:app,hosting:marketing
```

### Preview Channel (Testing)

```bash
firebase hosting:channel:deploy preview --only hosting:app
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SENTRY_DSN` | Sentry error tracking DSN | Optional |
| `FIREBASE_TOKEN` | Firebase CI token (GitHub Actions) | For CI only |

## Custom Domain Setup

1. Add A records in DNS pointing to Firebase Hosting IPs:
   - `151.101.1.195`
   - `151.101.65.195`
2. Connect domain in Firebase Console → Hosting → Connect Domain
3. Wait for SSL certificate provisioning (can take up to 24 hours)

## Project Structure

```
lib/
├── main.dart              # Entry point with Firebase init
├── app.dart               # Main app widget
├── firebase_options.dart  # Firebase config (auto-generated)
├── services/
│   ├── web_analytics_observer.dart  # Firebase Analytics navigator observer
│   └── error_logger.dart            # Centralized error logging
└── ...

web/
├── index.html             # HTML entry with splash screen
├── manifest.json          # PWA manifest
├── firebase-messaging-sw.js  # FCM service worker
└── icons/                 # App icons
```

## TODO Before First Deploy

1. Run `flutterfire configure` to generate `lib/firebase_options.dart`:
   ```bash
   flutterfire configure --project=mohaffez-ba2ec --platforms=web --out=lib/firebase_options.dart
   ```
2. Update `web/firebase-messaging-sw.js` with actual Firebase config
3. Add proper icons to `web/icons/`
4. Set up Sentry project and add DSN to build command
5. Configure GitHub secrets (`FIREBASE_SERVICE_ACCOUNT`, `SENTRY_DSN`)
