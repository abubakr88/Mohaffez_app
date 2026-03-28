# Mohaffez Mobile App — Current Status Document

**Generated:** March 2026  
**Based on:** Codebase analysis of `e:\Imam\Mohaffez_app`

---

# 1. Overview (Current Snapshot)

Mohaffez v1.0.0 is a **live Flutter application** with Firebase backend serving students and Quran teachers (Mohaffez). The core platform is operational: authentication, role-based access, teacher discovery, and session booking are all functional. A major new feature — **Al-Mohaffez Bundle-Based Booking Flow** — has been partially implemented and is under active development. This new flow introduces three booking paths (use existing bundle, buy new bundle, direct single-session request) with complex state management across Flutter frontend and Firebase Cloud Functions.

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

**Implementation Status:** `Partially Implemented` — Core CFs operational; slot-lock integration has edge cases

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

**Implementation Status:** `Implemented` — Production stable

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

## 4.3 Data Model & Constraints

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
- `lib/providers/booking_flow_provider.dart` — Booking state management
- `lib/models/subscription_model.dart` — Bundle data model
- `lib/models/session_request_model.dart` — Request data model

### Backend (Firebase Functions)
- `functions/src/bookings/createSessionRequest.ts` — Request creation
- `functions/src/payments/confirmBundleDirectPayment.ts` — Bundle confirmation
- `functions/src/payments/confirmSubscriptionSession.ts` — Bundle consumption
- `functions/src/payments/directPayment.ts` — Direct payment flow
- `functions/src/payments/handlers.ts` — Shared payment utilities

### Security & Data
- `firestore.rules` — Access control (lines 166-236 for sessionRequests)
- `firestore.indexes.json` — Query optimization
