# BulSU Student ID System Cutover & Migration Guide

## 1. Overview
The BulSU Student ID system introduces mandatory, globally unique 10-digit numeric identifiers (`YYYYNNNNNN`) for student profiles in OrgLink.

Key Architectural Guarantees:
- **Primary Identity**: Firebase Auth UID remains the internal, primary identity across all collections (`users`, `memberships`, `events`, `attendance`, `activityLogs`).
- **Student ID Format**: Exactly 10 numeric ASCII digits (e.g., `2026000001`).
- **Global Uniqueness**: Enforced atomically via Cloudflare Worker transactions writing to the `studentIds/{studentId}` registry collection.
- **Client Security**: Firestore Security Rules deny direct client creation/modification of `studentIds` documents and profile creation.
- **Manager Assignment**: Platform admins select managers by entering their 10-digit Student ID, which the backend securely resolves to `managerUid`.

---

## 2. Pre-Cutover Requirements & Prerequisites

1. **Environment Setup**:
   - Node.js v20+ with ES Module support.
   - Application Default Credentials (ADC) configured with access to project `orglink-dev`.
   - Admin credential JSON files stored outside the repository directory.

2. **Backend & Rules Deployment**:
   - Firestore Security Rules (`firebase/firebase.rules`) deployed with direct client registry write prevention.
   - Cloudflare Worker (`workers/attendance`) deployed with `WORKER_SERVICE_ACCOUNT_KEY` binding.

---

## 3. Migration & Backfill Procedure

The operator tool `tools/admin/backfill-student-ids.mjs` manages audit and backfill of existing student profiles without modifying user UIDs or user-entered profile data.

### Step 1: Read-Only Audit
Run the tool in read-only mode to evaluate current profiles against the `studentIds` registry:

```bash
node tools/admin/backfill-student-ids.mjs --project orglink-dev
```

**Output Report Sections**:
- `profiles`: Total user documents scanned.
- `registry`: Total `studentIds` registry documents found.
- `missing`: Accounts without a student number.
- `invalid`: Accounts with non-10-digit numbers or formatting issues.
- `duplicates`: Groups of accounts claiming the same student ID.
- `unclaimed`: Valid candidates awaiting registry document creation.
- `registryConflicts`: Candidates where registry points to a different UID or retired state.
- `staleRegistry`: Registry entries pointing to deleted or modified accounts.
- `candidates`: Valid, non-conflicting accounts eligible for atomic claim.

### Step 2: Write Freeze Protocol
Before applying backfill:
1. Announce a maintenance window or client write freeze for profile saves.
2. Ensure no concurrent student profile updates are occurring.

### Step 3: Interactive Backfill Application
Run the backfill application command:

```bash
node tools/admin/backfill-student-ids.mjs --project orglink-dev --apply
```

When prompted:
```
Confirm direct ID writes are frozen. Type BACKFILL STUDENT IDS IN orglink-dev:
```
Type exact string `BACKFILL STUDENT IDS IN orglink-dev` to proceed.

The tool executes an atomic transaction for each candidate:
- Checks Firebase Auth identity matching user email and UID.
- Reads `users/{uid}` and `studentIds/{studentId}` simultaneously.
- Creates `studentIds/{studentId}` document (`{ uid, state: 'active', createdAt, updatedAt }`).
- Retains original `users/{uid}` fields without altering stored values.

### Step 4: Verification
Verify that all candidate accounts have active registry mappings and no remaining unclaimed valid IDs:

```bash
node tools/admin/backfill-student-ids.mjs --project orglink-dev --verify
```
*Note: Exits with code 0 on clean state, or code 2 if manual review items remain.*

---

## 4. Rollback Safeguards & Recovery

1. **Non-Destructive Backfill**:
   - The backfill script NEVER deletes or modifies existing user profiles in `users/{uid}`.
   - It only creates missing `studentIds/{studentId}` registry documents.

2. **Registry Rollback / Reversion**:
   - If an incorrect registry claim occurs, the document state in `studentIds/{studentId}` can be set to `retired` by an admin via Worker operations.
   - Setting a claim to `retired` prevents theft or unauthorized re-registration while maintaining historical audit records.

3. **Rules Fallback**:
   - In the event of a critical issue during deployment, Firestore Security Rules can be temporarily rolled back to a previous tag while keeping the `studentIds` collection intact.

---

## 5. Summary Deployment Sequence

1. **Deploy Firestore Security Rules**: `firebase deploy --only firestore:rules`
2. **Deploy Attendance Worker**: `cd workers/attendance && npx wrangler deploy`
3. **Execute Read-Only Audit**: `node tools/admin/backfill-student-ids.mjs --project orglink-dev`
4. **Execute Backfill Application**: `node tools/admin/backfill-student-ids.mjs --project orglink-dev --apply`
5. **Execute Verification Check**: `node tools/admin/backfill-student-ids.mjs --project orglink-dev --verify`
6. **Deploy App Build**: Release updated Flutter Android APK.
