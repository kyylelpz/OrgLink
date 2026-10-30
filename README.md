# OrgLink V1 Documentation

Audited **30 October 2026 (Asia/Manila)** at commit `9b1e0536b98b5325fc90d189eb1327c08fc1dfef`. Verdict: **Conditionally Ready for the implemented core demonstration**, subject to deployment and physical-device acceptance. The complete original specification is **not complete**. See the [audit report](v1-audit-report.md) before presenting or releasing.

OrgLink is a Flutter Android student organization application using Firebase Authentication, Cloud Firestore, a Cloudflare Worker and Cloudinary. Only the existing `orglink-dev` project is configured and authorized. App version is `1.0.0+1`.

## Supported Functionality

| Area | Implemented scope | Guide |
| --- | --- | --- |
| Identity | Google and email/password authentication, verification, reset/link password, profile and Student ID reservation, account approval gate | [Module 1](module1.md) |
| Organizations | Discovery, membership requests/cancellation/review, roster, officer assignment, capability management, termination/reapplication | [Module 2](module2.md) |
| Events | Draft/review/publication lifecycle, posters, discovery, atomic registration/withdrawal, participant projections | [Module 3](module3.md) |
| Attendance | Manual marking, short-lived QR, scanning, corrections and audit, reports, own history | [Module 4](module4.md) |
| Administration | Account decisions, organization management, exact Student ID manager lookup, audited/versioned mutations | [Platform Administration](platform-admin.md) |
| Infrastructure | Authenticated Worker transactions and authorized Cloudinary image lifecycle | [Architecture](architecture.md), [Security](security.md), [Deployment](deployment.md) |

Calendar and Notifications are explicit Coming Soon destinations. Badges, ratings, announcement publishing, manager-transfer requests and account removal are absent. Direct administrator manager replacement is implemented; it does not satisfy the transfer-request specification. [Compliance](requirements-compliance.md) preserves these gaps.

## Architecture and Setup

Feature folders use View → ChangeNotifier ViewModel → Repository → Service → Model with Provider and go_router. Ordinary Firestore operations are protected by Rules; privileged operations use the Worker and reread authoritative records. Models and hidden buttons are not authorization boundaries.

Use the existing Flutter/Dart toolchain satisfying Dart `^3.12.2`, Android SDK/JVM 17 compilation, Node tooling and Java/Firebase CLI for emulators. Existing dependency installations were sufficient for this audit; no dependency was installed or upgraded.

```powershell
# From repository root, after normal development setup:
flutter analyze
flutter test
npm.cmd test --prefix workers/attendance
npm.cmd test --prefix tools/admin
flutter run --dart-define=ATTENDANCE_API_URL=https://orglink-attendance.orglink-dev.workers.dev
```

The ordinary app uses configured Firebase services, even in debug mode. Running it can access live development data; emulator isolation applies to the named test harnesses, not automatically to `flutter run`. Follow [deployment](deployment.md) for setup commands and manual release gates.

## Evidence and Document Reuse

Implemented means source exists; tested means a named check actually ran; deployed requires remote version and acceptance evidence. No deployment, live data inspection/mutation, account provisioning, or device installation was performed. Local tests do not establish those outcomes.

This set consolidates the existing `docs/` explanations without overwriting originals. Architecture, schema and permission explanations are reused with targeted corrections; detailed module workflows are condensed from the existing guides and checked against source. Historical test totals and obsolete migration claims are excluded. The audit report owns current results; deployment owns setup; compliance owns specification gaps. Supporting original guides remain linked where useful, but their historical totals/readiness claims are superseded by this set.

Read all eleven Markdown files in this directory. Supporting `.log` files are synthetic local validation evidence, not live operational records. Worker bundling was verified locally and its disposable bundle removed; no service was deployed.
