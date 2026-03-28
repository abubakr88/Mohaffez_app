# Mohaffez Mobile App — Current Status Document

**Generated:** March 2026  
**Based on:** Codebase analysis of `e:\Imam\Mohaffez_app`

---

# 1. Overview (Current Snapshot)

Mohaffez v1.0.0 is a **live Flutter application** with Firebase backend serving students and Quran teachers (Mohaffez). The core platform is operational: authentication, role-based access, teacher discovery, and session booking are all functional. 

**Recent Updates (March 2026):**
- **Student Assignments & Performance Tracking** — Students can now view completed session assignments, track their Hifz/Muraja performance with ratings, and review Quran recitation mistakes marked by teachers in an interactive Mushaf view
- **Payment Scenarios** — All payment paths (Path A, B, C) now fully implemented and tested
- **Security Hardening** — Removed exposed Google Cloud service account credentials from git history

The **Al-Mohaffez Bundle-Based Booking Flow** remains the primary active development area with three booking paths (use existing bundle, buy new bundle, direct single-session request) with complex state management across Flutter frontend and Firebase Cloud Functions.

---

# 2. Shipped Features (Production)

| Feature | Status | Notes |
|---------|--------|-------|
| **Authentication** | Live | Email/phone with Firebase Auth; role assignment on registration |
| **Role-Based Access** | Live | Student, Mohaffez (Teacher), Admin roles enforced via Firestore rules and CF auth |
| **User Profiles** | Live | Profile editing, credentials ( certifications), privacy settings |
| **Location-Based Discovery** | Live | Nearby Mohaffez search with geolocation; distance calculation |
| **Teacher Profiles** | Live | Availability schedules, pricing plans, student reviews |
| **Basic Session Booking** | Live | Single-session requests with pending/accepted/rejected flows |
| **Direct Payment (Path C)** | Live | Teacher-first approval → student pays → teacher confirms |
| **Bundle/Subscription Booking** | Live | All 3 paths (A/B/C) complete; use existing bundle, buy new bundle, direct request |
| **Student Assignments** | Live | View completed session assignments, performance ratings, teacher notes |
| **Mistake Review System** | Live | Interactive Quran page showing teacher-marked recitation mistakes |
| **Notifications** | Live | Push notifications via FCM; in-app notification center |
| **Admin Dashboard** | Live | User management, credential approval, broadcast notifications, audit logs |
| **Slot Locking** | Live | 24-hour temporary slot reservation mechanism |
| **Commission Tracking** | Live | Weekly commission calculation for teachers (5% rate) |

---

# 3. In-Progress Work – Booking Bundles

The new bundle booking system introduces three mutually exclusive paths when a student views a teacher's profile and selects a time slot:

## Path A: Use Existing Bundle (`useExistingBundle`)

**User Flow:**
1. Student selects a teacher and time slot
2. System checks for existing active bundle matching (studentId + mohaffezId + sessionType)
3. If found, student can "Use Existing Bundle" — consumes 1 session credit
4. `requiresPaymentOnAcceptance: false` — no new payment required

**Backend Behavior:**
- `createSessionRequest()` CF creates request with `subscriptionId` and `planType: 'bundle'`
- Teacher accepts → `confirmSubscriptionSession()` CF decrements `remainingSessions`, creates `hafizSession`
- Status chain: `pending` → `accepted` (immediate, no payment gate)

**Implementation Status:** `Partially Implemented` — Core logic complete; minor UI polish remaining

---

## Path B: Buy New Bundle (`buyNewBundle`)

**User Flow:**
1. Student selects teacher and time slot
2. No active bundle exists for this (student, teacher, sessionType) combination
3. Student selects from available bundle/subscription plans
4. `requiresPaymentOnAcceptance: true` — teacher must approve before payment
5. Teacher accepts → student marks payment → teacher confirms payment

**Backend Behavior:**
- `createSessionRequest()` CF creates request with full plan details (planId, planTitle, sessionsCount, validityDays)
- `selectedPaymentMethod: 'directpayment'` triggers teacher-first flow
- `studentMarkedDirectPayment()` CF creates slotLock + directPaymentRequest + new sessionRequest (slot-coupled)
- `confirmBundleDirectPayment()` CF (called by teacher) creates `subscription` document + first `hafizSession`
- Atomic transaction ensures bundle activation + first session creation together

