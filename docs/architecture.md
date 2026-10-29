# Architecture

## System and Technology

OrgLink targets native Android. Flutter renders a Material 3 interface; Firebase Authentication identifies accounts; Cloud Firestore stores application records; the existing Cloudflare Worker implements privileged transactions and Cloudinary signing/verification. No Firebase Cloud Functions or Firebase Storage upload integration is used by the current image flow.

`pubspec.yaml` declares app version **1.0.0+1**, Dart constraint **^3.12.2**, Provider **^6.1.5+1**, go_router **^18.1.1**, firebase_core **^5.1.0**, firebase_auth **^7.0.1**, cloud_firestore **^7.1.0**, google_sign_in **^7.2.0**, mobile_scanner **^7.4.2**, qr_flutter **^4.1.0**, http **^1.6.0** and image_picker **^1.1.2**. These are constraints, not a substitute for resolved versions in `pubspec.lock`. Inter is bundled; no runtime font download or crop package is required. Other generated platform directories/options do not establish cross-platform acceptance.

The Worker is an ES-module application using Web Crypto, Fetch and a custom Firestore REST transaction adapter. It does not run Firebase Admin SDK in Workers. Wrangler configuration names `orglink-attendance`, entry `src/index.js`, compatibility date `2026-10-23`, workers.dev enabled, observability disabled, and a 15-minute image-cleanup cron. Operator scripts under `tools/admin` separately use the Node Firebase Admin SDK; only the demo seeder needs Sharp.

## Feature Layers

```text
Screen/widget → ChangeNotifier ViewModel → Repository interface
                                      → concrete repository → Service
Typed models ↔ service serialization ↔ Firestore SDK / trusted HTTP API
```

Views handle interaction, navigation and presentation; ViewModels own state/operations and notify listeners; repositories abstract data access and map failures; services perform Firebase/HTTP work; models represent values and eligibility hints. Models are not a server authorization boundary.

| Location | Responsibility |
| --- | --- |
| `lib/main.dart`, `lib/app/startup.dart`, `splash_gate.dart` | First visible splash, Firebase bootstrap, minimum-duration coordination |
| `lib/app/dependency_injection.dart` | Provider wiring for auth/profile/org/event/attendance/admin repositories and services |
| `lib/app/router.dart`, `lib/core/constants/app_routes.dart` | go_router tree, authentication/eligibility redirects and create-form exit handling |
| `lib/core/` | Theme/tokens, feedback, shared widgets, image service/cropper, Worker HTTP client and display labels |
| `lib/features/{auth,profile,home,organizations,memberships,events,attendance,admin}/` | Feature presentation and data layers |
| `workers/attendance/src/` | ID-token verifier, REST Firestore, attendance, admin, Student ID and image backends |
| `firebase/` | Security Rules, index declarations and emulator test suites |
| `tools/admin/` | Explicit operator provisioning, Student ID audit/backfill and demo seeding |

## Data and Trust Flows

1. Firebase Auth emits the session. `AuthViewModel` resolves the user's own profile; router guards require password email verification, profile completion and active account status before normal protected use.
2. Ordinary reads and permitted membership/event/registration/manual-attendance writes use Firestore SDK. Security Rules validate the authenticated identity, organization permissions, canonical fields, timestamps and paired writes. Rules are not query filters; callers issue appropriately constrained queries.
3. Profile creation/Student ID changes, platform operations, QR verification/corrections and image reference changes use authenticated Worker POSTs. The Worker validates the token, reads authoritative documents, and applies privileged REST transactions through a service account. Those service-account operations bypass Rules, so backend validation remains essential.
4. Cloudinary upload tickets bind UID/resource/revision and expire after five minutes. Flutter sends image bytes to the Worker proxy; Cloudinary credentials/signatures remain server-side. Asset inspection precedes a revision-checked reference update. Old/orphan assets use a private cleanup queue.
5. Server-confirmed Firestore streams drive the UI. Services commonly exclude cached/pending snapshots for authoritative results; this is not an offline-first application. Network failures have explicit retry/error states.

## Lifecycle and Presentation Decisions

`AppStartup` paints the existing splash before Firebase initialization. A shared `SplashGate` overlaps asynchronous work with the two-second minimum starting on the first visible frame. Successful login receives the same treatment; startup resolution does not add a redundant second interval. No delay is inserted into Firebase or repositories.

Organization/event scopes and the authenticated shell are keyed/reactive to account identity. Create Event retains selected image bytes in memory until draft creation, then uploads using the new ID; retry retains that draft. Image bytes are not durable across process termination. Navigation and account changes are guarded independently of backend permission checks.

See [schema](database-schema.md), [authorization](perimissions-matrix.md), [API contracts](api-reference.md) and [UI baseline](ui-ux-design.md) for the detailed boundaries.
