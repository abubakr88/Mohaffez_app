# Al-Mohaffez (المحفظ)

A Flutter platform connecting students with Quran teachers (mohaffezeen) for in-person, mosque, or online memorization sessions. The UI is Arabic-only (RTL).

**Roles:** student, mohaffez (teacher), admin.

---

## Repository layout (monorepo)

```
.
├── packages/
│   ├── mohaffez_core/      # Shared models, repositories, providers, utilities
│   ├── mohaffez_mobile/    # Flutter Android/iOS app
│   └── mohaffez_web/       # Flutter web app (admin + teacher dashboards)
├── functions/              # Firebase Cloud Functions (TypeScript)
├── marketing_site/         # Static marketing site (mohafezy.com)
├── docs/                   # SRD, cost analysis, audits
├── scripts/                # Sync / publish PowerShell scripts
└── .github/workflows/      # CI/CD (GitHub Actions)
```

The repo uses [Melos](https://melos.invertase.dev/) for managing the workspace.

---

## Documentation

| Doc | What it covers |
|-----|----------------|
| [CLAUDE.md](CLAUDE.md) | Architecture, conventions, commands (also used by AI tools) |
| [RELEASE.md](RELEASE.md) | Branch model, CI/CD flow, how to ship to dev / prod |
| [docs/SOFTWARE_REQUIREMENTS_DOCUMENT.md](docs/SOFTWARE_REQUIREMENTS_DOCUMENT.md) | Full SRD (features, roles, flows) |
| [docs/cost_analysis_post_launch.md](docs/cost_analysis_post_launch.md) | Firebase cost projections |
| [docs/firebase_cost_audit.md](docs/firebase_cost_audit.md) | Firebase cost optimization audit |
| [PRIVACY_POLICY.md](PRIVACY_POLICY.md) | Privacy policy (Arabic) |
| [packages/mohaffez_web/README.md](packages/mohaffez_web/README.md) | Web-app specific build/deploy notes |
| [marketing_site/README.md](marketing_site/README.md) | Marketing site notes |

---

## Environments

| Environment | Firebase project   | Web URL                         |
|-------------|--------------------|---------------------------------|
| Development | `mohaffez-dev`     | (deployed by GitHub Actions)    |
| Production  | `mohaffez-ba2ec`   | `app.mohafezy.com` / `mohafezy.com` |

Mobile app flavors: `dev` flavor → `mohaffez-dev`, `prod` flavor → `mohaffez-ba2ec`. Dev installs alongside prod (`app.mohafezy.dev` vs `app.mohafezy`).

---

## Quick start

```bash
# Install Melos and bootstrap workspace
dart pub global activate melos
melos bootstrap

# Run mobile (dev flavor — uses VS Code launch config)
# F5 in VS Code → "mohaffez_mobile (dev)"

# Run web
cd packages/mohaffez_web
flutter run -d chrome

# Cloud Functions
cd functions
npm install
npm run build
```

See [CLAUDE.md](CLAUDE.md) for the full command reference, and [RELEASE.md](RELEASE.md) for how releases work.

---

## Required local files (never committed)

| File | Purpose |
|------|---------|
| `.env` | `GOOGLE_MAPS_API_KEY` and other dart-define secrets |
| `packages/mohaffez_mobile/android/key.properties` | Release signing config |
| `packages/mohaffez_mobile/lib/firebase_options.dart` | Prod Firebase config (FlutterFire CLI generated) |
| `functions/serviceAccountKey.json` | Firebase Admin SDK key |
