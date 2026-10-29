# Cloudinary Images for OrgLink

For operator-only, automatically sourced fictional development images, see the
[automated demo seeder](demo-seeder.md). It uses the same Cloudinary binding names,
signed dynamic folders, ID shape and image fields through an isolated Admin SDK
tool; it does not change these authenticated application endpoints or configuration.
Apply and cleanup require explicit approval and the original ownership manifest.

## Implementation and Security

The existing attendance Worker is also the image authorization backend. All routes use its existing Firebase RS256 ID-token verifier, fixed `orglink-dev` Firestore transport, authenticated POST/JSON convention, and sanitized error envelope. Password accounts must have verified email. Flutter never receives the Cloudinary API secret or the Firebase service account.

Cloudinary [upload signatures last one hour](https://cloudinary.com/documentation/authentication_signatures). Returning those signatures directly to a mobile client would prevent the Worker from enforcing a real five-minute expiry, one-use uploads, or an input byte limit. This implementation deliberately uses **signed five-minute upload tickets and a Worker upload proxy**. Cloudinary's signed parameters are generated and submitted inside the Worker; they are never exposed as reusable direct-upload credentials. No unsigned upload preset is needed. This costs Worker bandwidth and base64 overhead but enforces the limits before Cloudinary receives the file.

### Endpoints

All requests require `Authorization: Bearer <Firebase ID token>` and `Content-Type: application/json`. Responses are `{result: {...}}` or the existing `{error: {code, message}}` envelope. Do not log bodies, bearer tokens, upload signatures, or upstream credential responses.

| POST Route | JSON Body | Result |
| --- | --- | --- |
| `/images/sign` | `{kind: "profile"}` or `{kind: "organization", organizationId}` or `{kind: "event", organizationId, eventId}` | `{uploadId, signature, expiresAt, maxBytes, uploadPath}` |
| `/images/upload` | `{uploadId, signature, file: "<base64 bytes>"}` | `{uploadId, uploaded: true}` |
| `/images/finalize` | `{uploadId}` | `{saved: true}`; successful retries may return `duplicate: true` |
| `/images/remove` | Resource selectors as above plus `{expectedURL: "<currently displayed URL or null>"}` | `{removed: true}` |

`signature` is a scoped HMAC-SHA256 ticket signature bound to the authenticated UID, upload ID, and expiry. The ticket is single-use. Only the Worker generates folders, asset identifiers, transformations, Cloudinary signatures, and stored references. Callers cannot supply a UID, folder, URL, public ID, or arbitrary upload options. Finalization never accepts a client upload response as evidence: it independently calls Cloudinary's authenticated Admin resource API.

Input is capped at 5 MiB, and must have JPEG, PNG, or WebP magic bytes. Cloudinary validates the actual file and accepts only those formats on the `image/upload` endpoint. The Worker signs the server-selected `asset_folder` (`orglink/profiles`, `orglink/organizations`, or `orglink/events`) together with the existing public ID, timestamp, `overwrite=false`, `allowed_formats=jpg,png,webp`, and `c_limit,w_2048,h_2048` transformation. Finalization checks exact public ID, image resource type, upload delivery type, format, size, dimensions (1–4096 each), single-page content, and the HTTPS delivery URL for the configured cloud. SVG, PDF, video, and animated/multipage assets are not accepted as saved references. Client checks are convenience checks; the backend is authoritative.

### Permissions

| Resource | Backend Requirement |
| --- | --- |
| Profile | The Firebase UID's existing complete student profile, with active or pending account status. No client UID selector. |
| Organization logo | Active complete student account and an active organization; the assigned `managerUid` or authoritative `platformAdmin` role with the existing organization-administration capability. |
| Event poster | Active complete student account and active organization; assigned manager, or active officer with `manageEvents == true` who created this event. Only an editable draft: not archived or awaiting review. |

Permissions are read again for upload and finalization, not just ticket issuance. Poster changes reset approval to pending with no submission, matching ordinary draft edits. Approved draft content must be reviewed again. Published/cancelled/completed/archived event images cannot be changed. Create Event can stage a poster locally before saving. Save Draft first creates the event and obtains its valid ID, then automatically uploads and finalizes the poster. No Cloudinary request is made before draft creation succeeds.

Firestore Rules prohibit direct client edits of image references and private upload/cleanup queues, even by managers or platform administrators. Event creation requires a null poster. The event editor and admin organization editor no longer accept arbitrary image URLs. Platform Admin organization cards provide the verified logo editor, retaining administrative image management. Existing stored image URLs remain displayed verbatim and are not migrated.

### Stored Fields

| Document | Existing URL | New Cloudinary Public ID |
| --- | --- | --- |
| `users/{uid}` | `photoURL` | `photoPublicId` |
| `organizations/{orgId}` | `logoURL` | `logoPublicId` |
| `organizations/{orgId}/events/{eventId}` | `posterURL` | `posterPublicId` |

Each changed resource also has `imageRevision` and the existing `updatedAt`. Finalization compares the revision captured at ticket issuance inside a Firestore transaction; concurrent replacements have one winner. Removal compares the current URL to `expectedURL` and changes the revision to invalidate pending replacements. Unrelated profile, Student ID, role, organization, and event fields are preserved.

Public IDs are `orglink/profiles/<256-bit random hex>`, `orglink/organizations/<256-bit random hex>`, or `orglink/events/<256-bit random hex>`. There are no student names, Student IDs, or UIDs in public URLs. New uploads also specify the matching Media Library `asset_folder`: `orglink/profiles`, `orglink/organizations`, or `orglink/events`. The product environment must use [dynamic folder mode](https://cloudinary.com/documentation/folder_modes), where `asset_folder` controls Media Library placement independently of the public ID. The folder comes from the authorized server-created upload session and is included in the Cloudinary signature; clients cannot override it. No dashboard folder creation or folder-management API call is required. Existing assets/references are not moved or rewritten, and verification, cleanup, and deletion continue to use the unchanged public IDs.

## Image Editing and Cropping

| Resource | Selection and Crop Actions | Where Available |
| --- | --- | --- |
| Profile photo | Drag/reposition and pinch-to-zoom inside a fixed 1:1 live preview; Cancel, Reset, Confirm, or Keep Original | Existing profile editing flow after the student profile exists |
| Organization logo | The same interactive square cropper and actions | Active organization's details for its manager; organization cards in Platform Administration for active platform admins |
| Event poster | Create Event and Edit Draft share drag/pinch landscape cropping, Reset, Cancel, Confirm, and Keep Original; creation holds the selection locally until the draft exists | Create Event and existing editable draft editor/details, under current manager/officer permissions |

Reset returns to the initial centered, cover-fitted crop. Panning and zooming
keep the frame fully covered by the image. Confirm renders the visible source
region before invoking the existing upload service. Profiles/logos remain 1:1;
posters use the landscape frame described below.
Cancel uploads nothing. Keep Original returns the selected bytes unchanged by
cropping; native gallery resizing/compression may already have been applied.
No cropping dependency was added: the shared dialog uses Flutter gestures and
image rendering. `ProfilePhotoCropDialog` is reused for profiles, logos, and
posters with resource-specific titles and aspect ratios.

Gallery selection still requests a maximum of 2048 pixels on each axis and quality
85 where supported. Crop output is PNG, capped at 2048 pixels per side and
revalidated against the same 5 MiB upload limit. Encoding/size failures stay in
the dialog with an error and allow retry or Keep Original. Upload progress,
verification retries, removal confirmation, fallback images, and server permissions
are unchanged. Images save immediately, independently of text-form saves.

### Poster Placement and Actual Display Ratios

Event Poster appears above Event Details inside the same card, outside Schedule
and Capacity. `(Optional)` is separate muted, normal-weight supporting text below
the heading. Create Event and Edit Draft use the same landscape crop dialog.

The existing displays do not define a single fixed aspect ratio: the shared
`EventPoster` used in cards/details has responsive width, height **184 dp**, and
`BoxFit.contain`; the featured Home poster has height **174 dp** and
`BoxFit.cover`. The crop derives its ratio from the actual Details content width
(divided by 184), accounting for the 24 dp page gutters, 960 dp maximum content
width, and horizontal safe-area insets. For example, a 393 dp phone without
horizontal insets yields **345 × 184**, or **15:8**, not an assumed 16:9.

The main interactive preview matches Details. Cards with `contain` keep the whole
cropped image, even when their padded slots have a different shape. A separate
live Home Preview reproduces Home's centered `cover` trim at content-width/174.
The displayed poster layouts/fitting have not been redesigned. Keep Original
bypasses cropping and preserves the existing display behavior for other shapes.
Square profile/logo cropping remains unchanged; original and cropped selections
still pass the existing file/size checks and upload paths.

### Create Event Poster Recovery

The optional Event Poster picker keeps selected bytes in the creation ViewModel;
selection, replacement, removal, and preview make no Cloudinary requests.
Save Draft creates the event with a null poster first, retains its returned ID,
then uses the existing `/images/sign`, `/images/upload`, and `/images/finalize`
flow scoped to that ID. No endpoint, Rule, lifecycle, permission, or asset-folder
change is needed for this sequence.

If draft creation fails, the selected image stays available and upload does not
start. If upload/finalization fails after creation, the draft and selected bytes
are retained, saved text fields are locked, and Retry Upload uses the same event
ID. An ambiguous finalization retries its existing upload ticket; an expired or
stale ticket is cleared so a subsequent retry can request a fresh upload. Rate
limits and all backend checks still apply. Open Saved Draft requires
confirmation before discarding the local selection; the existing draft can later
be edited normally. An unconfirmed upload may already have completed on the
server, so check the saved poster before starting another upload.

Busy operations disable duplicate submissions and block ordinary route exits.
Leaving with a pending selection asks for confirmation, including navigation tabs
and Android Back. Forced authentication/account-status redirects remain allowed.
Local selection is held in memory, not persisted across app termination; a saved
draft survives, but the image must be selected again after restart. Edit Draft's
existing immediate poster editor is unchanged.

## Manual Setup

These are operator instructions. **No deployment or live database changes were performed by this implementation.**

1. Select the Cloudinary product environment intended for OrgLink development and verify that it uses dynamic folder mode. Do not manually create Media Library folders: new uploads supply the signed `asset_folder` parameter. Existing assets are not moved. Obtain its cloud name and an API key/secret with authenticated image upload, Admin resource lookup, and destroy access. Keep any existing unsigned presets disabled unless separately needed; this feature does not use them. Assets use public delivery URLs, so upload only imagery intended to be visible to anyone who has the URL.
2. From the repository root, install local dependencies:

   ```powershell
   flutter pub get
   npm ci --prefix workers/attendance
   npm ci --prefix firebase/tests
   ```

3. In `workers/attendance`, configure the three bindings using Wrangler's interactive secret prompts. Enter values at the prompts, never as shell arguments or in source files:

   ```powershell
   npx wrangler secret put CLOUDINARY_CLOUD_NAME
   npx wrangler secret put CLOUDINARY_API_KEY
   npx wrangler secret put CLOUDINARY_API_SECRET
   ```

   All three may be secrets even though cloud name and API key are not intrinsically secret. No real values belong in `wrangler.jsonc`. Preserve the existing `FIREBASE_SERVICE_ACCOUNT` binding and Firebase configuration; the service account must belong to `orglink-dev`. The existing Firestore datastore permissions must permit transactions and reads/writes for the resource documents and `_imageUploads`, `_imageSlots`, `_imageCleanup`. No new Flutter Firebase privileges are needed. Rotating the Cloudinary secret invalidates outstanding tickets.

   For local testing, use an untracked `.dev.vars` in that Worker directory with the same bindings and the existing development service-account configuration. Never print or commit it. Prefer local emulators and mocked Cloudinary for automated tests.

4. Run the local checks described below. After explicit deployment authorization, deploy the changed Rules first and Worker second:

   ```powershell
   # Repository root; run only when separately authorized.
   firebase deploy --only firestore:rules --project orglink-dev
   # Then workers/attendance; run only when separately authorized.
   npx wrangler deploy
   ```

   The existing Worker name is unchanged. `wrangler.jsonc` adds only a non-secret 15-minute Cron Trigger for cleanup. Verify the trigger is enabled after deployment. Build/install the updated Android app after the backend is ready. It uses the existing `ATTENDANCE_API_URL`; no Cloudinary settings are compiled into Flutter.

5. Optional retention: configure Firestore TTL on `deleteAfter` for `_imageUploads` and `_imageCleanup` after operator approval. This removes completed cleanup tombstones approximately seven days after retirement. TTL is **not** used to delete assets; never enable TTL on active upload `expiresAt`, which cleanup needs to find orphans. `_imageSlots` keeps one small rate-limit record per resource. All three collections must remain client-private.

## Cleanup, Retries, and Failure Handling

- Replaced/removed owned Cloudinary assets are queued transactionally; cleanup runs every 15 minutes, after a one-minute delay. Only exact OrgLink-generated public IDs can be deleted. Existing Google or external URLs are never submitted for deletion.
- Abandoned/conflicted/failed upload sessions are retired at least one hour after their five-minute expiry, then their assets are queued. This delay exceeds upload transport timeouts, preventing races with an uncertain upstream upload. Completed current assets are retained.
- Cleanup processes up to 50 expired sessions and 50 queued assets per run. Successful deletion or Cloudinary `not found` retires the job; failures retain it for a subsequent run. Monitor growing backlogs and Cloudinary Admin API quotas. Enable operator monitoring for scheduled failures; existing Worker logging configuration is otherwise preserved.
- A successful finalization is idempotent until its session is retired. A duplicate upload request is rejected and cannot overwrite an asset. If upload succeeds but finalization fails, Flutter offers **Retry Verification** using the same upload ID. Expired/conflicting sessions require a fresh image selection. If the upload request itself has an ambiguous transport failure, select again; the previous uncertain asset is reclaimed by cleanup.
- Images save immediately, separately from text edits. Canceling a profile/event text form does not undo an already saved image. Profile images use Firestore `photoURL`; Firebase Auth's provider photo is preserved separately.

## Local Tests

From the repository root:

```powershell
dart format .
flutter analyze
flutter test
npm test --prefix workers/attendance
npm run check --prefix workers/attendance
firebase emulators:exec --project orglink-dev --only firestore,auth "node --test --test-concurrency=1 firebase/tests/profile.rules.test.mjs firebase/tests/organization.rules.test.mjs firebase/tests/event.rules.test.mjs firebase/tests/attendance.rules.test.mjs firebase/tests/images.rules.test.mjs firebase/tests/email-auth.integration.test.mjs workers/attendance/test/admin.emulator.test.js workers/attendance/test/student_ids.emulator.test.js workers/attendance/test/attendance.emulator.test.cjs workers/attendance/test/images.emulator.test.js"
```

`npm run check` invokes Wrangler **dry-run only**, without deploying. Emulator tests use synthetic data and require local emulator bindings. If ports 8080/9099 are occupied, copy `firebase.json` to a temporary local config in the repository root, change only emulator ports (including hub/logging if necessary), and add `--config <temporary-file>` to the emulator command. Do not run test clients against live Firestore. Unit Cloudinary calls are mocked; no credentials are required.

Manual Android acceptance after separately approved setup/deployment:

1. Active/pending profile owner with an existing complete student profile: choose Change Photo, drag to reposition, pinch to zoom, use Reset, and Confirm. Verify the saved square matches the preview. Repeat with Cancel (no upload) and Keep Original (selected framing preserved), remove the photo, and reopen profile/home to check persistence and fallback.
2. Assigned organization manager: use Change Logo and repeat the interactive crop, Reset, Cancel, Confirm, Keep Original, and removal checks. Check discovery cards, details, and admin list. Other users/officers cannot change it. Repeat using Change Logo on an active Platform Admin's organization card.
3. Manager or permitted officer: select/change/remove an optional poster in Create Event and verify no upload occurs before Save Draft. Save and confirm the resulting draft/poster. Interrupt upload and check that Retry Upload keeps the same event ID without another event; test Stay/Leave on pending-image navigation. Verify the existing Edit Draft poster editor and text edits preserve poster references. Then submit/review/publish and check poster display on cards/details. Officer cannot edit another creator's draft; submitted/published events deny image changes.
4. Test invalid bearer tokens, stale `expectedURL`, duplicate upload requests, modified signatures, SVG/PDF/video, over-5-MiB files, oversized/multipage images, revoked permission between issuance and finalization, forged URL/public ID fields, expired tickets, and simultaneous replacements. None may assign an unverified reference.
5. Interrupt networking during upload/verification. Retry verification where available; confirm no false success, no text-data loss, and eventual cleanup of abandoned assets. Cloudinary delivery/CDN invalidation is asynchronous.
6. In the development Cloudinary Media Library, inspect a new upload of each kind: profile in `orglink/profiles`, logo in `orglink/organizations`, and poster in `orglink/events`. Confirm the asset-folder choice is signed and server-controlled, and public IDs retain their existing resource prefix plus random identifier. Check that existing URLs still resolve and replacement/removal cleanup still targets the public ID. Do not relocate existing assets or create folders manually.
7. Recheck Student ID editing/uniqueness, Platform Admin provisioning/manager assignment, event approval and registration, and QR attendance issue/redeem/correction.

## Troubleshooting and Limits

- **503 / backend not configured:** verify all three binding names, selected Cloudinary environment, and the preserved development Firebase service-account binding. Do not print secret values. Missing config fails closed.
- **Cloudinary 401/403:** check API key/secret pairing, SHA-256 signature support, and resource lookup/destroy permissions. Consult sanitized backend stage/reason, not upstream response bodies in client logs.
- **Permission denied:** refresh the Firebase session and profile; verify account status, current manager assignment, officer membership and `manageEvents`, event creator, and draft lifecycle. Platform administrators can manage organization logos through the admin organization cards; their role alone does not grant event editing.
- **Conflict:** another image change won the revision check, or removal's expected URL is stale. Refresh and choose again.
- **Invalid file:** select a static JPEG/PNG/WebP. Native gallery resizing/compression is requested at 2048 pixels/quality 85 where supported. Profiles and logos support interactive square cropping; Create Event and Edit Draft posters support interactive responsive landscape cropping with a live Home trim preview. Keep Original remains available. PNG crop re-encoding can exceed the cap; choose a smaller image or keep the original.
- **Image does not load:** existing fallback widgets handle delivery failures. Confirm Cloudinary delivery settings allow the generated secure URL. Organization/event privacy is application-level metadata access, not private Cloudinary delivery.
- **Unexpected Media Library folder:** confirm dynamic folder mode and that the intended updated Worker is serving the request after a separately authorized deployment. New uploads sign `asset_folder`; public-ID path prefixes alone do not set dynamic folder placement. Older assets keep their existing folder. Do not change public IDs, migrate existing references, or manually create dashboard folders to compensate.
- **Cleanup backlog:** verify the Cron Trigger, Cloudinary credentials/quota, and Firestore access. Jobs remain retryable; no public deletion endpoint exists. Without optional TTL, retired tombstones remain as small documents.
- **Scope:** Android gallery behavior and real Cloudinary upload/lookup/destroy require manual acceptance with a configured development environment. No live integration, deployment, credential setup, or database migration is part of local automated verification.

## Local Validation Results

Latest recorded implementation checks on 29 October 2026, before this documentation-only update. These are local results, not evidence of a deployment or live Cloudinary acceptance.

- `dart format .` executed; formatter-only changes outside the image feature were reverted to keep the diff focused.
- `flutter analyze`: two existing unused-import warnings in `complete_profile_screen.dart`; targeted analysis of crop/editor and creation-poster code/test files reports no issues.
- Full `flutter test`: 259 passed, including 26 shared-image/cropping tests, 21 creation-poster tests and the existing profile, organization, event, Student ID, Platform Admin, and QR/attendance workflows.
- Worker `npm test`: 87 passed, including all three signed `asset_folder` mappings, unchanged public IDs/references, rejection of client folder overrides, authorization, tampered/expired tickets, invalid files, forged references, replay, revisions, and cleanup.
- Firestore/Auth emulator regression run: 198 tests, 197 passed, zero failures, one existing TODO for Google/password linking rejected by the installed Auth emulator. That linking scenario remains a manual Android check.
- Separate image integration test using the actual Firestore REST transaction adapter and local emulator: one passed with the signed asset-folder change (folder parameter assertion, concurrent finalization, identity preservation, removal, and cleanup queries).
- Wrangler dry-run bundle: passed; no deployment.
- Android debug APK build: passed during the original image integration; no new build is claimed for the later crop/folder or documentation-only updates. Existing Firebase plugins emit a future Kotlin Gradle migration warning; no build failure.
- Real Cloudinary traffic and native Android gallery acceptance were not performed. All automated Cloudinary requests used synthetic fixtures.

## Modified Files

The pre-existing `image_picker` declaration in `pubspec.yaml` was reused and preserved. `flutter pub get` updated `pubspec.lock` and the generated platform plugin registrants. Firebase project/configuration files and the splash animation were not changed.

- `docs/cloudinary-setup.md`
- `firebase/firebase.rules`
- `firebase/tests/images.rules.test.mjs`
- `firebase/tests/package.json`
- `lib/core/services/image_upload_service.dart`
- `lib/core/services/worker_api_service.dart`
- `lib/core/utils/event_poster_layout.dart`
- `lib/core/widgets/image_editor.dart`
- `lib/core/widgets/profile_photo_crop_dialog.dart`
- `lib/features/admin/presentation/screens/admin_screen.dart`
- `lib/features/events/data/models/event.dart`
- `lib/features/events/data/services/event_service.dart`
- `lib/features/events/presentation/screens/event_details_screen.dart`
- `lib/app/router.dart`
- `lib/features/events/presentation/screens/event_editor_screen.dart`
- `lib/features/events/presentation/viewmodels/event_context_view_model.dart`
- `lib/features/events/presentation/widgets/event_widgets.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/organizations/data/models/organization.dart`
- `lib/features/organizations/presentation/screens/organization_details_screen.dart`
- `lib/features/profile/data/models/student_profile.dart`
- `lib/features/profile/data/services/user_profile_service.dart`
- `lib/features/profile/presentation/screens/complete_profile_screen.dart`
- `lib/features/profile/presentation/widgets/profile_overview.dart`
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `pubspec.lock`
- `pubspec.yaml`
- `test/event_creation_poster_test.dart`
- `test/event_poster_crop_test.dart`
- `test/image_upload_test.dart`
- `test/profile_photo_crop_test.dart`
- `tools/test-firestore.ps1`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`
- `workers/attendance/package.json`
- `workers/attendance/src/admin.js`
- `workers/attendance/src/images.js`
- `workers/attendance/src/index.js`
- `workers/attendance/test/images.emulator.test.js`
- `workers/attendance/test/images.test.js`
- `workers/attendance/wrangler.jsonc`
