# Development Demo Seeder

`tools/admin/seed-demo.mjs` provisions synthetic data into **orglink-dev only**. It is an isolated operator tool, never invoked by Flutter or the Worker. It creates no platform administrators, active QR credentials, verification tokens or audit history. The existing small `provision-demo.mjs` retains its original purpose; do not use it to manage these resources.

**Apply and cleanup require explicit project-owner approval before running the commands below.** Implementation and tests do not authorize execution. Dry run needs no credentials, makes no network calls and writes no files.

## Prerequisites

1. Install Node.js 22+ and run `npm.cmd ci` in `tools/admin`. Firebase Admin is reused; Sharp is the only new direct dependency. Its supported platform binary is required. No Flutter dependency is added.
2. For approved execution, provide Application Default Credentials with Firebase Authentication administration and Firestore read/write permissions for **orglink-dev**. If using `GOOGLE_APPLICATION_CREDENTIALS`, its JSON must declare `project_id: orglink-dev` and be stored **outside the repository**. ADC/workload identity is also supported; the target project remains fixed. Never copy administrative credentials into Flutter.
3. Load `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET` into the operator environment from an approved secret store. Use the existing development cloud, with upload, Admin resource inspection and destroy permissions. See [Cloudinary setup](cloudinary-setup.md) for dynamic folder configuration. The tool does not retrieve Wrangler secrets, read `.dev.vars`, configure folders or deploy anything. Never paste secrets into command history or documentation.
4. Set `ORGLINK_DEMO_PASSWORD` via the secret store to a dedicated demo password of at least 12 characters. It is used for new accounts only, never printed, saved or reset on reruns. Firebase email/password sign-in must already be enabled to log in through the app. Reserved `@orglink.example` addresses intentionally cannot receive mail or use real Google sign-in. Auth email verification is set by trusted fixture provisioning.
5. Unset `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` for this project-only CLI. Tests inject in-memory adapters instead of connecting to services.
6. Allow outbound HTTPS to `raw.githubusercontent.com`, Firebase/Google APIs and `api.cloudinary.com`. There is no paid image API. Operations consume existing Firebase/Cloudinary quotas; the tool does not enable billing.

## Exact Commands

From the repository root in PowerShell, preview without credentials or writes:

```powershell
node tools/admin/seed-demo.mjs dry-run --project orglink-dev --seed campus-demo
```

The JSON includes accounts, organizations, memberships, events, registrations, attendance, images, dimensions, source URLs and license identifiers. Optional `--now 2026-10-29T06:00:00Z` makes a reproducible preview. Do not use a stale preview date for a later demonstration.

**After explicit approval**, with credentials loaded, apply:

```powershell
node tools/admin/seed-demo.mjs apply --project orglink-dev --confirm-project orglink-dev --seed campus-demo --manifest .orglink-demo/campus-demo.json
```

Repeat that exact command to resume or verify the seed. Existing accounts/passwords and attached assets are reused. A missing asset is regenerated and verified. The manifest freezes the first apply's anchor time and dimensions; dry runs before first apply do not freeze anything. Normally omit `--now`.

**After explicit cleanup approval**, stop demonstration activity and run:

```powershell
node tools/admin/seed-demo.mjs cleanup --project orglink-dev --confirm-project orglink-dev --seed campus-demo --manifest .orglink-demo/campus-demo.json
```

Cleanup requires the original manifest and matching seed. Another manifest cannot adopt resources. A cleaned manifest cannot be applied again; use a fresh seed/manifest for another current-date demonstration. Dry run previews fixtures, not remote drift. Cleanup performs its own remote ownership/drift preflight.

## Dataset and Schema

| Resource | Contents |
| --- | --- |
| Accounts/profiles | 20 fictional Philippine names and unique 10-digit Student IDs; 16 active, 1 pending, 1 suspended, 1 disabled, 1 rejected |
| Organizations | 5 active fictional organizations, each named `Demo`, with distinct missions/goals and assigned managers; 4 public, 1 private |
| Memberships | 36, including active, pending, rejected and removed examples |
| Officers | 8 organization assignments across 5 distinct students, with varied event/attendance/roster permissions |
| Events | 20: 6 past completed, 2 ongoing approved/published, 8 upcoming approved/published, 4 other (editable draft, submitted draft, rejected draft, cancelled previously published event) |
| Registrations | 42: 40 registered, 2 withdrawn; accurate counters below capacity |
| Attendance | 20 synthetic manual present/absent results for registered active participants |
| Images | 45: 20 generated fictional avatars, 5 composed logos, 20 landscape icon-based posters |