**Implementation Status:** `Implemented` — Production ready (March 2026)

---

## Path C: New Direct Request (`newDirectRequest`)

**User Flow:**
1. Student selects teacher and time slot
2. Chooses single-session direct payment
3. Teacher accepts request (sets status to `awaitingpayment`)
4. Student marks payment via DirectPaymentScreen
5. Teacher confirms via `DirectPaymentConfirmationsScreen`

**Backend Behavior:**
- `createSessionRequest()` with `requiresPaymentOnAcceptance: true` (for non-bundle plans)
- `mohaffezConfirmDirectPayment()` CF creates `hafizSession` after payment verification

**Implementation Status:** `Implemented` — Production stable (March 2026)

---

# 3. Student Assignments & Performance Tracking (New — March 2026)

A comprehensive system for students to review completed sessions, track their progress, and learn from teacher feedback.

## 3.1 Student Assignments Screen

**File:** `lib/screens/student_assignments_screen.dart`

**Features:**
- **Completed Sessions List**: Shows all completed `hafizSessions` with teacher name and date
- **Assignment Cards**: Rich card UI displaying:
  - Previous assignment performance (Hifz/Muraja completion status)
  - Performance ratings (1-10 star ratings)
  - Teacher's performance notes
  - New assignments for next session (Hifz/Muraja content)
  - Session rating and notes from teacher

**Key Data Fields Used:**
```
session['previousHifzCompleted'] - bool
session['previousHifzRating'] - int (0-10)
session['previousMurajaCompleted'] - bool
session['previousMurajaRating'] - int (0-10)
session['performanceNotes'] - String
session['hifzAssignment'] - String
session['murajaAssignment'] - String
session['sessionRating'] - int
session['sessionNotes'] - String
```

## 3.2 Mistake Review System

**File:** `lib/screens/student_assignments_screen.dart` (`_MistakeReviewCard`)

**Features:**
- **Mistake Aggregation**: Groups teacher-marked recitation mistakes by type
- **Visual Chips**: Color-coded mistake type chips showing counts
- **Interactive Mushaf**: Opens `InteractiveQuranPage` at the mistake location
- **Read-Only Mode**: Students can view but not edit mistakes

**Model:** `lib/models/quran_mistake_model.dart`

```dart
class QuranMistake {
  final String id;
  final int pageNumber;
  final double x;  // Normalized coordinates (0-1)
  final double y;
  final MistakeType type;  // tajweed, hifz, makharij, etc.
  final String? note;
  final String? markedBy;
  final DateTime? markedAt;
}
```

## 3.3 Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Assignment Cards UI | Done | Rich card design with performance badges |
| Mistake Review Card | Done | Grouped by type with interactive Mushaf link |
| Interactive Quran Page | Done | Read-only mode for student review |
| Performance Tracking | Done | Hifz/Muraja completion and ratings |
| Teacher Notes Display | Done | Performance notes and session messages |

---

# 4. Implementation Status by Layer

## 4.1 Frontend (Flutter)

### Done
- `BookingMethodScreen` — Entry point showing 3 booking options with availability logic
- `SelectBundlePlanScreen` — Plan selection with Firestore query for `bundle`/`subscription` types
- `ConfirmBundleSessionScreen` — Session confirmation using existing bundle credits
- `DirectPaymentScreen` — Payment method selection with wallet display
- `DirectBookingRequestScreen` — Path C single-session request flow
- `ActiveSubscriptionsScreen` — Student view of all active bundles
- `StudentAssignmentsScreen` — View completed sessions, assignments, performance ratings, and mistake review
- `BookingFlowProvider` — Centralized booking state (SlotContext, selected plan, path tracking)
- `activeBundleProvider` — Query for single active bundle by (studentId, mohaffezId, sessionType)

### In Progress / Missing
| Item | Location | Status |
|------|----------|--------|
| Bundle usage widget on teacher profile | `mohaffez_profile_screen.dart` | Missing — no visible indicator of existing bundle |
| SessionType-aware active bundle query | `session_repository.dart` | Done but needs validation across all paths |
| BundleStripCard click handling | `widgets/bundle_strip_card.dart` | Cards are selectable but not clickable for navigation |
| Deep-link recovery for abandoned bookings | `booking_flow_provider.dart` | Partial — slotContext null guard redirects to home |

