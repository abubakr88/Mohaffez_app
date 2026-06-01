# Mohafezy (محفظي) — Software Design & Structure

> Technical reference for the Mohafezy platform: architecture, entry points,
> configuration files, module layout, data model, and the request/data flow
> across all tiers. For the product/marketing view, see
> [APP_FEATURES.md](APP_FEATURES.md). For requirements, see
> [SOFTWARE_REQUIREMENTS_DOCUMENT.md](SOFTWARE_REQUIREMENTS_DOCUMENT.md).

---

## 1. System Overview

**Mohafezy** is a marketplace platform connecting Quran students with certified
teachers (*mohaffezeen*) for memorization sessions — in person, at a mosque, or
online. It is built as a **Melos-managed Flutter monorepo** with a **Firebase**
backend (Firestore, Auth, Cloud Functions, Storage, Cloud Messaging, App Check,
Hosting).

The product ships as **three surfaces sharing one backend**:

| Surface | Tech | Audience |
|---|---|---|
| Mobile app | Flutter (Android / iOS) | Students & teachers |
| Web app | Flutter Web | Admins & teacher dashboards |
| Marketing site | Static HTML | Public (mohafezy.com) |

**Roles:** `student`, `mohaffez` (teacher), `admin`. UI is **Arabic-only, RTL**
throughout (V1; English is a planned V2).

### High-level architecture

```
┌─────────────────┐   ┌─────────────────┐   ┌──────────────────┐
│  Mobile (Flutter)│   │   Web (Flutter)  │   │ Marketing (HTML) │
│ student/teacher  │   │  admin/teacher   │   │  mohafezy.com    │
└────────┬─────────┘   └────────┬─────────┘   └──────────────────┘
         │                      │
         │   shared models / providers / repositories
         │        (packages/mohaffez_core)
         └──────────┬───────────┘
                    ▼
        ┌───────────────────────────────────────────┐
        │                Firebase                    │
        │  Auth · Firestore · Storage · Messaging    │
        │  App Check · Hosting                        │
        │  Cloud Functions (TypeScript, 31 exports)  │
        └───────────────────────────────────────────┘
```

---

## 2. Repository Layout (Monorepo)

Melos workspace (`melos.yaml`) — all packages live under `packages/**`.

```
Mohaffez_app/
├── packages/
│   ├── mohaffez_core/      # Shared models, providers, repositories, services
│   ├── mohaffez_mobile/    # Flutter Android/iOS app
│   └── mohaffez_web/       # Flutter Web app (admin + teacher dashboards)
├── functions/              # Firebase Cloud Functions (TypeScript)
├── marketing_site/         # Static marketing site → mohafezy.com
├── public/                 # Default Firebase hosting placeholder
├── docs/                   # Project documentation (this file lives here)
├── scripts/                # Helper scripts
├── firebase.json           # Firebase services config (functions/firestore/storage/hosting)
├── firestore.rules         # Firestore security rules
├── firestore.indexes.json  # Composite index definitions
├── storage.rules           # Cloud Storage security rules
├── cors.json               # Storage CORS config
├── melos.yaml              # Monorepo workspace definition
├── .firebaserc             # Project aliases: dev → mohaffez-dev, prod → mohaffez-ba2ec
└── CLAUDE.md               # Engineering guide / conventions
```

### `mohaffez_core` (shared library)

The single source of truth for domain logic, imported by both Flutter apps.

```
packages/mohaffez_core/lib/src/
├── models/         # Freezed data models (+ generated *.freezed.dart / *.g.dart)
├── providers/      # Riverpod providers (state + actions) — 22 providers
├── repositories/   # Thin Firestore data-access wrappers — 10 repositories
├── services/       # Cross-platform services (cache, connectivity, quran, …)
├── constants/      # Shared constants
└── utils/          # Pure utility functions (validation, formatting, …)
```

---

## 3. Entry Points

### Mobile app — two flavors, one bootstrap

The mobile app uses **flavors** so dev and prod can coexist on the same device.

