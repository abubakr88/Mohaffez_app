# Phase B Design Notes — Unifying the Wallet Ledger with Direct-Payment Commission

## Goal

Bring direct-payment commission (currently tracked in `weeklyCommissionSummaries`) into the same wallet ledger that handles online-payment commission. Eventually, a single "محفظتي" screen replaces today's split between "محفظتي" and "مستحقات المنصة" — backed by a single source of truth.

This document captures the architectural decisions made for Phase B step 1 and the followups needed to complete the migration.

---

## Architectural decisions made (step 1)

### 1. Dual-write, don't replace

Direct-payment commission writes happen **twice** for the same event:

| Write | Purpose | When to remove |
|---|---|---|
| `weeklyCommissionSummaries/{teacher_year_week}` (existing) | Backs the current "مستحقات المنصة" screen | Phase B step 4 (cleanup) |
| `walletTransactionGroups/direct_commission_{dpReqId}` + ledger legs (new) | Backs the unified wallet UI (Phase C) and settlement | Always — this is the new source of truth |

Why dual-write: the legacy screen keeps working, no migration of historical data needed, and we can roll back the new behavior by removing the ledger call without touching the legacy display.

### 2. Negative pending balances are allowed for `mohaffez` wallets

`walletUtils.ts` previously rejected any ledger leg that would make a wallet's `pendingCyclePiastres` negative. Direct commission creates exactly this — the teacher's pending bucket goes negative by the commission amount, representing a debt to the platform from a cash session.

Constraint relaxed at [walletUtils.ts:211](../functions/src/wallet/walletUtils.ts#L211): `newPending < 0` is allowed when `ownerType === 'mohaffez'`. The non-negative-available constraint (line 205) is **still in place** — teachers can't withdraw what they don't have.

### 3. Commission posted at confirmation time, not session-completion time

The ledger entry fires inside `mohaffezConfirmDirectPayment` and `confirmBundleDirectPayment`, the moment the teacher confirms receipt of cash. Rationale:
- The teacher has the money in hand — it's the right moment to recognize the platform's claim
- Same trigger as the legacy `weeklyCommissionSummaries` write, so the two systems stay in lock-step
- If the teacher never confirms, no commission is owed (no ghost charges on disputed payments)

### 4. Reversal on cancellation

`onSessionCancelled` ([cancellations/index.ts](../functions/src/cancellations/index.ts)) now reverses the direct-commission entry whenever a direct-payment session is cancelled — regardless of who cancelled or whether a refund was issued. Rationale:
- Commission applies to **sessions that happened**. A cancelled session didn't happen.
- Symmetric and simple — no edge-case business logic about "did the teacher keep some cash so commission should be partial"
- Idempotent via `direct_commission_reversal_{dpReqId}` group id

Note: the legacy `weeklyCommissionSummaries` doc is **not** reversed in the same flow (it never was). This is a known inconsistency between the two ledgers during the dual-write window. After Phase B step 4, the legacy doc goes away and the issue resolves itself.

### 5. New ledger transaction types

Added to `TxType`:
- `direct_session_commission` — initial debit when teacher confirms cash receipt
- `direct_session_commission_reversal` — credit-back when the session is cancelled

Both are 2-leg entries: teacher pending ± commission, system_revenue ∓ commission.

---

## Step 3 (done): settlement drains dues from available

Decision taken: a separate `dues` bucket (not mixed into `pending`).

`WalletDoc` gained a new field `directCommissionOwedPiastres` (≤ 0 when teacher owes). The `LedgerTarget` enum gained a third value `'dues'`. Direct-commission ledger entries now use `target: 'dues'` instead of `target: 'pending'`, so the online-pending bucket stays clean (gross earnings only) and settlement math doesn't get confused.

`settleCycleForTeacher` now runs in two steps:

1. **Online settlement** (unchanged behavior): drain `pending` → `available` net of commission, credit `system_revenue`.
2. **Dues settlement** (new): if `directCommissionOwedPiastres < 0`, drain as much as possible from the teacher's `available` balance (capped to keep available ≥ 0). Remaining debt rolls forward in dues. An `adminAlerts` entry is created if the settlement was partial or fully unsettleable.

This is option **(a)** from the design discussion (roll forward). Option (b) — block payouts when in debt — can be layered on later by checking `directCommissionOwedPiastres < 0` in `requestPayout`.

### Step 4: deprecate `weeklyCommissionSummaries`

Once the unified UI ships and admin metrics are migrated to read from the ledger:
- Stop writing `weeklyCommissionSummaries` in `mohaffezConfirmDirectPayment` and `confirmBundleDirectPayment`
- Migrate the "مستحقات المنصة" screen to read from ledger entries filtered by `type: 'direct_session_commission'`
- Optionally backfill ledger entries for historical `weeklyCommissionSummaries` docs (or accept they only show in the legacy screen until expired)
- Delete `weeklyCommissionSummaries` collection after a retention period

### Step 5: unified UI (Phase C)

Single "محفظتي" screen with:
- Tier card at top
- Available balance (withdrawable)
- Pending this cycle, broken down: online inflow, online commission, direct commission, estimated net at next settlement
- Outstanding dues from prior cycles (if any leftover from step 3 option a)
- "طلب سحب" (disabled if balance ≤ 0)
- "تسوية فورية للمستحقات" optional — for teachers wanting to clear dues before settlement

Old `مستحقات المنصة` route → 301 redirect to wallet with dues section pre-expanded.

---

## Open questions for the next session

1. Step 3 settlement logic (see above)
2. Should past `weeklyCommissionSummaries` records get backfilled into the ledger, or only new ones?
3. UI mockups for Phase C — get user sign-off before building
4. If a teacher disputes a direct-commission ledger entry, what's the admin tooling? (Currently no admin UI for ledger reversals — only the `adjustment` TxType exists)

---

## Test coverage

Phase B logic is currently **not** covered by automated tests. Adding tests requires either:
- A Firestore emulator setup (2hr investment, covers all ledger logic end-to-end)
- Or extracting more of the ledger math into pure helpers (incremental, partial coverage)

Recommended: add emulator tests when starting Phase B step 3, so settlement logic gets verified before deployment.
