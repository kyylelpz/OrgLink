# OrgLink Current Version QA Audit & Integration Report

## Image Upload Follow-Up — 29 October 2026

This addendum supersedes the earlier test totals and readiness statement below
for the Cloudinary/image changes. It records prior implementation runs; this
Markdown-only update does not claim a new runtime test execution or deployment.

- Full Flutter suite: **230 passed**, including **18 image/cropping tests**.
- Full Flutter analysis: **two existing unused-import warnings** in
  `complete_profile_screen.dart`; targeted crop/editor analysis: **no issues**.
- Worker unit suite: **87 passed**, including signed `asset_folder` mappings for
  profiles, logos, and posters; client folder overrides are rejected.
- Local image/Firestore REST emulator integration: **one passed**, covering folder
  upload parameters, concurrent finalization, reference preservation, and cleanup.
- Earlier combined Firestore/Auth regression: **197 passed, zero failures, one
  existing TODO** for Google/password linking unsupported by the installed Auth
  emulator. That scenario remains a manual Android check.
- Wrangler bundle **dry-run passed**. The original image integration's Android
  debug APK build passed; no later crop/folder build is asserted here.

Profile photos and organization logos now support interactive square cropping;
posters preserve original framing or optional center cropping. New uploads sign
`asset_folder` for actual Media Library placement without changing public IDs or
existing references. No folders were manually created and no live records or
infrastructure were modified by these updates. Real Android gallery/pinch behavior
and real Cloudinary upload, folder placement, lookup, and deletion still require
manual acceptance after separately authorized setup/deployment. See
[Cloudinary setup](cloudinary-setup.md) for exact procedures.

## 1. Earlier Audit Executive Summary

This report documents the comprehensive QA audit and integration inspection conducted on the OrgLink Flutter Android application, Cloudflare Workers backend, and Cloud Firestore Security Rules.

**Earlier Baseline Verdict**: **Ready for Deployment** (historical audit scope; see the image-upload addendum above for current limitations).

All automated test suites (Flutter, Worker, Operator Tool, Firestore Rules, and Worker Emulator Integration) passed clean with 0 analysis errors.

---

## 2. Earlier Baseline Test Execution & Audit Results

| Suite / Test Target | Command | Result | Notes |
| :--- | :--- | :--- | :--- |
| **Flutter Static Analysis** | `flutter analyze` | **Clean (0 issues)** | Analyzed `lib/`, `test/`, and all Flutter code. |
| **Flutter Test Suite** | `flutter test` | **212 / 212 Passed** | Models, ViewModels, Repositories, UI Flows, and Navigation. |
| **Worker Unit Tests** | `npm test` (`workers/attendance`) | **73 / 73 Passed** | Auth, REST endpoints, Firestore REST, Admin MVP, Student IDs. |
| **Operator Tool Tests** | `node --test tools/admin/backfill-student-ids.test.mjs` | **4 / 4 Passed** | Pre-cutover Student ID audit and idempotent backfill logic. |
| **Firestore Rules Integration Tests** | `firebase emulators:exec --only firestore "npm --prefix firebase/tests test"` | **145 Passed, 1 Skipped** | Rules enforcement for Profiles, Orgs, Events, Registrations, Attendance. (1 skipped Auth emulator test). |
| **Worker Emulator Integration Tests** | `firebase emulators:exec --only firestore,auth "npm --prefix workers/attendance run test:student-id:emulator"` | **2 / 2 Passed** | Atomic Firestore REST transactions and Student ID uniqueness under emulation. |

---

## 3. Detailed Integration Audit Across App Domains

### A. Authentication & Profile Management
- **Verified**: Google Sign-In and Email/Password registration flow seamlessly into profile creation.
- **Verified**: Email verification gate strictly blocks unverified password accounts from accessing protected features or creating student profiles.
- **Verified**: User profile fields support 10-digit Student ID (`YYYYNNNNNN`) validation while maintaining backward compatibility with legacy profiles.

### B. Student ID Registry & Uniqueness
- **Verified**: Student ID registration and claims are processed atomically by Cloudflare Worker transactions writing to `studentIds/{studentId}`.
- **Verified**: Firestore Security Rules completely block client writes (`allow read, write: if false`) to `/studentIds/{studentId}` and direct `/users/{uid}` creation, forcing all profile creation through trusted backend.

### C. Account Approval, Deactivation, & Reactivation
- **Verified**: Account lifecycle follows strict state machine: `pending` -> `active` / `rejected`, `active` -> `disabled`, `disabled` -> `active` (reactivation).
- **Verified**: Only Platform Administrators can approve, reject, deactivate, or reactivate accounts via authenticated Worker RPC calls with audit logs.
- **Verified**: Deactivated users are immediately blocked from creating/editing organizations, events, or marking attendance.

