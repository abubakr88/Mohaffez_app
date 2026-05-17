# Wallet System

Internal double-entry ledger for all money movements in Mohafezy. Designed as a unifying primitive so payment-provider integration, refunds, promos, and teacher payouts all go through one consistent mechanism.

---

## Why a wallet, not direct payments?

Without a wallet, every money concept (commission, refund, bundle credit, promo, payout) needs its own collection and its own logic. The system fragments fast.

With a wallet:
- Single source of truth per user: `balance = sum of ledger entries`
- Refunds become a credit, not a bank reversal
- Bundles and subscriptions become "wallet credit with constraints"
- Teacher commission is automatic — it lands in `system_revenue` at session-payment time
- Promos/referrals are just system-funded credits
- Payment-provider swap (manual → Paymob → anything else) only touches the top-up entry point; the rest of the app is unaffected

---

## Core principles

1. **Double-entry, always.** Every money movement creates ≥ 2 ledger legs that sum to zero. If they don't, the transaction throws.
2. **Integer piastres.** 1 EGP = 100 piastres. No floats. `egpToPiastres()` is the only place EGP→piastres conversion happens.
3. **Ledger is the source of truth.** `wallets/{id}.balance` is a cached sum. It can always be rebuilt from `walletTransactions where walletId == X`.
4. **User wallets cannot go negative.** System wallets can — negative `system_revenue` means net refunds outweighed earnings (meaningful, not a bug).
5. **All mutations server-side.** Clients have read-only Firestore access to their own wallet/transactions. Every write goes through a Cloud Function inside a Firestore transaction.
6. **Idempotency by `groupId`.** Every operation has a deterministic `groupId` (e.g. `paysession_{sessionRequestId}`, `payout_{payoutRequestId}`). Replaying the same call is a no-op.

---

## Collections

### `wallets/{userId}`

One per user. Doc ID = user UID for direct lookup. System wallets use fixed IDs (`system_revenue`, etc).

```ts
{
  ownerId: string,           // = doc ID
  ownerType: 'student' | 'mohaffez' | 'system',
  balancePiastres: number,   // cached sum; recomputable from walletTransactions
  currency: 'EGP',
  createdAt: Timestamp,
  updatedAt: Timestamp,
}
```

### `walletTransactions/{txId}`

Immutable ledger entries. One row per leg. Same `groupId` ties related legs together.

```ts
{
  groupId: string,           // e.g. 'paysession_abc123'
  walletId: string,          // which wallet this leg affects
  ownerType: 'student' | 'mohaffez' | 'system',
  amountPiastres: number,    // signed: negative = debit, positive = credit
  type: 'topup' | 'session_payment' | 'session_refund' | 'payout' |
        'payout_reversal' | 'promo_credit' | 'adjustment',
  reason: string,
  relatedSessionId: string | null,
  relatedPaymentId: string | null,
  relatedPayoutId: string | null,
  createdBy: string,         // UID of actor, or 'system'
  createdAt: Timestamp,
}
```

### `walletTransactionGroups/{groupId}`

Internal idempotency marker — its existence means "this groupId was already posted." Also stores group-level metadata (overall reason, references).

### `topUpRequests/{id}`

User-submitted "I sent money, here's proof" requests. Created by the client; verified by admin via `verifyWalletTopUp`.

```ts
{
  userId, ownerType, amountEgp, method, referenceNumber, proofUrl,
  status: 'pending' | 'verified' | 'rejected',
  // server-only fields:
  verifiedBy, verifiedAt, verifiedAmountEgp, adminNote, ledgerGroupId,
}
```

### `payoutRequests/{id}`

Teacher-initiated withdrawals. State machine: `requested → processing → completed | failed`.

---

## System wallets

