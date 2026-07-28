# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Is

**Mohafezy** (محفظي) — a Flutter app connecting students with Quran teachers (mohaffezeen) for in-person, mosque, or online memorization sessions. The app has three roles: **student**, **mohaffez** (teacher), and **admin**. The UI is Arabic-only, RTL throughout.

---

## Repo Layout (Monorepo)

This is a Melos-managed monorepo. Code lives under `packages/`:

| Package | Purpose |
|---|---|
| `packages/mohaffez_core/` | Shared models, repositories, providers, services, utilities |
| `packages/mohaffez_mobile/` | Flutter Android/iOS app (entry: `lib/main.dart` prod, `lib/main_dev.dart` dev) |
| `packages/mohaffez_web/` | Flutter web app (admin + teacher dashboards) |
| `functions/` | Firebase Cloud Functions (TypeScript) |
| `marketing_site/` | Static marketing site (deployed to mohafezy.com) |

When asked about "the app," default to `packages/mohaffez_mobile/` unless the request is clearly about web.

## Flavors (mobile)

| Flavor | Firebase project | App ID | Entry point |
|---|---|---|---|
| `dev` | `mohaffez-dev` | `app.mohafezy.dev` | `lib/main_dev.dart` |
| `prod` | `mohaffez-ba2ec` | `app.mohafezy` | `lib/main.dart` |

Both flavors share `bootstrap.dart` (init logic) and `app.dart` (`MyApp` widget). Each entry point passes its own `FirebaseOptions` to `bootstrap()`. Dev and prod can coexist on the same device.

VS Code launch configs in `.vscode/launch.json`: "mohaffez_mobile (dev)" and "mohaffez_mobile (prod)".

## Commands

### Workspace bootstrap

```bash
dart pub global activate melos          # First time only
melos bootstrap                          # Resolves deps for all packages
```

### Flutter

```bash
# Run from a package directory (e.g. packages/mohaffez_mobile)
flutter pub get
flutter analyze
flutter test
flutter test test/path/to_test.dart

# Mobile dev flavor (or use VS Code F5 → "mohaffez_mobile (dev)")
cd packages/mohaffez_mobile
flutter run --flavor dev --dart-define-from-file=../../.env -t lib/main_dev.dart

# Mobile release builds (run from repo root via batch scripts on Windows)
./build_release_apk.bat                  # APK with prod flavor
./build_release_aab.bat                  # AAB for Play Store

# Web
cd packages/mohaffez_web
flutter run -d chrome
flutter build web --release
```

The batch scripts validate `.env` and `packages/mohaffez_mobile/android/key.properties` before building, and use the prod flavor.

### Code Generation (Freezed / JSON / Riverpod)

```bash
dart run build_runner build --delete-conflicting-outputs   # One-time generation
dart run build_runner watch --delete-conflicting-outputs   # Watch mode
```

Models that use `@freezed` or `@JsonSerializable` have generated `*.freezed.dart` and `*.g.dart` siblings — never edit those files manually.

### Firebase

Releases are normally driven by GitHub Actions on branch push (see [RELEASE.md](RELEASE.md)). Use these only for manual fixes / emergencies:

```bash
firebase use dev                         # or `firebase use prod`
firebase deploy --only firestore:rules   # Deploy Firestore security rules
firebase deploy --only functions         # Deploy Cloud Functions
firebase deploy                          # Deploy everything (rules, indexes, storage, functions, hosting)
```

Project aliases configured in `.firebaserc`: `dev` → `mohaffez-dev`, `prod` → `mohaffez-ba2ec`.

### Cloud Functions (TypeScript, in `functions/`)

```bash
cd functions && npm install              # Install function dependencies
npm run build                            # Compile TypeScript
npm run serve                            # Local emulator
```

---

## Required Local Files (Never Committed)

| File | Purpose |
|---|---|
| `.env` | `GOOGLE_MAPS_API_KEY` and other dart-define secrets (in repo root) |
| `packages/mohaffez_mobile/android/key.properties` | Release signing config (keystore path + passwords) |
| `packages/mohaffez_mobile/lib/firebase_options.dart` | Prod Firebase config (FlutterFire CLI generated) |
| `packages/mohaffez_mobile/lib/firebase_options_dev.dart` | Dev Firebase config (committed — values are public client keys) |
| `functions/serviceAccountKey.json` | Firebase Admin SDK key for functions |

---

## Architecture

### Flutter Mobile App (`packages/mohaffez_mobile/lib/`)

```
packages/mohaffez_mobile/lib/
  main.dart            # Prod entry point — calls bootstrap(prodFirebaseOptions)
  main_dev.dart        # Dev entry point — calls bootstrap(devFirebaseOptions)
  bootstrap.dart       # Shared init: Firebase, App Check, Firestore, NotificationService, runApp
  app.dart             # MyApp widget, lifecycle observer, error fallback UI
  firebase_options.dart      # Prod Firebase config (gitignored)
  firebase_options_dev.dart  # Dev Firebase config (committed)
  config/              # GoRouter setup, GuardManager, per-role route guards
  screens/             # One file per screen
  services/            # Stateless helper services (cache, notifications, images…)
  shared/
    theme/             # AppThemeConstants, AppThemeData (theme source of truth)
    widgets/           # Reusable widgets used across screens
    constants/         # App-wide string constants
  utils/               # Pure utility functions

packages/mohaffez_core/lib/
  src/
    models/            # Freezed data models (+ generated *.freezed.dart / *.g.dart)
    providers/         # Riverpod providers (state + actions)
    repositories/      # Firestore data access layer
    services/          # Cross-platform services
    constants/         # Shared constants
    utils/             # Pure utility functions
```

