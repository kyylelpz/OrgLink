# Implemented Requirements and Scope

OrgLink supports student organization discovery, membership, event participation and attendance in the configured development Firebase project `orglink-dev`. This is an implemented MVP inventory, not a future roadmap or a claim of live deployment. The original academic PDFs and valid module decisions remain reference material; [current QA](current-version-qa-audit.md) defines verification limits.

## Functional Modules

| Area | Implemented behavior | Detailed reference |
| --- | --- | --- |
| Identity and onboarding | Google and email/password sign-in, registration, verification/resend, forgot/reset password, explicit Google-to-password linking, profile completion, account-status routing and two-second minimum splash | [Module 1](module1.md) |
| Student profile | Name, Student Number, year, section, controlled college/program selection, profile photos, preservation of legacy values and opt-in capitalization suggestions | [Module 1](module1.md) |
| Home and navigation | Personalized data-driven dashboard, accessible event/org search and shortcuts; Home, Events, QR, Organizations, Profile tabs | [UI baseline](ui-ux-design.md) |
| Organizations | Public active discovery, details, managed/joined organizations, membership request/history, assigned-manager decisions and protected roster | [Module 2](module2.md) |
| Events | Draft create/edit/submit, manager approve/reject/publish/cancel/complete/archive, public/private visibility, event/time filters and optional posters | [Module 3](module3.md) |
| Participation | Confirmation before registration, atomic capacity/counter enforcement, withdrawal/re-registration before cutoff, My Events and event-scoped participant names | [Module 3](module3.md) |
| Attendance | Manual present/absent, participant short-lived QR pass, authorized scanning, duplicate handling, revision-checked corrections, event reports and personal history | [Module 4](module4.md) |
| Platform administration | Protected dashboard, account approve/reject/deactivate/reactivate, organization create/update/status, manager lookup by Student ID, idempotent audited mutations | [Administration](platform-admin.md) |
| Images | Authorized Cloudinary profile/logo/poster uploads, gallery preparation, interactive square/landscape cropping, original option, verification/removal and deferred cleanup | [Images](cloudinary-setup.md) |
| Development operations | Explicit administrator bootstrap, Student ID audit/backfill, deterministic demo preview/provisioning/cleanup with tracked ownership | [Operations](setup-and-operations.md) |

## Core Integrity Requirements

- Firebase UID remains the primary account key. New/changed Student IDs are **exactly 10 ASCII digits stored as strings**. `YYYYNNNNNN` is an illustrative format; code does not validate the first four digits as an enrollment year. Existing legacy identity eligibility is deliberately more permissive than new-save validation.
- New profile role/status is `user` / `pending`. Verified email is not organization membership or platform approval. No UI self-grant of administrator, manager or officer permissions exists.
- Organization `managerUid` defines manager authority; officer power depends on active membership, role and explicit permission. Platform Admin does not inherit event/attendance authority.
- Published events require approval; approval and publication are distinct. Registration/attendance depend on event state, time and eligibility, not card visibility alone.
- Upload authorization, image references and privileged account/organization changes are trusted-backend responsibilities. Client fields and displayed labels cannot authorize mutations.
- Student data is not exposed through full profile listings to members/managers. Published officer names and scoped participant/applicant snapshots serve limited display needs.
- Material 3, the current Inter theme, existing animation and responsive navigation remain the UI baseline. Final poster UI has separate Poster and Details cards, no secondary Home preview, and `cover` rendering. Display casing never changes persisted enum/permission keys or user-entered spelling automatically.

## Explicit Boundaries

Calendar and Notifications routes are **Coming Soon** screens. No working calendar/feed, notification scheduling, CSV export, geolocation, biometric attendance, ratings/badges, in-app audit browser or general role editor is implemented. Officer assignment remains a trusted external operator task. Demo tooling is not production app content. Android hardware/email/live Cloudinary acceptance, release signing and remote release verification remain separate work; see [handover status](current-version-qa-audit.md).