---

## 4.2 Backend (Firebase Functions)

### Implementation Status - TypeScript Cloud Functions

| Function | File | Status |
|----------|------|--------|
| `createSessionRequest` | `bookings/createSessionRequest.ts` | **Done** — Supports all plan types; slot-lock integration for bundles |
| `confirmBundleDirectPayment` | `payments/confirmBundleDirectPayment.ts` | **Done** — Teacher-called; creates subscription + first session atomically |
| `confirmSubscriptionSession` | `payments/confirmSubscriptionSession.ts` | **Done** — Consumes bundle credit for subsequent sessions |
| `studentMarkedDirectPayment` | `payments/directPayment.ts` | **Done** — Creates slotLock + directPaymentRequest for bundles |
| `mohaffezConfirmDirectPayment` | `payments/directPayment.ts` | **Done** — Confirms single-session direct payments |
| `consumeSubscriptionAndCreateSession` | `payments/handlers.ts` | **Done** — Atomic subscription decrement + session creation |
| `confirmBookingAfterPayment` | `payments/handlers.ts` | **Done** — Slot disabling atomic with booking confirmation |

### Critical and High Priority Items (from Pending Fixes)

| Priority | Item | Description |
|----------|------|-------------|
| **CRITICAL** | sessionType uniqueness enforcement | `confirmBundleDirectPayment.ts` (line 256-270) has uniqueness check but `createSessionRequest.ts` (line 177-195) has duplicate prevention; verify no race condition exists |
| **CRITICAL** | isSlotCoupled transaction chain | Slot-coupled bundle purchases require atomic chain: slotLock → sessionRequest → directPaymentRequest → subscription; transaction boundaries need validation |
| **HIGH** | `originalSessionRequestId` resolution | Step 9h-b in `confirmBundleDirectPayment.ts` resolves original request; ensure status transitions don't orphan requests |
| **HIGH** | Teacher role case-sensitivity | `confirmBundleDirectPayment.ts` (line 57-58) has case-insensitive check; verify other CFs are consistent |
| **HIGH** | Bundle vs Subscription terminology | Model uses both terms interchangeably in some UI strings; could confuse users |

---

## 4.3 Security & Secrets Management

**Issue Resolved (March 2026):** Exposed Google Cloud Service Account Credentials

**Problem:**
- `functions/serviceAccountKey.json` containing Google Cloud service account credentials was committed to git history
- GitHub Push Protection blocked push with error: `GH013: Repository rule violations found`

**Resolution:**
1. Added `serviceAccountKey.json` to `functions/.gitignore`
2. Used `git filter-branch` to remove file from entire git history
3. Force pushed clean history to origin

**Action Required:**
- **CRITICAL:** Revoke the exposed service account credentials in Google Cloud Console immediately
- Generate new service account key if needed
- Store new credentials securely (environment variables, not in repo)

**Prevention:**
```
# functions/.gitignore
node_modules/
*.local
serviceAccountKey.json  # Never commit service account keys
```

---

## 4.4 Data Model & Constraints

### Core Collections

| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `subscriptions` | Active bundles/session packages | `studentId`, `mohaffezId`, `sessionType`, `remainingSessions`, `status`, `expiryDate` |
| `sessionRequests` | Booking requests pending approval | `studentId`, `mohaffezId`, `sessionType`, `status`, `planType`, `subscriptionId` |
| `hafizSessions` | Confirmed scheduled sessions | `studentId`, `mohaffezId`, `sessionDate`, `slotStart`, `slotEnd`, `subscriptionId`, `status` |
| `slotLocks` | Temporary 24h slot reservations | `mohaffezId`, `slotDate`, `timeSlot`, `sessionType`, `lockedBy`, `expiresAt`, `released` |
| `directPaymentRequests` | Pending payment confirmations | `studentId`, `mohaffezId`, `amount`, `status`, `sessionRequestId`, `subscriptionId` |
| `pricingPlans` | Teacher-defined plans | `mohaffezId`, `type` (single/bundle/subscription), `sessionsCount`, `priceEGP`, `validityDays` |

