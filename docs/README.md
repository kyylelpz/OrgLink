# OrgLink Documentation Index

Reviewed against the working source tree on **29 October 2026**. OrgLink is a Flutter Android student organization application using the configured Firebase project **orglink-dev**, a Cloudflare Worker, and Cloudinary.

## Reading Order

| Document | Purpose |
| --- | --- |
| [Requirements and implemented scope](requirements.md) | System overview, functional modules, acceptance boundaries and deferred work |
| [Architecture](architecture.md) | Technology, feature layers, data flow and source map |
| [Database schema](database-schema.md) | Persisted paths, fields, relationships and private operational records |
| [Permissions matrix](perimissions-matrix.md) | Roles, authentication, authorization and enforcement locations; filename retained for compatibility |
| [API reference](api-reference.md) | Trusted Worker contracts, Firebase and Cloudinary integration |
| [UI/UX baseline](ui-ux-design.md) | Current theme, navigation, screen behavior and image presentation |
| [Setup and operations](setup-and-operations.md) | Configuration, Android build, manual deployment and maintenance |
| [Current QA and handover status](current-version-qa-audit.md) | Fresh test evidence, limitations, unverified deployments and reconciliation of old claims |
| [Git workflow](github-workflow.md) | Local review and handover process; no CI pipeline is claimed |

## Detailed Module and Operator Guides

Use these existing guides for detailed behavior and procedures rather than duplicating their complete API/acceptance descriptions:

1. [Authentication and profile](module1.md): Google/email-password flows, verification, linking, account status, academics and splash timing.
2. [Organizations and membership](module2.md): discovery, organization information, membership requests, review and roster privacy.
3. [Events and registration](module3.md): event lifecycle, approval decisions, registration/withdrawal and participant identity projection.
4. [Attendance and QR](module4.md): manual marking, short-lived passes, scanning, corrections, reports and history.
5. [Platform administration](platform-admin.md): account decisions, organization configuration, manager resolution and operator-only administrator bootstrap.
6. [Cloudinary images](cloudinary-setup.md): permissions, cropping, upload tickets, verification, dynamic folders and cleanup.
7. [Student ID cutover](student-id-cutover.md): read-only audit, controlled registry backfill and verification; no completed live migration is asserted.
8. [Development demo seeder](demo-seeder.md): offline preview, approved provisioning/cleanup, ownership manifest and image licensing.
9. [Deployment readiness checklist](deployment-organization-verification.md): explicit remaining checks before a release.

## Evidence and Precedence

“Implemented” means source exists; “tested” identifies a named local suite; “deployed” requires an identified remote release and acceptance evidence. An endpoint default, configured project, emulator result or successful local test does **not** establish deployment. This documentation review performed no deployment, provisioning, migration or live service inspection.

Current source, Rules and configuration define technical behavior. Approved final poster UI uses **separate poster/details cards, no secondary Home crop preview, and cover-fitted poster displays**. Source/UI discrepancies are listed in the QA report rather than silently fixed in this documentation task. Historical counts in module guides are implementation-time snapshots; the current QA report is the source for newly executed test totals.

## Historical References

The PDF specifications (`Elective3_FinalProject.pdf` and its UI companion, when available in the checkout) are academic source requirements, not a claim that every proposed feature exists. Changes explicitly chosen by the project owner are documented in module guides.

- [UI migration phase 1](ui-migration-phase1.md), [phase 2](ui-migration-phase2.md), [phase 3](ui-migration-phase3.md), [phase 4](ui-migration-phase4.md), [phases 5–6](ui-migration-phase5-6.md): historical implementation/design records, superseded by the current UI baseline.
- [Previous QA report](history/qa-audit-previous.md) and [previous deployment report](history/deployment-report-previous.md): retained evidence of earlier reporting, not current certification or proof of remote state.
- Asset READMEs document provenance. Inter is registered in the current app; the retained Open Sans README is historical. The iOS launch-image README describes template tooling, not validated iOS release support.
