# TODO — Remove admin from the mobile app + harden admin auth

> **Status:** planned, not started. Do this on a dedicated branch
> (`chore/remove-admin-from-mobile`) — ideally right before or just after the
> first public launch.
>
> **Why:** the consumer mobile app currently ships the full admin UI. The
> server boundary is solid (Firestore rules trust the `admin` custom claim, not
> the Firestore field; money collections are `write:false`), so this is **not an
> active vulnerability** — admin screens in the app are just UI that fails
> server-side for non-admins. BUT shipping admin in the public app:
> - hands attackers a full map of the back-office (decompile the APK),
> - makes total platform safety depend on every backend check being perfect,
> - means one compromised admin login on a personal phone controls everything.
>
> Admin already exists in **`mohaffez_web`** → move admin there exclusively.

---

## Scope

1. Remove admin UI/routes/guard branch from `mohaffez_mobile`.
2. Make admin live **only** on `mohaffez_web` (behind login + `admin` custom claim).
3. Make the **custom claim the single source of truth** for admin in Cloud Functions.

---

## Pre-work — verify the web console has parity FIRST

Before deleting anything from mobile, confirm `mohaffez_web` covers every admin
action the mobile app exposes. Compare against `mohaffez_mobile/lib/screens/admin/`:

- [ ] users list + user detail (view/suspend/role)
- [ ] teacher credential approval/rejection
- [ ] teacher requests
- [ ] broadcast notifications
- [ ] promo codes
- [ ] system settings + maintenance mode
- [ ] dev mode
- [ ] slot locks
- [ ] payment events
- [ ] wallet settings / credit wallet / wallet top-ups
- [ ] process payouts
- [ ] audit log
- [ ] failed operations

If any are missing in web, port them there **before** removing from mobile.

---

## Mobile changes (`packages/mohaffez_mobile/`)

### 1. Delete admin screens
- [ ] Delete the whole folder `lib/screens/admin/` (18 files):
  `admin_home_screen, admin_users_screen, admin_user_detail_screen,
  admin_credentials_screen, admin_failed_operations_screen, admin_promo_codes_screen,
  admin_system_settings_screen, admin_dev_mode_screen, admin_broadcast_screen,
  admin_slot_locks_screen, admin_payment_events_screen, admin_audit_log_screen,
  admin_wallet_settings_screen, admin_credit_wallet_screen, admin_wallet_topups_screen,
  admin_process_payouts_screen, admin_teacher_requests_screen, admin_commission_tiers_screen`

### 2. Router (`lib/config/app_router.dart`)
- [ ] Remove all admin screen `import` lines (the `// Admin screens` block).
- [ ] Remove the entire `// ADMIN ROUTES` section (all `/admin-home` and `/admin/*`
      GoRoutes).

### 3. Guards
- [ ] `lib/config/guards/role_guard.dart` — remove the `admin` branch / any
      redirect to `/admin-home`.
- [ ] `lib/config/guard_manager.dart` — in the suspension-lift redirect, remove
      `if (role == 'admin') return '/admin-home';`.
- [ ] Decide mobile behavior if an `admin` role *does* log in on mobile:
      **recommended** → show a simple full-screen notice
      ("إدارة المنصة متاحة عبر لوحة التحكم على الويب فقط") instead of any admin UI,
      or just route them to the student/teacher home. Never load admin screens.

### 4. Cleanup
- [ ] `flutter analyze` — remove any now-unused imports/providers that were only
      used by admin screens (some `admin_provider` / `admin_metrics_provider`
      usages may remain valid for web; only prune mobile-only dead code).
- [ ] Grep for stray `context.go('/admin` / `admin-home` references in mobile.

---

## Backend changes (`functions/`)

### 5. Make the custom claim the single source of truth
- [ ] `functions/src/admin/adminActions.ts` → `isAdminCaller()` currently falls
      back to the Firestore `role`:
      ```ts
      if ((context.auth.token as { admin?: boolean }).admin === true) return true;
      const userDoc = await db.collection('users').doc(context.auth.uid).get();
      return userDoc.exists && userDoc.data()?.role === 'admin';   // ← remove this fallback
      ```
      Change to **claim-only**:
      ```ts
      return (context.auth?.token as { admin?: boolean })?.admin === true;
      ```
- [ ] Ensure the `admin` custom claim is set **only** via the existing
      `setAdminClaim` Cloud Function (never client-writable).
- [ ] Audit every `https.onCall` in `functions/src/` to confirm each privileged
      one calls `ensureAdmin` — after this change the claim is the only wall.

---

## Web hardening (`packages/mohaffez_web/`)

- [ ] Admin dashboards already gated by login; confirm they also check the
      `admin` custom claim client-side (UX) — server still enforces.
- [ ] Optional: restrict the admin web build to a non-public URL / Firebase
      Hosting auth / IP allow-list.

---

## Cross-cutting hardening (separate, smaller tasks — nice to have)

- [ ] 2FA / MFA on admin accounts (Firebase Auth MFA, or Google sign-in + org 2FA).
- [ ] Re-authentication prompt for high-impact actions (payouts, credit wallet,
      delete user, change role).
- [ ] Split `admin` into roles (support / finance / super-admin) for least privilege.
- [ ] Periodic review of `firestore.rules` + all `onCall` for missing `isAdmin()`.

---

## Verification before merge

- [ ] Non-admin mobile user: no admin entry points anywhere; no `/admin*` route reachable.
- [ ] Admin user on mobile: sees the "use web console" notice (or normal home), **no** admin UI.
- [ ] Admin on web: full admin works.
- [ ] Cloud Functions: an account with `role:'admin'` in Firestore but **no** custom
      claim is now **rejected** by admin functions (proves claim-only).
- [ ] `flutter analyze` clean in mobile + web; `npm run build` clean in functions.
- [ ] Deploy order: functions first (claim-only), then web, then mobile release.

---

_Created 2026-06-02. Delete this file once the work is merged._