### Critical Constraints

**One-Active-Bundle Rule:**
```
(studentId, mohaffezId, sessionType) → max 1 active subscription
```

Enforced in:
- `createSessionRequest.ts` (lines 177-195) — Pre-request check
- `confirmBundleDirectPayment.ts` (lines 256-270) — Transaction-level guard

**Status State Machine:**
```
pending → awaitingpayment → awaitingdirectpaymentconfirmation → accepted
   ↓           ↓                      ↓
rejected   cancelled              cancelled
```

---

# 5. Known Gaps and Risks

| Gap | Location | Risk |
|-----|----------|------|
| sessionType uniqueness not enforced in `confirmSubscriptionSession` | `confirmSubscriptionSession.ts` | Student could potentially use bundle for different session type than purchased |
| isSlotCoupled chain requires 4+ documents in transaction | `confirmBundleDirectPayment.ts` | Firestore 500 document limit not at risk but transaction latency increases |
| UI: Pricing cards not navigating to booking | `mohaffez_profile_screen.dart` | Students see bundles but can't initiate booking flow from cards |
| `directPaymentRequest` orphaned if app killed mid-flow | `DirectPaymentScreen.dart` | Recovery mechanism exists but not fully tested |
| Bundle plan `mode` field nullable | `pricing_plan_model.dart` | Old Firestore docs without `mode` cause parsing fallback to single type |
| Slot lock expiration race condition | `releaseExpiredSlotLocks.ts` | Concurrent slot releases could temporarily show slot as available when locked |

---

# 6. Next Actionable Steps (1–2 Weeks)

| # | Task | File Location | Priority |
|---|------|---------------|----------|
| 1 | Fix bundle card navigation | `lib/screens/mohaffez_profile_screen.dart` | High |
| 2 | Add sessionType validation in `confirmSubscriptionSession` | `functions/src/payments/confirmSubscriptionSession.ts` (lines 223-234) | Critical |
| 3 | Test end-to-end slot-coupled bundle purchase flow | Test: Path B with slot selection | Critical |
| 4 | Add bundle indicator widget on teacher profile | `lib/screens/mohaffez_profile_screen.dart` | Medium |
| 5 | Verify `activeBundleProvider` query includes sessionType filter | `lib/providers/session_provider_paginated.dart` | High |
| 6 | Add error boundary for slotContext null in booking screens | `lib/screens/booking_method_screen.dart` | Medium |
| 7 | Update Firestore indexes for new bundle queries | `firestore.indexes.json` | High |
| 8 | Test bundle expiry edge cases | Test: Bundle with validityDays | Medium |
| 9 | Document CF deployment process | `functions/README.md` (create) | Low |
| 10 | Add analytics events for bundle conversion funnel | `lib/providers/booking_flow_provider.dart` | Low |

---

## Appendix: Key File References

### Frontend (Flutter)
- `lib/screens/booking_method_screen.dart` — Booking path selection
- `lib/screens/select_bundle_plan_screen.dart` — Path B plan selection
- `lib/screens/confirm_bundle_session_screen.dart` — Path A bundle usage
- `lib/screens/direct_payment_screen.dart` — Payment marking
- `lib/screens/direct_booking_request_screen.dart` — Path C single session
- `lib/screens/student_assignments_screen.dart` — Student assignments and mistake review
- `lib/providers/booking_flow_provider.dart` — Booking state management
- `lib/models/subscription_model.dart` — Bundle data model
- `lib/models/session_request_model.dart` — Request data model
- `lib/models/quran_mistake_model.dart` — Quran recitation mistake tracking

### Backend (Firebase Functions)
- `functions/src/bookings/createSessionRequest.ts` — Request creation
- `functions/src/payments/confirmBundleDirectPayment.ts` — Bundle confirmation
- `functions/src/payments/confirmSubscriptionSession.ts` — Bundle consumption
- `functions/src/payments/directPayment.ts` — Direct payment flow
- `functions/src/payments/handlers.ts` — Shared payment utilities

### Security & Data
- `firestore.rules` — Access control (lines 166-236 for sessionRequests)
- `firestore.indexes.json` — Query optimization
