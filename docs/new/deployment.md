# Setup, Build, Deployment and Maintenance

Reviewed 30 October 2026 and reused from `docs/setup-and-operations.md` with current build evidence and corrected guide links. This audit performed local tests and bundle/build checks only. The instructions below do not authorize remote actions.

## Current Release Evidence and Gates

`flutter build apk --release --no-pub` passed (76.9 MB APK) using the current default development Worker origin. The merged release manifest includes INTERNET and CAMERA permissions. Release currently uses debug signing and `com.example.orglink`; Google login with the installed certificate remains unverified. The APK is a local build product, not a published release. Kotlin Gradle plugin compatibility warnings were emitted for Firebase plugins; no package upgrade was made.

Root `.firebaserc`, platform Firebase options, Android configuration and Worker token audience all point to `orglink-dev`. The PDF proposes separate prod configuration, but this task explicitly permits only the configured development project. No prod project, flavor or secret was created. Treat this as a development demonstration, not established environment-separated production readiness.

Before presentation record the compatible deployed Worker version, Rules and indexes (ready, not merely declared), Auth providers/OAuth certificates/action-link association, Cloudinary bindings/dynamic folders and cleanup cron. Validate exact HTTPS origin against the app build. None was remotely verified here. Existing Student ID registry adoption may need the separately approved audit/backfill described below; do not blindly run apply commands.

These are operator instructions, not actions performed by reading this guide. OrgLink uses only the configured **orglink-dev** Firebase project. Preserve current configuration and never deploy, provision or migrate without the required project-owner approval.

## Local Development

Use a Flutter SDK that satisfies Dart **^3.12.2**, Android SDK/emulator or device, and the Flutter-recommended Java toolchain. Android compilation targets Java/Kotlin JVM 17 in `android/app/build.gradle.kts`; compile/min/target SDK values come from Flutter rather than hardcoded numbers. Use `flutter doctor` to identify local toolchain gaps. Node.js 22+ is the shared recommended operator/test runtime (including Sharp); Firebase emulator tests require a compatible Java installation and Firebase CLI. Wrangler is installed through the Worker lockfile.

From the repository root:

```powershell
flutter doctor
flutter pub get
npm.cmd ci --prefix workers/attendance
npm.cmd ci --prefix firebase/tests
npm.cmd ci --prefix tools/admin
flutter devices
flutter run --dart-define=ATTENDANCE_API_URL=https://orglink-attendance.orglink-dev.workers.dev
```

Use the actual authorized development Worker origin if different. The default origin in source is not a health check. Firebase options and the root `.firebaserc` target `orglink-dev`. Root `firebase.json` selects `firebase/firebase.rules`, `firebase/firestore.indexes.json`, Firestore emulator port 8080 and Auth emulator port 9099. `firebase/firebase.json` and `firebase/storage.rules` are empty placeholders, **not alternate deployment configurations**. Run Firebase commands from the repository root. Generated platform options exist beyond Android, but this guide does not claim those platforms have been accepted.

### Firebase Authentication Setup

Check the existing development Console rather than creating another project. Enable the intended Google and email/password providers and configure support email, authorized action-link domains and email templates where required; no current Console state is certified here. See [Module 1 manual setup](module1.md) for detailed verification/reset/linking acceptance.

Keep `android/app/google-services.json` canonical. A historical duplicate under `android/app/src/` caused missing generated OAuth resources; do not restore it casually. Android application ID is `com.example.orglink`. Verify OAuth Android package/certificate registration for the actual signing key, and ensure the web OAuth client produces `default_web_client_id`. Do not copy a developer's debug SHA into a release configuration without checking its actual certificate. Use `android/gradlew.bat signingReport` from a suitable working directory or the Gradle wrapper in `android`; rebuild natively after configuration changes. Hot reload cannot refresh native resources.

### Worker Secrets and Configuration

Required bindings:

| Binding | Purpose |
| --- | --- |
| `FIREBASE_SERVICE_ACCOUNT` | Development service-account JSON used to obtain Google access tokens for Firestore REST |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary development product environment |
| `CLOUDINARY_API_KEY` | Upload/Admin API identity |
| `CLOUDINARY_API_SECRET` | Cloudinary signing, image-ticket HMAC and privileged asset operations |

Keep administrative JSON outside the repository. Use interactive Wrangler prompts or an approved secret manager; never pass secret contents as shell arguments or print them. From `workers/attendance`, **only when secret configuration is authorized**:

```powershell
npx.cmd wrangler secret put FIREBASE_SERVICE_ACCOUNT
npx.cmd wrangler secret put CLOUDINARY_CLOUD_NAME
npx.cmd wrangler secret put CLOUDINARY_API_KEY
npx.cmd wrangler secret put CLOUDINARY_API_SECRET
```

These commands change remote bindings. Do not rerun merely to test documentation. For local Worker development, an ignored `.dev.vars` may provide the same names; never commit it. The Worker allows a loopback `FIRESTORE_EMULATOR_HOST` for its test adapter; that is not a supported production binding. The Flutter app does not have a general automatic Auth/Firestore emulator switch in `main.dart`; do not assume a debug build is isolated from live services.