| Flavor | Firebase project | App ID | Entry point | Firebase config |
|---|---|---|---|---|
| `dev`  | `mohaffez-dev`    | `app.mohafezy.dev` | `lib/main_dev.dart` | `firebase_options_dev.dart` (committed) |
| `prod` | `mohaffez-ba2ec`  | `app.mohafezy`     | `lib/main.dart`     | `firebase_options.dart` (gitignored) |

Both entry points are one line — they only choose which `FirebaseOptions` to
pass into the shared `bootstrap()`:

```dart
// lib/main.dart (prod)
void main() => bootstrap(firebaseOptions: DefaultFirebaseOptions.currentPlatform);

// lib/main_dev.dart (dev)
void main() => bootstrap(firebaseOptions: DevFirebaseOptions.currentPlatform);
```

**`lib/bootstrap.dart`** is the real startup sequence (shared by both flavors):

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp(options:)`
3. **App Check** — Play Integrity / DeviceCheck in release, debug providers
   otherwise (skipped on web)
4. **Firestore** offline persistence (`persistenceEnabled`, unlimited cache)
5. **FCM** background handler + `NotificationService.initialize()` (mobile only)
6. Arabic date formatting (`ar`, `ar_SA`, `ar_EG`)
7. `CacheService.initialize()` + **stale-cache guard** (clears local cache if a
   cached UID exists but Firebase Auth has no current user)
8. System UI overlay style + portrait-lock (mobile)
9. `runApp(ProviderScope(child: DevModeOverlay(child: MyApp())))`
10. On any failure → `buildErrorApp()` fallback UI

`lib/app.dart` hosts the `MyApp` widget, lifecycle observer, and error fallback.

### Web app

Entry: `packages/mohaffez_web/lib/main.dart` → `app.dart` (`MyApp`). Title set to
`Mohafezy | محفظي`. Served from Firebase Hosting target **`app`**.

### Marketing site

Static `marketing_site/index.html`, served from Firebase Hosting target
**`marketing`**.

---

## 4. Routing & Navigation (Mobile)

**GoRouter** with a single `ShellRoute` wrapping all authenticated routes in
`HomeShell` (bottom navigation). Defined in
[config/app_router.dart](../packages/mohaffez_mobile/lib/config/app_router.dart).

```
goRouterProvider (Provider<GoRouter>)
├── initialLocation: '/'
├── refreshListenable: GoRouterNotifier   (auth/suspension/user streams)
├── redirect: GuardManager.checkGuards
└── routes:
    ├── PUBLIC (no shell):
    │     /  /login  /register  /google-role-selection
    │     /maintenance  /suspended  /setup  /exam-result
    │     /teacher-certificates  /teacher-pending  /teacher-rejected
    └── ShellRoute (HomeShell + bottom nav):
          Student:  /home /my-sessions /my-schedule /nearby /requests
                    /assignments /student-wallet /wallet-topup
                    /mohaffez/:id /rate-session/:sessionId /mushaf/:pageNumber
          Booking:  /booking/method /booking/select-bundle-plan
                    /booking/confirm-bundle-session /booking/direct-payment
                    /booking/direct-request /payment-webview /pick-location
                    /payment/:mohaffezId
          Teacher:  /mohaffez-home /pending-requests /completed-sessions
                    /upcoming-sessions /credentials /availability /my-students
                    /student/:studentId /complete-session/:sessionId
                    /pricing-management /teacher-schedule /session-quiz
                    /student-challenges /teacher-setup-wizard
          Wallet:   /mohaffez-wallet /wallet-settings /request-payout
          Shared:   /notifications /profile /settings /location-settings
                    /privacy-settings /cancellation-policy /student-rewards
                    /active-subscriptions
          Admin:    /admin-home /admin/users /admin/user-detail
                    /admin/credentials /admin/failed-ops /admin/promo-codes
                    /admin/settings /admin/dev-mode /admin/broadcast
                    /admin/slot-locks /admin/payment-events /admin/wallet-numbers
                    /admin/wallet-topups /admin/credit-wallet
                    /admin/process-payouts /admin/audit-log
                    /admin/teacher-requests
