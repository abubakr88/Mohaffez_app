# Payment & Commission System — Test Checklist

This checklist covers every scenario documented in `TEACHER_PAYMENT_GUIDE_AR.md` and `STUDENT_PAYMENT_GUIDE_AR.md`. Each item is a discrete test case. Mark `[x]` when verified end-to-end on **dev**.

**Legend:**
- 📱 = mobile app test
- ☁️ = Cloud Function / backend test
- 🔥 = Firestore data check
- 🔔 = notification check
- ⚙️ = scheduled job (use Firebase scheduler emulator or wait for the trigger)
- 🤖 = **automated test exists** — see [Automated Tests](#automated-tests) section

---

## Automated Tests

**70 tests across 4 files cover ~50% of this checklist** — all the pure logic (refund math, penalty calculation, tier selection, settlement amounts, webhook integrity, redirect URL parsing). They run in under 10 seconds and require no setup beyond `npm install` / `flutter pub get`.

### How to run them

```bash
# Cloud Function tests (58 tests — cancellations, settlement, Paymob HMAC)
cd functions
npm test                # one-shot
npm run test:watch      # auto-re-run when files change

# Mobile app tests (12 tests — Paymob redirect URL parsing)
cd packages/mohaffez_mobile
flutter test                                                         # all tests
flutter test test/services/paymob_callback_parser_test.dart          # one file
```

### When to run them

| Trigger | Why |
|---|---|
| **Before pushing changes** to `functions/src/cancellations/`, `functions/src/payments/`, `functions/src/utils/paymobVerification.ts`, or `payment_webview_screen.dart` | These files have direct test coverage — break a rule, get a red ✗ in seconds |
| **Before editing** the policy values in `TEACHER_PAYMENT_GUIDE_AR.md` or `STUDENT_PAYMENT_GUIDE_AR.md` | The "Documentation consistency" sections fail if doc values drift from code |
| **Before deploying functions to prod** | `cd functions && npm test && npm run deploy` — last gate |
| **After Firebase SDK upgrades** | Catches breaking changes in field types / rounding |
| **When investigating a payment bug** | Add a new test reproducing the bad case first, then fix the code until it passes |

### What the test files cover

| File | Tests | Checklist sections | Lives at |
|---|---|---|---|
| `cancellationPolicy.test.ts` | 16 | C1–C3, E1–E3, F, Q | `functions/src/cancellations/__tests__/` |
| `settlement.test.ts` | 27 | H1–H2, I1–I6, G (math), Q | `functions/src/payments/__tests__/` |
| `paymobVerification.test.ts` | 15 | A2 (webhook integrity) | `functions/src/utils/__tests__/` |
| `paymob_callback_parser_test.dart` | 12 | A2 (WebView redirect parsing) | `packages/mohaffez_mobile/test/services/` |

### How to read test output

**Passing:**
```
✓ src/cancellations/__tests__/cancellationPolicy.test.ts > C1: > 3h before → 100% refund 1ms
Test Files  3 passed (3)
     Tests  58 passed (58)
```

**Failing** (example — if someone changed the 3h refund threshold to 4h):
```
FAIL  C1 boundary: exactly 3h01m → still 100%
  Expected: 100
  Received: 50
```
The test name tells you exactly which rule broke and the file/line points at the assertion. Either revert the code change OR update the test AND the docs together.

### How to add a new test

When you implement a new payment behavior or fix a bug:

1. **Find the right file** by topic (cancellation? settlement? webhook?).
2. **Add an `it('description', () => { ... })`** block describing the expected behavior.
3. **Call the pure function** (`computeCancellationOutcome`, `pickTier`, `computeSettlementPiastres`, etc.) with the inputs.
4. **Assert the expected output** with `expect(result).toBe(...)`.
5. Run `npm run test:watch` and iterate until green.

Example template:

```ts
it('describes the new rule in plain language', () => {
  const out = computeCancellationOutcome({
    cancelledBy: 'student',
    teacherNoShow: false,
    sessionDate: sessionInHours(2.5, NOW),
    cancelledAt: NOW,
  });
  expect(out).toEqual({ refundPercent: 50, penaltyPercent: 0 });
});
```

### What automated tests CANNOT cover

These items in this checklist still need manual verification (or a future Firestore emulator setup):

- ❌ Real Paymob iframe transactions (needs sandbox + device)
- ❌ Firestore wallet ledger writes actually firing (needs emulator)
- ❌ Push notification delivery (needs real device with FCM)
- ❌ UI flows: tapping buttons, screen transitions, animations
- ❌ Scheduled function cron timing
- ❌ Admin web app flows

Items marked with 🤖 below have automated coverage. All others need a human to verify on dev.

---

## A. Student — Payment Methods

### A1. Wallet (in-app balance)
- [ ] 📱 Student with sufficient balance books a session → payment succeeds instantly, no card UI shown
- [ ] 🔥 `payments/{id}` doc created with `gateway: 'wallet'`, `status: 'completed'`
- [ ] 🔥 Student wallet balance decremented by session price
- [ ] 🔥 Teacher `pendingBalance` incremented by session price (the full amount before commission)
- [ ] 📱 Student with insufficient balance → blocked with clear message, no debit happens

### A2. Paymob card payment
- [ ] 📱 Student selects Paymob → WebView opens with iframe
- [ ] 📱 Test card success (`5123 4567 8901 2346`, `12/25`, `123`, OTP `123456`) → success animation
- [ ] 📱 Test card failure (wrong OTP) → failure dialog with retry option
- [ ] 📱 Student cancels mid-iframe → returns to payment screen, no debit
- [ ] ☁️ Webhook receives `success=true` → payment doc marked `completed`
- [ ] ☁️ Webhook receives `success=false` → payment doc marked `failed`
- [ ] ☁️ Webhook idempotency: same callback fired twice → second is no-op (check `eventStore`)
- [x] 🤖 ☁️ Webhook signature integrity — `paymobVerification.test.ts` (15 cases: tampered amount, flipped success flag, wrong secret, malformed signature)
- [x] 🤖 📱 WebView intercept correctly distinguishes `success=true` vs `success=false` — `paymob_callback_parser_test.dart` (12 cases, including the original substring bug)
- [ ] 📱 3-min timeout fires if user idles → timeout dialog
- [ ] 📱 `paymobEnabled = false` → option shows "قريبا" badge, can't be selected

### A3. Direct payment to teacher (cash / transfer)
- [ ] 📱 Student picks "direct" → instructions screen with teacher contact info
- [ ] 📱 Teacher receives notification of pending direct payment
- [ ] 📱 Teacher confirms receipt in their app → session moves to `accepted`
- [ ] 📱 Teacher rejects payment → session stays pending, student notified
- [ ] 🔥 `payments/{id}` doc has `gateway: 'direct'`, `confirmedByTeacher: true` after confirmation

---

## B. Student — Wallet Top-up

- [ ] 📱 Profile → Wallet → Top-up → enter amount → choose method
- [ ] 🔥 Top-up request doc created with `status: 'pending'`
- [ ] 📱 Admin approves → wallet credited, student notified
- [ ] 📱 Admin rejects → student notified with reason, wallet unchanged
- [ ] 📱 Admin SLA: approval happens within 1–3 business days

---

## C. Student Cancellation Refund Rules

For each, create an accepted session, advance system clock (or schedule far enough out), then cancel as student. Verify refund banner BEFORE cancel matches dialog AFTER cancel matches actual wallet credit.

| # | Time before session | Expected refund | Tests |
|---|---|---|---|
| C1 | > 3h | 100% to wallet | [x] 🤖 refund% logic [ ] banner [ ] dialog [ ] wallet credit [ ] payment doc `refundPercent: 100` |
| C2 | 1h–3h | 50% to wallet | [x] 🤖 refund% logic [ ] banner [ ] dialog [ ] wallet credit [ ] payment doc `refundPercent: 50` |
| C3 | < 1h | 0% | [x] 🤖 refund% logic [ ] banner [ ] dialog [ ] no wallet credit [ ] payment doc `refundPercent: 0` |
| C4 | Session already started | Cancel button hidden | [ ] no bottom bar shown |
| C5 | Session status = `completed` | Cancel button hidden | [ ] no bottom bar shown |

> 🤖 The "refund% logic" column is covered by `cancellationPolicy.test.ts` (boundary cases at exactly 3h and exactly 1h included).

Also check:
- [ ] 🔥 Cancelled session doc: `status: 'cancelled'`, `cancelledBy: 'student'`, `cancelledAt: <timestamp>`, `refundAmount`, `refundPercent`
- [ ] 🔔 Teacher receives cancellation notification
- [ ] 🔔 Student receives confirmation notification with refund amount
- [ ] 📱 Cancelled session disappears from "upcoming" list, appears in "history" with cancelled badge

---

## D. Student No-show

- [ ] 📱 Teacher reports "student didn't attend" after session end → session marked `studentNoShow: true`, `status: 'completed'` (counts to teacher)
- [ ] 🔥 No refund issued to student wallet
- [ ] 🔥 Teacher `pendingBalance` incremented full price
- [ ] 🔔 Student receives "غياب مسجل" notification with warning
- [ ] 📱 Student account shows warning count incremented

---

## E. Teacher Cancellation — Refunds & Penalties

For each tier, set system clock so the cancel happens at the right offset, then cancel as teacher.

| # | Time before session | Refund | Commission penalty | Tests |
|---|---|---|---|---|
| E1 | > 3h | 100% to student | 0% | [x] 🤖 logic [ ] refund credited [ ] no penalty added |
| E2 | 1h–3h | 100% to student | +0.5% | [x] 🤖 logic [ ] refund credited [ ] `commissionPenaltyPercent` increment by 0.5 |
| E3 | < 1h | 100% to student | +1% | [x] 🤖 logic [ ] refund credited [ ] `commissionPenaltyPercent` increment by 1.0 |

> 🤖 Refund% + penalty% decisions are covered by `cancellationPolicy.test.ts`. The Firestore writes (wallet credit, penalty increment) still need manual verification on dev.

Verify for each:
- [ ] 🔥 Session doc: `cancelledBy: 'teacher'`, `refundPercent: 100`
- [ ] 🔥 Student wallet credited 100%
- [ ] 🔥 Teacher user doc: `commissionPenaltyPercent` increased correctly
- [ ] 🔔 Student notified of refund
- [ ] 🔔 Teacher notified of penalty (if any)
- [ ] 🔔 Admin notified of teacher cancellation
- [ ] 📱 Teacher warning counter incremented

---

## F. Teacher No-show

### F1. Manual report (student-initiated, any session type)
- [ ] 📱 Student opens rate screen for not-yet-started session → taps "المحفظ لم يحضر الجلسة"
- [ ] 🔥 Session doc: `teacherNoShow: true`, `status: 'cancelled'`, `cancelledBy: 'teacher'`
- [ ] 🔥 Student wallet credited 100%
- [ ] 🔥 Teacher `commissionPenaltyPercent` increment by 1.5
- [x] 🤖 No-show always triggers 100% refund + 1.5% penalty regardless of timing — `cancellationPolicy.test.ts`
- [ ] 🔔 Admin notified
- [ ] 🔔 Teacher notified of warning + penalty

### F2. Auto-detect (online sessions only)
- [ ] ⚙️ Schedule an online session ≥ 60 min in the past, teacher never joined (no `meetingTeacherJoinedAt`) → `autoEndOverdueSessions` job marks it no-show
- [ ] 🔥 Same Firestore writes as F1
- [ ] ⚙️ Verify composite index `sessionType + status + meetingTeacherJoinedAt + slotStart` exists (else query errors silently)
- [ ] 📱 If teacher joins AFTER 60 min → still marked no-show (joining late doesn't reverse)
- [ ] 📱 If session is in-person (not online) → auto-detect should NOT fire (no-show stays student-reported only)

---

## G. Cumulative Penalty Accumulation

- [x] 🤖 Math: cumulative penalty produces correct effective rate (e.g. base 15% + 1.5% accumulated → 16.5%) — `settlement.test.ts`
- [ ] 🔥 Teacher with `commissionPenaltyPercent: 0` cancels < 1h (+1%) → reads 1.0
- [ ] 🔥 Same teacher cancels 1–3h on another session (+0.5%) → reads 1.5
- [ ] 🔥 Same teacher reported no-show (+1.5%) → reads 3.0
- [ ] 📱 Teacher app shows current penalty in commission card (if surfaced)
- [ ] ☁️ Penalty is preserved across reads (no race condition: try two near-simultaneous cancels and verify final value = sum)

> 🤖 The penalty math (how it compounds and how it affects the final settlement rate) is automated. The actual Firestore `FieldValue.increment` writes across multiple real cancellations need manual verification (or future emulator tests).

---

## H. Commission Tiers — Cycle Mechanics

Tiers (default): Starter 15% (0+ sessions), Active 12% (8+), Mid 10% (14+), Premium 8% (20+), Elite 5% (35+).

### H1. Single cycle, tier rises
- [x] 🤖 Tier-selection math at each threshold (0, 7, 8, 14, 20, 35, 100) — `settlement.test.ts`
- [ ] 🔥 Start of cycle: `commissionTier: 'starter'`, `currentCycleSessions: 0`
- [ ] Complete 7 on-time sessions → still `starter` (counter = 7)
- [ ] Complete 8th on-time session → tier moves to `active`, notification fires
- [ ] Complete up to 20 on-time sessions → reaches `distinguished` (تمييز)
- [ ] At settlement, commission deducted at `distinguished` rate (8%) for ALL 20 sessions, not just the ones after promotion

### H2. Late sessions don't count toward tier
- [x] 🤖 7 on-time + 13 late → stays Starter (15%), full revenue still paid — `settlement.test.ts` (I3)
- [ ] Teacher completes 20 sessions, 3 of which started > 10 minutes late
- [ ] 🔥 Tier counter shows 17, not 20
- [ ] At settlement, tier is `intermediate` (10%), not `distinguished` (8%)
- [ ] 🔥 Teacher STILL paid full share for the late 3 sessions (no money lost; only tier velocity slowed)

### H3. Cycle reset (settlement)
- [ ] ⚙️ Trigger `recomputeTeacherTiers` on day 1 or day 15 at midnight Cairo time
- [ ] 🔥 Teacher with `premium` tier last cycle → `commissionTier` reset to `starter` for new cycle
- [ ] 🔥 `currentCycleSessions` reset to 0
- [ ] 🔥 `commissionPenaltyPercent` reset to 0
- [ ] 🔥 Settled amount moves from `pendingBalance` → `availableBalance`
- [ ] 🔔 Teacher receives settlement summary notification

### H4. Cycle window
- [ ] 🔥 Sessions completed > 14 days ago do NOT count toward current cycle's tier
- [ ] 🔥 Sessions from previous cycle that were settled don't re-enter pendingBalance

---

## I. Settlement Math

For each scenario, manually compute expected settlement vs actual.

| # | Sessions | Total EGP | Tier earned | Penalty | Expected net | Tests |
|---|---|---|---|---|---|---|
| I1 | 20 on-time | 2000 | Distinguished 8% | 0% | 1840 | [x] 🤖 math [ ] real settlement amount [ ] availableBalance |
| I2 | 20 on-time | 2000 | Distinguished 8% | +1% | 2000 × (1 − 0.09) = 1820 | [x] 🤖 math [ ] real settlement |
| I3 | 7 on-time + 13 late | 2000 | Starter 15% (counter = 7) | 0% | 1700 | [x] 🤖 math [ ] real settlement |
| I4 | 5 on-time | 500 | Starter 15% | +2.5% (cumulative) | 500 × (1 − 0.175) = 412.5 | [x] 🤖 math [ ] real settlement |
| I5 | 50 on-time | 5000 | Elite 5% | 0% | 4750 | [x] 🤖 math [ ] real settlement |
| I6 | Penalty pushes rate ≥ 100% | — | — | — | Cap at 0 net (verify no negative payouts) | [x] 🤖 math |

> 🤖 All six worked examples are covered by `settlement.test.ts`. Bonus tests verify integer-safe piastre rounding (no money lost to rounding errors).

Also:
- [ ] 🔥 After settlement, `pendingBalance` = 0 (all moved or zeroed)
- [ ] 🔥 Settlement doc/log created in `settlements/` (if such a collection exists) for audit

---

## J. Maximum Session Duration (90 min auto-end)

- [ ] 📱 Teacher starts a session, walks away
- [ ] ⚙️ After 90 minutes (configurable), `autoEndOverdueSessions` (or equivalent) ends it
- [ ] 🔥 Session marked `completed`, `completedAt` = auto-end time
- [ ] 🔥 Full price counted to `pendingBalance` (no penalty)
- [ ] 🔥 Counts toward tier (if started on-time)
- [ ] 🔔 Teacher notified that session was auto-ended

---

## K. Late-start Detection (>10 min)

- [ ] 📱 Teacher starts session 9 min after slot start → NOT marked late
- [ ] 📱 Teacher starts session 11 min after slot start → marked `startedLate: true`
- [ ] 🔥 Late session: `startedLate: true`, NOT counted in `currentCycleSessions` counter
- [ ] 🔥 Late session STILL credited full price to `pendingBalance`
- [ ] 📱 Teacher dashboard shows late-session count separately

---

## L. Teacher Withdrawal

- [ ] 📱 Wallet → "طلب سحب رصيد" → enter amount
- [ ] 📱 Reject if amount < 50 EGP
- [ ] 📱 Reject if amount > `availableBalance`
- [ ] 📱 Cannot withdraw `pendingBalance` (UI doesn't include it in withdrawable total)
- [ ] 🔥 Withdrawal request doc created with `status: 'pending'`
- [ ] 🔥 `availableBalance` immediately decremented (or marked reserved)
- [ ] 📱 Admin approves → status `processing` → `completed`
- [ ] 📱 Admin rejects → `availableBalance` restored
- [ ] 🔔 Teacher notified at each state change

---

## M. Rating & Punctuality

- [ ] 📱 Student rates teacher 1–10 after completed session
- [ ] 🔥 `hafizSessions/{id}.teacherRating` written
- [ ] ☁️ `onSessionCompleted` trigger updates teacher's running `rating` average
- [ ] 📱 Punctuality question: "هل بدأت الجلسة في وقتها؟"
- [ ] 🔥 If student answers "no" → session marked `startedLate: true` (alternative path to late detection — verify consistency with server-side timestamp check)
- [ ] 📱 Skipping rating doesn't block payment / settlement

---

## N. Edge Cases & Cross-cutting

- [ ] 🔥 Cancel a session whose payment was via Paymob → refund goes to wallet (not back to card) — per docs
- [ ] 🔥 Cancel a session whose payment was direct (cash) → refund still goes to student's in-app wallet, admin notified to follow up with teacher
- [ ] 🔥 Cancel a bundle/subscription session → bundle session count restored (one credit returned)
- [ ] 📱 Cancel a session past its time slot (status `accepted` but slot ended) → behavior defined (likely auto-completes or blocks cancel)
- [ ] 🔥 Two students simultaneously book the same teacher slot → only one succeeds (race condition check)
- [ ] 🔥 Session with `sessionType: 'online'` but no `meetingLink` → blocked from being started
- [ ] 📱 App offline during payment → graceful retry, no double-charge

---

## O. Notifications Coverage

Verify each event triggers a push + in-app notification:

| Event | Recipient | Tests |
|---|---|---|
| Session booked | Teacher | [ ] |
| Session accepted | Student | [ ] |
| Session cancelled by student | Teacher | [ ] |
| Session cancelled by teacher | Student | [ ] |
| Teacher no-show detected (auto) | Student + Admin | [ ] |
| Refund credited to wallet | Student | [ ] |
| Commission penalty applied | Teacher | [ ] |
| Tier promotion | Teacher | [ ] |
| Tier demotion (after settlement reset) | Teacher | [ ] |
| Settlement complete | Teacher | [ ] |
| Withdrawal status changes | Teacher | [ ] |
| Top-up status changes | Student | [ ] |

---

## P. Admin / Config Toggles

- [ ] 🔥 `systemConfig/global.paymobEnabled = false` → Paymob hidden in student UI
- [ ] 🔥 `systemConfig/global.maintenanceMode = true` → app shows maintenance screen, no booking/payment possible
- [ ] 🔥 Tier thresholds editable in admin panel → next settlement uses new thresholds
- [ ] 🔥 Late-threshold minutes editable → next session uses new value
- [ ] 🔥 Max session duration editable → applies to future sessions

---

## Q. Documentation Consistency

Cross-check that values match across all surfaces (docs, UI banners, dialogs, backend):

- [x] 🤖 Refund tiers (100/50/0) — `cancellationPolicy.test.ts` "Documentation consistency" group
- [x] 🤖 Penalty values (0/0.5/1/1.5) — `cancellationPolicy.test.ts` "Documentation consistency" group
- [x] 🤖 Tier thresholds (0/8/14/20/35) — `settlement.test.ts` "Documentation consistency" group
- [x] 🤖 Tier rates (15/12/10/8/5) — `settlement.test.ts` "Documentation consistency" group
- [x] 🤖 Paymob HMAC field order — `paymobVerification.test.ts` "field order matches Paymob spec"
- [ ] 📝 Refund threshold hours (3h / 1h) — manually verify identical wording in `STUDENT_PAYMENT_GUIDE_AR.md`, cancel banner ([session_details_screen.dart](../packages/mohaffez_mobile/lib/screens/shared/session_details_screen.dart)), cancel dialog, `cancellations/index.ts`
- [ ] 📝 Late threshold: 10 min — in guide and config
- [ ] 📝 Online no-show window: 60 min — in guide, `autoEndOverdueSessions` query
- [ ] 📝 Max session duration: 90 min — in guide and auto-end logic
- [ ] 📝 Min withdrawal: 50 EGP — in guide and UI validation

> 🤖 The automated tests will fail loudly if anyone changes a sentinel value in code without updating both — they act as a contract between the guides and the implementation.

---

## How to use this checklist

1. Work top-to-bottom on **dev** flavor with test Firestore data.
2. For time-dependent tests (cancellation thresholds, no-show auto-detect, settlement), prefer **changing session dates in Firestore** over waiting real time.
3. For settlement, manually invoke `recomputeTeacherTiers` via the Firebase Functions shell or scheduler emulator instead of waiting for day 1/15.
4. Keep dev Firestore seeded with at least: 1 student with wallet balance, 2 teachers (one starter tier, one premium tier), 5 completed sessions, 3 upcoming sessions.
5. After all `[ ]` are `[x]` on dev, repeat critical-path tests (A2, C1–C3, E1–E3, F1, F2, I1, I3) on **prod** with a small live transaction before announcing.