Cloudinary must use dynamic folders. Uploads supply signed `asset_folder` values for profiles, organizations and events; no dashboard folder creation or asset migration is needed. API permissions must support authenticated image upload, Admin inspection and destroy. [Image setup](../cloudinary-setup.md#manual-setup) explains private queues, public delivery, retry and optional tombstone retention. Do not enable TTL on upload `expiresAt`.

## Validation Commands

```powershell
flutter analyze
flutter test
npm.cmd test --prefix workers/attendance
npm.cmd test --prefix tools/admin
```

For isolated Firebase rules/Auth tests, start from a clean emulator environment, free ports 8080/9099 and the repository root:

```powershell
firebase.cmd emulators:exec --project orglink-dev --only firestore,auth "npm.cmd --prefix firebase/tests test"
```

This uses synthetic local emulator data, not a live integration. `tools/test-firestore.ps1` is a narrower Windows runner for profile/org/event/image Rules and sample provisioning; it does not run every suite in `firebase/tests/package.json`. Worker emulator suites are separate scripts: `test:emulator`, `test:student-id:emulator`, `test:admin:emulator`, `test:images:emulator`. Review their environment guards and run inside the appropriate emulator invocation. See [current QA](v1-audit-report.md) for what was actually rerun during handover. Do not interpret a test script's presence as a passing result.

## Build and Manual Release

```powershell
flutter build apk --debug --dart-define=ATTENDANCE_API_URL=https://orglink-attendance.orglink-dev.workers.dev
```

Expected Flutter debug output: `build/app/outputs/flutter-apk/app-debug.apk`. This debug command is a setup instruction, not a newly executed debug build. The audit executed flutter build apk --release --no-pub successfully; see the audit report. No APK was installed. For distribution, the current `release` build type uses the **debug signing config** and package `com.example.orglink`. A proper release keystore, signing policy and corresponding OAuth fingerprints require separately approved configuration work. A successful `flutter build apk --release` with today's config is not a production release certification. Preserve keystores/passwords outside source control.

Before an authorized backend release:

1. Record the reviewed commit, current deployed Worker version, Rules/index state and configuration owners. Back up data according to project policy; do not export student data into Git.
2. Run local/unit and isolated emulator checks; resolve or explicitly accept known warnings and manual acceptance gaps.
3. Check ADC/service-account project/IAM and secrets privately. For Student ID adoption, coordinate any write freeze and approved [audit/backfill](../student-id-cutover.md); an audit is a live read and backfill is a separate live write operation.
4. From repository root, deploy the reviewed Rules/index declarations, then the compatible Worker and app in a coordinated change window. Index building and cross-version client compatibility must be checked; strict new Rules may reject older clients that omit identity projections.

```powershell
# Execute only after deployment approval.
firebase.cmd deploy --project orglink-dev --only firestore:rules,firestore:indexes
Push-Location workers/attendance
npm.cmd run check
npx.cmd wrangler deploy
Pop-Location
```

`npm run check` invokes Wrangler **deploy --dry-run**, which bundles locally; it does not prove remote deployment. Secret configuration is a separate authorized remote action. Verify the Workers cron `*/15 * * * *` is enabled and the returned origin matches the app. Do not enable Workers observability or make billing changes implicitly. Validate actual deployed endpoints and signed asset flow with authorized demo accounts; do not use real student credentials for screenshots or test fixtures.

Use [Platform Admin bootstrap](platform-admin.md#administrator-bootstrap) for the first administrator. Do not substitute raw Console role edits or hardcoded privileged UIDs for that verified operator procedure. Use [demo seeder](../demo-seeder.md) for a clearly fictional dataset only after explicit apply approval; its offline dry run is safe without service credentials. Seeder credentials additionally require ADC and `ORGLINK_DEMO_PASSWORD`; they are not Flutter/Worker bindings.

## Maintenance and Recovery

- Keep source, lockfiles, Rules, indexes and app/Worker versions together in reviews. Run appropriate tests after dependency updates; source constraints alone are not a security audit. Recheck dependency advisories before release rather than relying on old counts.
- Investigate sanitized stage/reason failures locally. Never log tokens, Cloudinary signatures, password/action codes, service-account JSON, private profile dumps or full request bodies. Worker observability is currently disabled; a logging call in code does not guarantee stored production logs.
- Image cleanup handles bounded batches of 50 expired sessions and 50 queued assets per run. Replaced assets wait at least one minute; failed upload sessions are inspected after expiry plus one hour. Backlogs/credentials/quota errors require operator attention. Optional TTL removes retired tombstones only after approved policy setup; it does not delete Cloudinary assets.
- QR expiry is enforced at verification time regardless of retention. The image cron is not general QR/audit cleanup. Define retention/access policies for attendance corrections, activity logs, private registry and demo manifests before larger use.
- Reconcile uncertain mutations before retrying with a new operation ID. Admin requests, image tickets, document revisions and demo ownership manifests have different retry semantics; follow the owning guide.
- Do not delete live referenced images or recursive Firestore trees as a recovery shortcut. Seeder cleanup requires its original manifest and ownership checks; modified records intentionally stop cleanup.
- Roll back only to reviewed compatible releases. Never weaken authorization to recover a UI error. A Rules rollback can reopen formerly allowed writes, so preserve the Student ID registry and review every affected client path before changing enforcement.
- Before handover, record actual remote versions, test date/commands, configured provider owners, signing-key custodian and manual device acceptance in a private operations record. No secrets belong in Markdown.

