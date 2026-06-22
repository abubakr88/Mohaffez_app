# Founding Teacher Badge

## Purpose

The `foundingTeacher` badge is a manual recognition badge for teacher
(`mohaffez`) accounts. It is never assigned automatically.

## Firestore schema

The badge is stored in the teacher's existing `users/{teacherId}` document:

```text
badges.foundingTeacher
  enabled: boolean
  grantedAt: Timestamp
  grantedBy: string
  grantedByName: string
  reason: string | null
  updatedAt: Timestamp
  revokedAt: Timestamp | null
  revokedBy: string | null
  revocationReason: string | null
```

Missing or null `badges` data is treated as an inactive badge, so no migration
is required for existing users.

## Backend operation

Callable function: `setTeacherFoundingBadge`

Input:

```json
{
  "teacherId": "firebase-auth-uid",
  "enabled": true,
  "reason": "Optional internal reason"
}
```

The callable:

- Requires the `manageTeacherBadges` admin permission.
- Verifies the target exists and has role `mohaffez`.
- Rejects deleted accounts and new grants to suspended accounts.
- Trims and limits the internal reason to 500 characters.
- Updates the badge and writes the audit event in one transaction.
- Is idempotent; duplicate grant/revoke calls do not write or audit again.

Audit actions:

- `TEACHER_FOUNDING_BADGE_GRANTED`
- `TEACHER_FOUNDING_BADGE_REVOKED`

## Admin workflow

Open **Admin > Users > User Detail** for a teacher. The account tab contains
the **Badges and Recognition** section. Admins with `manageTeacherBadges` can
grant or revoke the badge after confirmation.

The permission is part of the existing limited-admin permission editor.
Super admins always have it.

## Public display

The reusable `FoundingTeacherBadge` widget is used in:

- Teacher public profile.
- Teacher search result cards.
- Map teacher preview cards.
- Direct booking session summary.
- Teacher's own profile header.
- Admin user list and user-detail preview.

The widget reads the badge from the user document already loaded by each
screen. It does not perform additional Firestore reads.

## Asset

Expected path in both Flutter applications:

```text
assets/badges/founding_teacher_badge.png
```

Until the production PNG is added, `Image.asset` falls back to a gold
`workspace_premium` icon.

## Security rules

Clients cannot create or update the protected `badges` field, including admin
clients. Only the callable function's Admin SDK transaction may change it.

Deploy after review:

```powershell
firebase deploy --only functions:setTeacherFoundingBadge
firebase deploy --only firestore:rules
```

## Local verification

```powershell
cd functions
npm test
npm run build

cd ..\packages\mohaffez_core
flutter test
flutter analyze

cd ..\mohaffez_web
flutter gen-l10n
flutter analyze

cd ..\mohaffez_mobile
flutter analyze
```

No Firestore index is required.