Models and Riverpod providers live in `mohaffez_core` and are imported by both `mohaffez_mobile` and `mohaffez_web`. Platform-specific code (e.g. mobile photo upload, mobile NotificationService) stays in `mohaffez_mobile`.

**State management:** Riverpod only (`flutter_riverpod`). No `setState` for shared state — use providers. Each screen watches providers via `ref.watch`; mutations go through `ref.read(...notifier)`.

**Routing:** GoRouter with a `ShellRoute` wrapping all authenticated routes inside `HomeShell` (bottom nav). Guards run in priority order via `GuardManager` → `TimeoutGuard` → `AuthGuard` → `SetupGuard` → `RoleGuard`. Always use `context.push` / `context.go` — never `Navigator.push`, which bypasses the GoRouter stack.

**Data flow:** Screen → Provider → Repository → Firestore. Providers hold `AsyncValue` state; repositories are thin Firestore wrappers. Pagination uses `studentSessionsFirstPageProvider(uid)` / `sessionActionsProvider` patterns in `session_provider_paginated.dart`.

**User roles:** `role` field on `users/{uid}`: `'student'`, `'mohaffez'`, `'admin'`. Role is cached in `CacheService` (SharedPreferences). Guards read role from `currentUserRoleProvider`.

### Firestore Collections

| Collection | Purpose |
|---|---|
| `users` | All user profiles (students, mohaffezeen, admins) |
| `hafizSessions` | Booked sessions; `status`: `pending → accepted → completed` |
| `sessionRequests` | Pre-acceptance booking requests |
| `subscriptions` | Bundle subscription plans per student |
| `payments` | Payment records (direct, bundle, subscription) |
| `userSuspensions` | Suspension docs — existence = suspended |
| `systemConfig` | App-wide flags (maintenance mode, app version) |
| `promoCodes` | Promo code definitions |

Key Firestore field names (session rating pipeline — must match security rules):
- Student submits feedback → writes `teacherRating` (int), `teacherRatingScale` (5), `technicalIssueSource`, optional `teacherRatingReason`, and `reviewNotes` to `hafizSessions`
- Cloud Function `onTeacherRated` counts only explicit five-point V2 ratings and updates the teacher's `rating` average on `users/{mohaffezId}`
- `teacherRatingReason == 'technical_only'` is retained for support review but excluded from the public average
- Public reputation requires `ratingPolicyVersion == 2`; legacy session ratings remain admin-visible but are excluded. Use `docs/RATING_V2_MIGRATION.md` for the dry-run-first rebuild.

### Cloud Functions (`functions/src/`)

TypeScript. Organised by domain: `notifications/`, `payments/`, `bookings/`, `admin/`, `cleanup/`. Entry point `index.ts` re-exports everything. The Paymob webhook is disabled (stub remains for future activation).

---

## Theme System

**Single source of truth:** `packages/mohaffez_mobile/lib/shared/theme/app_theme_constants.dart` (mobile) and the parallel constants file in `packages/mohaffez_web/`.

- Use `AppThemeConstants.*` for **all** colors, spacing, border radii, and typography.
- Never use raw `Colors.*` values in screens (except `Colors.transparent` where semantically correct).
- Never use `.withOpacity()` — use `.withValues(alpha: x)` (Flutter 3.x API).
- Deprecated aliases exist for backward compatibility (e.g., `primaryAmber` → `primary`, `accentGreen` → `secondary`) — always use the canonical names.

The active theme palette is teal/gold Islamic:
- **Primary:** `0xFF0B7A75` (teal)
- **Secondary:** `0xFFD4A44A` (soft gold)
- **AppBar gradient:** `deepTeal → midTeal → primary` (use `AppThemeConstants.tealGradient`)

---

## Localization Plan

The app is **Arabic-only at launch** (targeting Egypt, Saudi Arabia, UAE). English localization is a planned **V2 feature** after the first 3 months in market.

**Do not** suggest or implement `flutter_localizations` ARB files, `intl` message extraction, or any localization scaffolding until explicitly requested. Arabic strings hardcoded in widgets are intentional for V1 — do not refactor them into localization keys as a "cleanup" or "improvement."

When English support is eventually added, the migration path is: extract all Arabic strings → `packages/mohaffez_mobile/lib/l10n/app_ar.arb` + `app_en.arb` → typed access via `flutter_gen`.

---

## Key Conventions

- All screens wrap their root widget in `Directionality(textDirection: TextDirection.rtl, ...)` — RTL is per-screen, not just app-level.
- `SliverList` with `SliverChildBuilderDelegate` inside `CustomScrollView` — never `ListView.builder` inside `SliverFillRemaining` (nested scroll conflict).
- Session-date fields are `Firestore Timestamp`, `DateTime`, or `String` — always use a `_toDateTime(dynamic)` helper that handles all three types.
- Error visibility: show a `SnackBar` with `AppThemeConstants.error` background on failures — never silently swallow errors in user-facing flows.
- `Timestamp` import: use `import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;` to avoid polluting namespace.