| Wallet ID | Meaning |
|---|---|
| `system_topups` | Mirrors money coming in from outside. Credited (positive) when admin verifies a top-up; debit equals what landed in user wallets. Balance ≈ negative of total real cash in custody. |
| `system_revenue` | Platform commission accrual. Grows on every `session_payment`. Shrinks on refunds. |
| `system_payouts` | Money queued for / sent to teachers via bank. Credited at `startPayout`, drains as `completePayout` happens. |
| `system_promos` | Marketing spend. Debited when admin grants a promo credit. |

**Reconciliation:** `−sum(system_topups) ≈ sum(all user wallets) + sum(system_revenue) + sum(system_payouts) − sum(system_promos)`. If they ever disagree, the ledger is the truth and you have a UI bug somewhere.

---

## Cloud Functions

All in `functions/src/wallet/`.

### Top-up (money in)

- **`verifyWalletTopUp({ topUpRequestId, paidAmountEgp?, adminNote? })`** — admin only. Marks request `verified`, posts: `system_topups -X / user +X`.
- **`adminCreditWallet({ userId, ownerType, amountEgp, reason, type })`** — admin only. Direct credit for promos, manual fixes. Source wallet depends on `type` (`promo_credit` → `system_promos`, otherwise `system_topups`).

### Session payment

- **`payFromWallet({ sessionRequestId })`** — student calls. Reads commission rate from `systemConfig/global`. Posts three legs:
  - student wallet −total
  - teacher wallet +(total − commission)
  - `system_revenue` +commission

  Same transaction: creates `hafizSessions` doc with `paymentType: 'wallet'`, marks request `accepted`, updates weekly commission summary (now informational since commission auto-settles), notifies teacher.

- **`refundSessionPayment({ sessionId, reason })`** — admin only. Reverses the three legs. Marks session `refunded`.

### Payout (money out)

- **`requestPayout({ amountEgp, method, accountDetails })`** — teacher calls. Validates balance ≥ amount. Creates `payoutRequest` with status `requested`. **No ledger movement yet** — balance still shows in-wallet until admin processes.

- **`startPayout({ payoutRequestId })`** — admin only. Moves to `processing`. Posts: teacher wallet −amount, `system_payouts` +amount. Admin now sends the bank transfer offline.

- **`completePayout({ payoutRequestId, bankReference? })`** — admin only. Bank transfer succeeded. Marks `completed`. No ledger change.

- **`failPayout({ payoutRequestId, reason })`** — admin only. Bank transfer failed. Posts reversal: teacher wallet +amount, `system_payouts` −amount. Marks `failed`.

---

## Adding the Flutter layer

Not done yet. Recommended order when adding:

1. `mohaffez_core/lib/src/models/wallet_model.dart` (`@freezed WalletModel`) and `wallet_transaction_model.dart`.
2. `mohaffez_core/lib/src/repositories/wallet_repository.dart` — Firestore reads only; mutations call functions via `FirebaseFunctions.instance.httpsCallable('payFromWallet')`.
3. `mohaffez_core/lib/src/providers/wallet_providers.dart` — `walletProvider(uid)` (StreamProvider), `walletTransactionsPageProvider`, etc.
4. UI screens: top-up screen (student), payout request screen (teacher), admin verify queue.

---

## Migration plan (when going live)

For existing users with `paymentType: 'directpayment'` sessions, no migration needed — wallet payments coexist with direct payments. The wallet is purely additive.

When/if you want to retire direct payments:
1. Force all new session-payment flows through `payFromWallet`.
2. Remove the "send to teacher" option from the booking UI.
3. Keep the direct-payment functions deployed until the last in-flight `directPaymentRequests` resolves.

---

## What's intentionally out of scope (for now)

- **Currency conversion.** Egypt-only launch; `currency: 'EGP'` is hardcoded.
- **Wallet-to-wallet transfers between users.** Not a product requirement; the schema supports it trivially via `postLedgerEntry` if/when needed.
- **Holds / authorized-but-not-captured.** When Paymob is integrated, add a `holds` collection and a `commit_hold` function. Not needed for the manual-transfer flow.
- **Wallet expiry.** Promo credits don't expire in v1. Add an `expiresAt` field on `walletTransactions` if you want time-bombed promos later.
