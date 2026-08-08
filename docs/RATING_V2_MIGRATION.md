# Teacher Rating V2 Migration

Teacher Rating V2 counts only session ratings that explicitly contain
`teacherRatingScale: 5`. Older 1–10 and unversioned ratings remain visible to
administrators as historical feedback but do not affect public reputation.

## Dry run

From `functions/`, build and inspect the production summary without writing:

```powershell
npm run ratings:v2 -- --project=mohaffez-ba2ec
```

The command validates that `serviceAccountKey.json` belongs to the requested
project and reports how many teachers will retain a V2 score or reset to
`جديد`.

## Apply

After deploying the V2 Cloud Functions and clients, apply the idempotent
rebuild:

```powershell
npm run ratings:v2 -- --project=mohaffez-ba2ec --apply
```

Before any Firestore writes, the script stores the previous teacher aggregates
under `functions/migration_backups/`. Re-running the migration produces the
same aggregate from explicit V2 session ratings.