All platform roles are `user`. Organization authority uses the existing `managerUid`; membership roles and granular permission keys match the app. `studentIds/{studentNumber}` is reserved using create-only ownership checks. A conflicting ID stops execution. Program labels match `AcademicOptions`. Participant identity snapshots accompany registrations and withdrawals. No incompatible marker fields are added to application documents.

Dates are relative to the first apply's UTC instant. Past events start 24–9 days earlier; ongoing windows span two hours before/after the anchor; upcoming registration is open. Membership, registration, publication, approval and completion timestamps follow the historical sequence. Attendance timestamps fall within event windows, with another authorized manager as verifier. Completed-event attendance represents synthetic history recorded before completion; the tool does not submit backdated client attendance or fabricate QR/audit evidence. All snapshots are explicitly trusted Admin SDK fixture imports.

## Images and Licenses

Avatars are original illustrations, not photos of real people. Logos and posters download theme-matched icons from [Lucide 0.468.0](https://github.com/lucide-icons/lucide/tree/0.468.0/icons), compose distinct backgrounds/title overlays, resize/crop and optimize PNGs using Sharp. This meets image sourcing through an open icon collection without scraping, paid APIs or manual downloads.

The tool verifies pinned SHA-256 checksums for the [Lucide ISC notice](https://raw.githubusercontent.com/lucide-icons/lucide/0.468.0/LICENSE) and [Feather MIT notice](https://raw.githubusercontent.com/feathericons/feather/v4.29.2/LICENSE), retaining both for inherited portions. Copies are in `tools/admin/demo/licenses/`. Original composition/fallback artwork is dedicated to CC0-1.0. Unavailable sources, unsafe SVG or failed license verification produce an explicitly marked original graphic, never an unverified licensed image.

Per-image manifest metadata retains source URL/checksum, full notices, attribution, retrieval time, fallback reason, output checksum/format/size/dimensions. PNG EXIF contains attribution/provenance before upload. **Keep the manifest and license notices with demo exports/distributions:** provider transformations/downloads may strip embedded metadata.

Profiles/logos are 768×768. Existing posters have responsive widths with fixed heights: detail 184 dp, featured 174 dp. There is no universal ratio for every device/slot. The default **1380×736 (15:8)** matches a 345×184 detail slot at a 393 dp phone width after 24 dp side margins. Optional first-apply `--viewport 412` targets another detail width using `min(viewport, 960) - 48`; featured slots still crop differently. App layouts remain unchanged.

Each PNG is checked for expected dimensions and the **5 MiB** limit. Cloudinary applies the existing 2048-pixel bound. Uploads reuse the Worker's signature function, public-ID shape, URL/public-ID fields and `imageRevision` convention. Collision-resistant IDs hash the random manifest owner plus resource path. Signed dynamic `asset_folder` values are:

- `orglink/profiles`: `photoURL` / `photoPublicId` on users.
- `orglink/organizations`: `logoURL` / `logoPublicId` on organizations.
- `orglink/events`: `posterURL` / `posterPublicId` on nested events.

Signed ownership context and `overwrite=false` prevent foreign assignment/replacement. Independent Admin inspection verifies public ID, folder, ownership, URL, type, format, dimensions and size before storing references. Cleanup destroys exact verified public IDs. No existing image reference is migrated, and the authenticated application upload flow is unchanged.

## Ownership, Resume and Cleanup

The ignored `.orglink-demo/` directory contains manifest, source cache and process lock. Back it up privately: it contains synthetic identifiers, ownership and provenance, but no passwords/API secrets. Files use restrictive modes where supported; use user-only directory ACLs on Windows if needed. Exclude any custom manifest directory from source control too.

A server-private `_demoSeeds/{seed}/resources/{pathHash}` ledger stores ownership and canonical document hashes. Existing catch-all Rules already deny client access; no Rules change is needed. Transactions repeat ownership/hash checks before writes/deletes. Auth's inert `orglinkDemoOwner` claim grants no privileges. Accounts start disabled and are enabled according to profile status only after complete provisioning. A temporary creation marker permits recovery if Auth creation stops before claim assignment. Reruns do not disable existing usable accounts.

Checkpoints precede uploads and follow operations. Bounded retries handle transient Cloudinary/source failures. Lost upload responses are reconciled through inspection, without repeating multipart uploads or overwriting. Firestore transactions use SDK retries; other failures stop with checkpoints intact. Resume with the original command/manifest. Provider response bodies and credentials are withheld from logs.

Cleanup checks all planned records/accounts/tracked assets first. It refuses externally modified fixtures, foreign child documents and non-demo organizations assigned to demo managers. It removes only explicit owned document paths (deepest first), exact verified assets and matching Auth accounts; no recursive collection deletion is used. Partial deletion is resumable. Avoid concurrent app edits while applying/cleaning: the tool is for isolated fixtures and does not scan every arbitrary external reference in the database.

A crash intentionally leaves a `.lock` file. Verify no seeder process is running, preserve the manifest, then manually remove **only that exact lock** before resuming. Never discard ownership records to bypass collisions/drift. App-edited fixture content blocks cleanup; review and reconcile known demo changes rather than forcing deletion or changing ownership hashes.

## Testing and Verification

Local tests do not contact Firebase/Cloudinary and use real Sharp PNG processing:

```powershell
Push-Location tools/admin
npm.cmd ci
npm.cmd test
Pop-Location
dart format .
flutter analyze
flutter test
```

Coverage includes dataset counts, Student ID uniqueness, relationships/private membership, lifecycle distribution, counters/withdrawals, attendance windows/verifiers, image ratios/limits/license verification/fallbacks, source restrictions, signed folders, forged assets, idempotency, interrupted uploads/deletion and refusal to overwrite/clean unrelated data. Live credentials, service quotas and actual API behavior still require an approved development execution.

After approved apply, check manifest `state: complete`, then verify through the app: account-status redirects; organization visibility/roster permissions; Upcoming/Ongoing/Past/All, My Events and Home; participant/attendance lists; draft approval and officer permissions. Seeded accounts cannot access Platform Admin; use an independently authorized existing administrator. QR features require their normal authorized session generation and have no seeded secrets. Check Cloudinary folder placement and matching URL/public-ID fields.

Troubleshooting:

- Configuration/permission failure: check fixed project, ADC and Cloudinary binding names/permissions without publishing secrets.
- Collision/modified record: preserve manifest and data; investigate or choose a fresh seed for first provisioning. Do not force adoption.
- Source/license failure: inspect marked original fallback metadata. Existing attached assets intentionally remain reused.
- Quota/rate limit: wait and resume the same command; do not run concurrent seeders.
- Sharp unavailable: reinstall for supported Node/platform architecture; do not disable validation.
- Aged dataset: retain its frozen anchor for idempotency; request cleanup approval and use a fresh seed for another demonstration.

## Validation for This Change

Admin tests: 38 passed. Offline dry run: expected counts, no external writes. `dart format .` ran; unrelated existing formatting changes were restored. `flutter analyze`: 3 existing warnings (unused crop preview and two profile imports). Full Flutter suite: 279 passed, 5 existing poster UI/crop failures (same-card placement, three responsive crop cases, Home crop preview). No apply, cleanup, account creation, Cloudinary upload, live Firestore write or deployment was executed.

Dependency audit: the new Sharp dependency uses patched 0.35.5; 8 moderate findings remain in the existing Firebase Admin dependency tree. No unrelated major Firebase SDK migration was performed.

Modified/new files: `.gitignore`, `README.md`, `docs/cloudinary-setup.md`, this guide, `tools/admin/package.json`, `tools/admin/package-lock.json`, `tools/admin/seed-demo.mjs`, and `tools/admin/demo/{dataset,engine,firebase,images}.mjs`, `{dataset,engine,images}.test.mjs`, `licenses/lucide-ISC.txt`, `licenses/feather-MIT.txt`. Flutter, Firebase configuration/Rules and Worker source are unchanged.