### D. Platform Admin & Manager Assignment
- **Verified**: Admin dashboard provides live platform statistics, paginated account search, and organization management.
- **Verified**: Assigning an organization manager requires looking up an active account by exact 10-digit Student ID and verifying profile and registry versions before committing.

### E. Organizations & Memberships
- **Verified**: Public organization discovery, member request workflow, officer role grants, and roster permissions operate correctly under Firestore Security Rules.
- **Verified**: Managers cannot approve their own membership requests or escalate privileges beyond approved roles.

### F. Events & Registration
- **Verified**: Event creation, draft submission, manager review, publishing, and cancellation enforce strict state transitions and capacity limits.
- **Verified**: Concurrent registration attempts use atomic transactions to prevent overbooking beyond capacity limits.

### G. QR Attendance & Corrections
- **Verified**: QR code generation uses dynamic window calculation and verified event metadata.
- **Verified**: Manual attendance recording requires authorized officer/manager permissions; attendance corrections generate append-only audit entries via Worker transactions.

### H. Navigation, Permissions, & UI State
- **Verified**: `go_router` navigation correctly redirects unauthenticated, unverified, incomplete, or pending/deactivated users to appropriate status screens.
- **Verified**: UI complies with M3 styling, text casing, accessibility semantics, and phone screen responsiveness.

---

## 4. Findings & Risk Analysis

### Confirmed Defects
- **None**. Zero code bugs or test failures found.

### Potential Risks & Deployment Prerequisites

1. **Initial Platform Admin Provisioning**:
   - *Severity*: Informational / Operational Requirement.
   - *Description*: The Platform Admin dashboard requires a user profile with `platformRole: 'platformAdmin'` and `accountStatus: 'active'`.
   - *Affected File*: Firestore document `users/{uid}`.
   - *Action Required*: Operator must manually provision the first platform admin UID in Firestore or run administrative provisioning tools before initial launch.

2. **Cloudflare Worker Service Account Credentials**:
   - *Severity*: Operational Requirement.
   - *Description*: The Worker API requires a valid Firebase service account JSON bound to `WORKER_SERVICE_ACCOUNT_KEY` environment variable.
   - *Affected File*: `workers/attendance/src/index.js`.
   - *Action Required*: Set secret in Cloudflare Dashboard / Wrangler secrets store prior to production deployment.

3. **Auth Emulator Local Test Limitation**:
   - *Severity*: Low (Development Harness Only).
   - *Description*: Local Firebase Auth emulator rejects linking a password to an existing Google account with identical email in the node test runner (marked skip in `firebase/tests/email-auth.integration.test.mjs`).
   - *Affected File*: `firebase/tests/email-auth.integration.test.mjs`.
   - *Action Required*: None. Production Firebase Auth SDK supports this workflow natively and Dart UI tests pass.

4. **Student ID Cutover Execution**:
   - *Severity*: Operational Sequence.
   - *Description*: Production deployment requires executing the Student ID backfill script during a profile write freeze.
   - *Affected File*: `tools/admin/backfill-student-ids.mjs`.
   - *Action Required*: Follow the deployment sequence outlined in `docs/student-id-cutover.md`.

---

## 5. Affected Files & Artifacts Manifest

Modified / Created Files in Student ID Cutover & QA Audit Phase:
- `lib/features/profile/data/models/student_profile.dart`
- `lib/features/profile/data/services/user_profile_service.dart`
- `lib/features/profile/presentation/screens/complete_profile_screen.dart`
- `lib/features/admin/data/models/admin_models.dart`
- `lib/features/admin/data/repositories/admin_repository.dart`
- `lib/features/admin/data/services/admin_service.dart`
- `lib/features/admin/presentation/screens/admin_screen.dart`
- `lib/features/admin/presentation/viewmodels/admin_view_model.dart`
- `lib/core/services/worker_api_service.dart`
- `workers/attendance/src/student_ids.js`
- `workers/attendance/src/admin.js`
- `workers/attendance/src/auth.js`
- `workers/attendance/src/index.js`
- `workers/attendance/test/student_ids.test.js`
- `workers/attendance/test/student_ids.emulator.test.js`
- `tools/admin/backfill-student-ids.mjs`
- `tools/admin/backfill-student-ids.test.mjs`
- `firebase/firebase.rules`
- `firebase/tests/profile.rules.test.mjs`
- `docs/student-id-cutover.md`
- `docs/current-version-qa-audit.md`

---

## 6. Recommended Next Actions

1. Proceed to release build phase for Flutter Android application.
2. Deploy Firestore Rules (`firebase deploy --only firestore:rules`) and Firestore Indexes (`firebase deploy --only firestore:indexes`).
3. Deploy Cloudflare Workers script (`cd workers/attendance && npx wrangler deploy`).
4. Execute `tools/admin/backfill-student-ids.mjs --apply` on target environment following `docs/student-id-cutover.md`.
