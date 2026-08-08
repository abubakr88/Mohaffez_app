# Challenge V2 rollout

1. Deploy `firestore.indexes.json` and `firestore.rules`.
2. Deploy `publishSessionChallenge`, `submitSessionChallenge`, and
   `reviewSessionChallenge`.
3. Run the migration in dry-run mode:

   ```powershell
   cd functions
   npm run challenges:migrate:v2
   ```

4. Review the reported bank, overflow, and parent-account counts.
5. Commit the migration explicitly:

   ```powershell
   node lib/scripts/migrateChallengeBanksV2.js --commit
   ```

6. Release the app, then control availability from
   `systemConfig/global.challengeV2Enabled`.
7. Keep legacy question documents during the first release. The migration does
   not delete them.

For parent accounts, questions that cannot be attributed to a child are stored
under `{studentId}__legacy_unassigned`. They are read only when the teacher
explicitly chooses “استيراد” from a child’s bank.

Rollback is performed by setting `challengeV2Enabled` to `false`; no migrated
legacy documents need to be restored because none are deleted.