```

> **Convention:** always use `context.push` / `context.go`. Never
> `Navigator.push` — it bypasses the GoRouter stack.

### Route Guards

Guards run on every redirect via `GuardManager.checkGuards`, in **priority
order**, with a suspension pre-check that short-circuits to `/suspended`:

```
GuardManager
  ├── (pre-check) Suspension  → /suspended if userSuspensions doc OR status=='suspended'
  ├── TimeoutGuard            → handles slow auth/profile load
  ├── AuthGuard               → unauthenticated → /login
  ├── SetupGuard              → incomplete profile → /setup
  └── RoleGuard               → routes to correct role home, blocks cross-role access
```

The manager includes **loop protection** (ignores a redirect identical to the
current path+query) and coalesces provider-fire storms into a single
`notifyListeners` per microtask (`GoRouterNotifier._scheduleNotify`).

---

## 5. State Management & Data Flow

**Riverpod only** (`flutter_riverpod`). No `setState` for shared state.

```
Screen ──watch──▶ Provider (AsyncValue state) ──▶ Repository ──▶ Firestore
   │                  ▲                                              │
   └──read(notifier)──┘  ◀────────── stream / snapshot ─────────────┘
```

- **Screens** watch providers via `ref.watch`; mutations go through
  `ref.read(...notifier)`.
- **Providers** (`packages/mohaffez_core/lib/src/providers/`) hold `AsyncValue`
  state and expose actions. Key ones: `auth_provider`, `user_provider`,
  `booking_flow_provider`, `session_provider_paginated`, `wallet_provider`,
  `payment_provider`, `pricing_provider`, `subscription_provider`,
  `suspension_provider`, `system_config_provider`, `admin_metrics_provider`,
  `teacher_commission_provider`, `server_clock_provider`.
- **Repositories** (`.../repositories/`) are thin Firestore wrappers:
  `user`, `session`, `payment`, `pricing`, `subscription`, `wallet`,
  `notification`, `promo_code`, `system_config`, `admin`.
- **Pagination** uses the `studentSessionsFirstPageProvider(uid)` /
  `sessionActionsProvider` patterns in `session_provider_paginated.dart`.

**Role caching:** `role` on `users/{uid}` is cached in `CacheService`
(SharedPreferences); guards read it via `currentUserRoleProvider`.

---

## 6. Data Model (Firestore Collections)

| Collection | Purpose |
|---|---|
| `users` | All profiles (students, mohaffezeen, admins); holds `role`, `status` |
| `hafizSessions` | Booked sessions; `status`: `pending → accepted → completed` |
| `sessionRequests` | Pre-acceptance booking requests |
| `subscriptions` | Bundle subscription plans per student |
| `payments` | Payment records (direct, bundle, subscription) |
| `userSuspensions` | Suspension docs — existence ⇒ suspended |
| `systemConfig` | App-wide flags (maintenance mode, app version, FCM toggle) |
| `promoCodes` | Promo code definitions |
| `notifications` | In-app notification docs |
| `adminAuditLog` | Audit trail for privileged admin actions |
| `broadcastHistory` | Record of admin broadcasts |
| `walletTransactions` / wallet ledger | Double-entry wallet ledger |
| `payoutRequests` | Teacher payout requests |

**Domain models** live in `packages/mohaffez_core/lib/src/models/` as
`@freezed` / `@JsonSerializable` classes with generated `*.freezed.dart` /
`*.g.dart` siblings (never hand-edited). Examples: `user_model`,
`session_model`, `payment_model`, `subscription_model`, `wallet_model`,
`wallet_transaction_model`, `payout_request_model`, `commission_tier_model`,
`pricing_plan_model`, `promo_code_model`, `quran_mistake_model`,
`notification_model`, `suspension_model`, `system_config_model`.

### Key field conventions
- **Session rating pipeline:** student writes `teacherRating` (int) +
  `reviewNotes` (string) to `hafizSessions`; Cloud Function `onSessionCompleted`
  recomputes the teacher's `rating` average on `users/{mohaffezId}`. Field names
  must match Firestore security rules.
- **Date fields** may be `Timestamp`, `DateTime`, or `String` — always normalize
  via a `_toDateTime(dynamic)` helper.

---

## 7. Backend — Cloud Functions (`functions/src/`)

TypeScript, organized by domain. Entry point `index.ts` re-exports everything
(**31 exports**). Built with `npm run build` (predeploy hook in `firebase.json`).

```
functions/src/
├── index.ts                 # Re-export entry point (single source of exports)
├── admin/                   # adminActions, appVersionCheck, maintenanceCheck, metrics
├── bookings/                # confirmFreeSession, createSessionRequest
├── notifications/           # sendNotification, triggers, session/payment reminders
├── payments/                # directPayment, bundle confirms, paymobWebhook (stub),
│                            #   projections, expiredPayments, recomputeTeacherTiers
├── onlineSessions/          # meeting creation, start, reminders, autoEndOverdueSessions
├── cancellations/           # cancellation policy, no-show handling, bundle detection
├── wallet/                  # walletTopUp, walletPaySession, walletPayout
├── cleanup/                 # releaseExpiredSlotLocks
├── services/  types/  utils/
├── onUserSuspended.ts  onUserUnsuspended.ts  setAdminClaim.ts
└── getMohaffezStudentCount.ts
```

### Function categories

- **Callable (`https.onCall`)** — privileged/admin & self-service operations:
  `setUserRole`, `suspendUser`, `unsuspendUser`, `deleteUserAccount` (admin),
  `deleteMyAccount` (self-service, scoped to caller), `sendBroadcastNotification`,
  `approveCredential`, `rejectCredential`, `triggerCleanupJobManually`,
  `getBroadcastAudienceCount`, wallet top-up/payout flows, `createSessionRequest`,
  direct-payment confirmations.
- **Firestore triggers** — `onSessionCreated`, `onSessionCompleted`,
  `onTeacherRated`, `onPaymentCreated`, `onSessionRequestAccepted`,
  `onSessionAcceptedCreateMeeting`, `onMeetingStarted`, `onUserSuspended`,
  `onUserUnsuspended`, cancellation/no-show triggers.
- **Scheduled (cron)** — `sendSessionReminders`, `sendPaymentDeadlineReminders`,
  `sendOnlineSessionReminder`, `autoEndOverdueSessions`, `checkExpiredPayments`,
  `releaseExpiredSlotLocks`, `recomputeTeacherTiers`, `refreshAdminMetrics`.
- **Webhook** — `paymobWebhook` (exported, gated off at runtime via
  `systemConfig/global.paymobEnabled`; stub for future activation).

**Authorization pattern:** admin callables go through `ensureAdmin(context)`
(checks `admin` custom claim or `users/{uid}.role === 'admin'`). Self-service
callables derive the target strictly from `context.auth.uid` (never a
client-supplied id). Privileged actions append to `adminAuditLog`.

---

## 8. Configuration Files

| File | Scope | Purpose |
|---|---|---|
| `melos.yaml` | Repo | Workspace packages + `analyze` / `test` / `gen` scripts |
| `firebase.json` | Repo | Functions (predeploy build), Firestore rules/indexes, Storage rules, Hosting (`app` + `marketing` targets, cache headers) |
| `.firebaserc` | Repo | Project aliases: `dev → mohaffez-dev`, `prod → mohaffez-ba2ec` |
| `firestore.rules` | Repo | Firestore security rules |
| `firestore.indexes.json` | Repo | Composite index definitions |
| `storage.rules` | Repo | Cloud Storage security rules |
| `cors.json` | Repo | Storage bucket CORS |
| `.vscode/launch.json` | Repo | Launch configs: "mohaffez_mobile (dev)" / "(prod)" |
| `pubspec.yaml` (per package) | Package | Dart/Flutter dependencies |
| `.env` (repo root) | **Local, never committed** | `GOOGLE_MAPS_API_KEY` + dart-define secrets |
| `android/key.properties` | **Local** | Release signing (keystore path + passwords) |
| `firebase_options.dart` | **Local (prod)** | Prod Firebase config (gitignored) |
| `firebase_options_dev.dart` | Committed | Dev Firebase config (public client keys) |
| `functions/serviceAccountKey.json` | **Local** | Admin SDK key for functions |

### Hosting targets (`firebase.json`)
- **`app`** → `packages/mohaffez_web/build/web` — SPA rewrite to `/index.html`;
  `index.html` and service worker are `no-cache`, `canvaskit/` and `assets/` are
  immutable (1-year cache).
- **`marketing`** → `marketing_site/`.

---

## 9. Key Dependencies (Mobile)

| Concern | Package(s) |
|---|---|
| State management | `flutter_riverpod`, `riverpod_annotation` |
| Routing | `go_router` |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `firebase_storage`, `firebase_app_check`, `cloud_functions` |
| Codegen (runtime) | `freezed_annotation`, `json_annotation` |
| Maps & location | `flutter_map` (OSM), `latlong2`, `geolocator` (free, no Google Maps SDK cost) |
| Payments UI | `webview_flutter` |
| Notifications | `flutter_local_notifications` |
| Quran data | `quran` |
| Media | `image_picker`, `image_cropper`, `flutter_image_compress`, `file_picker` |
| Cache/storage | `shared_preferences`, `flutter_cache_manager`, `cached_network_image` |
| Connectivity | `connectivity_plus`, `http`, `crypto` |
| UI | `google_fonts`, `shimmer`, `table_calendar`, `confetti` |
| i18n/format | `intl`, `timeago` (Arabic locales) |

---

## 10. Theme System

Single source of truth: `app_theme_constants.dart` (one in mobile, a parallel
file in web). Active palette is **teal/gold Islamic**:

- **Primary** `0xFF0B7A75` (teal) · **Secondary** `0xFFD4A44A` (soft gold)
- AppBar gradient: `deepTeal → midTeal → primary` (`AppThemeConstants.tealGradient`)

Rules: use `AppThemeConstants.*` for all colors/spacing/radii/typography; never
raw `Colors.*` (except `Colors.transparent`); never `.withOpacity()` — use
`.withValues(alpha: x)`.

---

## 11. Build, Run & Deploy

### Bootstrap
```bash
dart pub global activate melos     # first time
melos bootstrap                    # resolve deps across all packages
```

### Code generation (Freezed / JSON / Riverpod)
```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

