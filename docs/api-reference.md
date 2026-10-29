# Integrations and Worker API

Source: [`index.js`](../workers/attendance/src/index.js), operation backends under `workers/attendance/src/`, Flutter [`WorkerApiService`](../lib/core/services/worker_api_service.dart), `AdminService`, and `AttendanceService`. No additional API is implied by screen names.

## Shared HTTP Contract

All listed routes require **POST**, `Content-Type: application/json`, and `Authorization: Bearer <Firebase ID token>`. Success is HTTP 200 with `{ "result": { … } }`; failure is `{ "error": { "code": "…", "message": "…" } }`. Responses set `Cache-Control: no-store` and `X-Content-Type-Options: nosniff`. Unsupported paths return 404, wrong methods 405. CORS support is not implemented for a browser client.

| Error code | HTTP status |
| --- | --- |
| `invalid-argument` | 400 |
| `unauthenticated` | 401 |
| `permission-denied` | 403 |
| `not-found` | 404 |
| `failed-precondition`, `already-exists`, `conflict` | 409 |
| `resource-exhausted` | 429 |
| unexpected/upstream failure (`unavailable`) | 503 |

JSON limits are 8 KiB normally, 64 KiB for `/admin/*`, and 7 MiB for `/images/upload` (base64 overhead included). The decoded image limit is 5 MiB. Backend diagnostics expose allowlisted stage/reason/status codes, not secrets, upstream response bodies or full requests.

The compile-time Flutter setting is `ATTENDANCE_API_URL`, default `https://orglink-attendance.orglink-dev.workers.dev`. This is **configured source**, not proof of availability. It is an origin with no path prefix, user info, query or fragment. Native release requests require HTTPS; debug clients permit HTTP only on explicit loopback/Android-emulator hosts. Changing a Dart define requires a new run/build. General Worker calls have a 25-second timeout, image proxy upload 60 seconds; other attendance transport behavior is implemented separately in `AttendanceService`.

## Routes

| Route | Request essentials | Result / purpose |
| --- | --- | --- |
| `/profile/save` | `{details: {fullName, studentNumber, yearLevel, section, college, program}}` | Validated owner profile save and atomic Student ID claim; no client role/status/UID accepted |
| `/admin/stats` | `{}` | Protected dashboard aggregates |
| `/admin/list` | `collection: users|organizations`, allowlisted `field`, `search`, optional `{id,value}` cursor | Up to 25 records, document versions, next cursor and derived presentation hints |
| `/admin/manager` | `studentId` | Unique registry-backed manager lookup with profile/registry versions and eligibility |
| `/admin/mutate` | `requestId`, `operation`, `targetId`, operation-specific version/changes/action | Idempotent, version-checked mutation and audit |
| `/issue` | `organizationId`, `eventId` | Participant's opaque QR token, `expiresAt`, `serverTime` |
| `/redeem` | `organizationId`, `eventId`, `version: 1`, `type: attendance`, `token` | Operator verification or safe duplicate result |
| `/correct` | `organizationId`, `eventId`, `operation: preview|apply`, `participantUid`; apply adds `newStatus`, `reason`, `revision` | Preview returns current status/revision; apply corrects/audits atomically |
| `/images/sign` | `kind: profile|organization|event`, applicable org/event IDs | `uploadId`, HMAC ticket `signature`, `expiresAt`, `maxBytes`, `uploadPath` |
| `/images/upload` | `uploadId`, ticket `signature`, base64 `file` | Proxy uploads the authorized static image; returns upload confirmation |
| `/images/finalize` | `uploadId` | Independently inspects Cloudinary and commits reference; successful retry may report `duplicate` |
| `/images/remove` | Resource selector + `expectedURL` (displayed URL or null) | Version-sensitive reference removal and deferred asset cleanup |

The exact QR `type` value and payload are defined by `QRPayload` and Worker checks; use the implementation rather than inventing QR user-ID payloads. The complete admin mutation/version contracts are in [Platform Admin](platform-admin.md#api-concurrency-and-audit-records), QR/correction behavior in [Module 4](module4.md), and image ticket contract in [Cloudinary setup](cloudinary-setup.md#endpoints).

## Backend Semantics

Profile saves validate the token's UID/email and protect legacy duplicates in addition to the registry. Admin changes support `accountStatus` actions approve/reject/deactivate/reactivate and organization create/update; they do not disable/delete Auth accounts or expose arbitrary role grants.

QR issuance requires an eligible registered participant and open attendance window. Tokens use 32 cryptographically random bytes, last at most 60 seconds (bounded by event end), are stored only as SHA-256 hashes, and are consumed transactionally. Issue throttling and latest-credential slots limit reuse; raw token possession is not sufficient to write attendance without an authorized scanner/operator. Corrections require a reason of 1–1000 trimmed characters, current revision and an existing result; they invalidate related prior credentials.

Image “sign” returns a Worker HMAC ticket, **not a reusable Cloudinary API signature**. The Worker generates a random 64-hex public ID in the appropriate `orglink/*` prefix and signs Cloudinary parameters including dynamic `asset_folder`, `overwrite=false`, allowed formats and bounded transformation. Folder paths/public IDs/URLs from Flutter are not accepted for assignment. Cloudinary Admin resource inspection verifies exact public ID, HTTPS delivery URL, type, format, size and dimensions before the transaction. See the image guide for precise retry/cleanup limits.

## External Services and Credentials

- Firebase Auth: SDK-managed credentials/session, Google OAuth and action codes. No password or service-account key belongs in Firestore, Flutter configuration or logs.
- Firestore: client SDK operations use Rules; the Worker obtains a Google access token from `FIREBASE_SERVICE_ACCOUNT` and uses its fixed `orglink-dev` REST database. The account must have the required IAM permissions; Rules do not authorize service-account writes.
- Cloudinary: `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` are Worker bindings/operator environment values. Delivery URLs are public to anyone who has the URL, including private-event images; private Firestore visibility does not make Cloudinary delivery private.
- Camera/gallery: `mobile_scanner` and `image_picker` use native device facilities. Automated widget coverage does not establish real camera permission, photo-picker or two-phone scanning acceptance.
