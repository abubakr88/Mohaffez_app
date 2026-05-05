# Release Process

This project uses a **branch-based deploy model**. The branch your code is on
decides which Firebase project it gets deployed to. You never type a project
ID by hand — git decides.

| Branch     | Firebase project   | Deployed automatically? |
| ---------- | ------------------ | ----------------------- |
| `develop`  | `mohaffez-dev`     | Yes (on push)           |
| `main`     | `mohaffez-ba2ec`   | Yes (with approval)     |
| `feature/*`| nothing            | No                      |

---

## One-time setup

Done once, ever — skip if already configured.

### 1. Create the `develop` branch

```bash
git checkout -b develop
git push -u origin develop
```

### 2. Configure GitHub secrets

In **GitHub repo → Settings → Secrets and variables → Actions**, add:

| Secret name                       | Value                                                       |
| --------------------------------- | ----------------------------------------------------------- |
| `FIREBASE_SERVICE_ACCOUNT`        | JSON service account key for **mohaffez-ba2ec** (prod)      |
| `FIREBASE_SERVICE_ACCOUNT_DEV`    | JSON service account key for **mohaffez-dev** (dev)         |
| `SENTRY_DSN`                      | (already set — used by web build)                           |

To generate a service account key:
Firebase Console → Project Settings → Service accounts → Generate new private key
→ paste the entire JSON contents into the GitHub secret.

### 3. Configure the `production` environment with manual approval

GitHub repo → **Settings → Environments → New environment** → name `production`.
Then enable **Required reviewers** and add yourself. This adds a "click to
approve" gate before any prod deploy actually runs.

Repeat for an environment named `development` (no required reviewers — auto-approve).

### 4. Branch protection for `main`

GitHub repo → **Settings → Branches → Add rule** for `main`:
- Require pull request reviews before merging
- Require status checks to pass

This stops anyone (including you) from pushing directly to `main`.

---

## Day-to-day flow

### A. Working on a feature

```bash
git checkout develop
git pull
git checkout -b feature/my-thing
# ... write code, commit ...
git push -u origin feature/my-thing
```

Open a PR: `feature/my-thing` → `develop`. Review, merge.

**On merge to `develop`** → GitHub Actions auto-deploys backend + web to
`mohaffez-dev`. Open the dev app and verify your change works against
real-ish data.

### B. Releasing to production

When `develop` is stable and tested:

```bash
git checkout main
git pull
git merge --no-ff develop
git push
```

Or open a PR `develop` → `main` and merge through the UI (recommended —
gives you a release-style review of the full diff).

**On merge to `main`** → GitHub Actions queues a prod deploy. You'll see a
yellow "Waiting for review" banner on the workflow run. Click **Review
deployments → Approve and deploy**. Backend deploys to `mohaffez-ba2ec`.

Web hosting also auto-deploys via `web_deploy.yml` (path-filtered to web
changes only).

### C. Mobile app release (Play Store / App Store)

The CI pipeline does NOT publish mobile binaries — those go through the
stores manually:

```powershell
./build_release_aab.bat   # Android — upload to Play Console
./build_release_apk.bat   # Android — for direct distribution / testing
```

iOS releases use Xcode → Archive → Upload to App Store Connect.

The mobile app talks to whichever Firebase project its flavor was built
with (`dev` flavor → mohaffez-dev, `prod` flavor → mohaffez-ba2ec). The
release builds always use the prod flavor.

---

## Manual operations (rare)

### Refresh dev with latest prod data

When dev's data has drifted from reality and you want fresh prod data:

```powershell
pwsh ./scripts/sync_prod_to_dev.ps1
```

This exports prod Firestore, copies it to a regional dev bucket, and imports
it into dev. Auth users are NOT copied (would need password hashes).

### Emergency manual deploy

If GitHub Actions is down or you need to deploy fast:

```bash
firebase use prod
firebase deploy --only firestore:rules,firestore:indexes,storage,functions

firebase use dev
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

But avoid this — it bypasses the approval gate and isn't logged in Actions.

---

## Rolling back a bad prod release

```bash
git revert <commit-sha>   # creates a new commit that undoes it
git push                   # triggers a new prod deploy
```

For Firestore data corruption (not a code bug), restore from the most recent
export in `gs://mohaffez-ba2ec.firebasestorage.app/exports/`.

---

## Pre-release checklist

Before merging `develop` → `main`:

- [ ] All features work in dev app (`https://mohaffez-dev.web.app` or dev mobile flavor)
- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes
- [ ] Cloud Function changes have been smoke-tested in dev
- [ ] Firestore rule changes have been tested in dev (no permission regressions)
- [ ] Index changes have finished building in dev (Firestore Console → Indexes)
- [ ] No `.env` / secret values are committed
- [ ] Mobile app version code/name bumped in `pubspec.yaml` if releasing a new mobile build
