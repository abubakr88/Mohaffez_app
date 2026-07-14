# Admin Analytics

## Purpose

The admin dashboard uses incremental Firestore projections for marketing,
operations, and finance indicators. New business events add small numeric
deltas instead of repeatedly scanning the complete users, payments, requests,
and sessions collections.

## Data Flow

1. Firestore triggers project user, request, payment, session, wallet-ledger,
   and failed-operation events.
2. `_adminAnalyticsEventReceipts` makes each projected event idempotent.
3. `_adminAnalyticsDailyShards` distributes counters across eight daily shards
   to avoid a single hot document.
4. The hourly aggregation job writes `adminAnalyticsDaily`,
   `adminAnalyticsMonthly`, and the cached `systemConfig/adminInsights` view.
5. Teacher completion counters are stored in `adminTeacherDaily` and rolling
   30/90/365-day summaries in `adminTeacherAnalytics`.

All source-of-truth booking, payment, session, and wallet documents remain
unchanged. The analytics collections are derived data and must not be used to
approve payments or change account balances.

## Cost Controls

- Dashboard reads use cached documents and Firestore count queries.
- Daily counters are sharded, so trigger write contention stays bounded.
- The legacy full-scan admin metrics job runs once per day for compatibility.
- The top-teachers report keeps its historical query until a complete rolling
  window has accumulated, then switches to a ten-document summary query.
- Rolling-window expiration is idempotent and catches up at most 31 missed days
  per scheduled run.

## Historical Data

Incremental indicators start collecting after the functions are deployed.
`projectionStartedAt` records that boundary. Existing legacy metrics continue
to provide historical totals while the new rolling windows mature. No automatic
full-database backfill is performed, avoiding a surprise read bill.

## Security

- `systemConfig/adminInsights` is readable only by admins.
- `adminTeacherAnalytics` is readable only by admins.
- Internal shards, receipts, and daily aggregates have no client access.
- Cloud Functions use the Admin SDK for all projection writes.

## Deployment

From the repository root, deploy the functions and rules to the intended
project explicitly:

```powershell
firebase deploy --only functions,firestore:rules --project <project-id>
```

Then rebuild and deploy the admin web application.

For receipt cleanup, enable a Firestore TTL policy on:

- Collection group: `_adminAnalyticsEventReceipts`
- Timestamp field: `expiresAt`

TTL cleanup is optional for correctness but recommended to cap long-term
storage growth.

## Verification

After deployment:

1. Open the admin dashboard and press refresh once to create
   `systemConfig/adminInsights` immediately.
2. Create a test booking request and move it through acceptance and payment.
3. Confirm the related daily shard changes and the dashboard updates after a
   refresh or the next hourly aggregation.
4. Confirm a non-admin account cannot read `adminInsights` or
   `adminTeacherAnalytics`.