### Run / build (mobile)
```bash
cd packages/mohaffez_mobile
flutter run --flavor dev --dart-define-from-file=../../.env -t lib/main_dev.dart
./build_release_apk.bat            # APK (prod flavor)   — from repo root
./build_release_aab.bat            # AAB for Play Store  — from repo root
```
Batch scripts validate `.env` and `android/key.properties` before building.

### Web
```bash
cd packages/mohaffez_web
flutter run -d chrome
flutter build web --release
```

### Firebase (normally driven by GitHub Actions — see RELEASE.md)
```bash
firebase use dev | prod
firebase deploy --only firestore:rules
firebase deploy --only functions
firebase deploy                    # everything
cd functions && npm run build      # compile functions
```

---

## 12. Cross-cutting Conventions

- **RTL per screen:** every screen wraps its root in
  `Directionality(textDirection: TextDirection.rtl, …)`.
- **Slivers:** `SliverList` + `SliverChildBuilderDelegate` inside
  `CustomScrollView`; never `ListView.builder` inside `SliverFillRemaining`.
- **Error visibility:** show a `SnackBar` with `AppThemeConstants.error` on
  failures — never silently swallow user-facing errors.
- **App Check** enforced in release (Play Integrity / DeviceCheck).
- **Offline-first:** Firestore persistence enabled with unlimited cache.
- **Generated files** (`*.freezed.dart`, `*.g.dart`) are never edited by hand.

---

*Last updated: 2026-06-01. Maintained alongside the codebase — update this file
when entry points, routes, collections, or configuration change.*
