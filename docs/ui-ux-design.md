# OrgLink — UI/UX Design Specification

**Version:** 1.0 · 27 October 2026  
**Purpose:** Add this document to the existing OrgLink project documentation as the implementation-ready UI/UX reference for Codex.  
**Scope:** Existing Modules 1–4, and presentation-only preparation for Module 5. This is not an authorization to modify backend behavior or deploy.

## 1. Reference hierarchy and traceability

1. **Elective3_FinalProject.pdf — functional source of truth.** Screen inventory, general wireframes, roles, permitted actions, form content, validation, navigation intentions, and Firestore architecture. Preserve requirements even where the visual design changes.
2. **Elective3_FinalProject-UI.pdf — visual source of truth.** Brand logo, colors, font options, mood board, and stylistic direction (pages 1–2). It references the earlier BarkadaBase project as a stylistic precedent, not as a mandate to copy its implementation.
3. **Existing OrgLink implementation and docs/module4.md — working behavior and integration source of truth.** Preserve actual routes, authentication, role guards, QR Hub, events, attendance verification, correction flows, server-authoritative data, and existing architecture.
4. **This specification — derived implementation guidance.** Token roles, component patterns, responsive/accessibility rules, rollout and acceptance criteria are recommendations for consistent implementation, not claims that the source PDFs explicitly specify every pixel or behavior.

**Conflict resolution:** Never weaken security or remove a required function to match a wireframe. Where a general wireframe conflicts with already-implemented working navigation, preserve the functioning route/flow and adapt its visual presentation. Flag irreconcilable ambiguities rather than silently rewriting business logic.

## 2. Brand identity

### 2.1 Source-defined palette (exact hexadecimal values)

| Token suggestion | Hex | Suggested use |
|---|---|---|
| `brandMidnight` | `#000246` | Brand headers, high-emphasis surfaces, dark logo variant |
| `brandNavy` | `#1E2A78` | Secondary emphasis, navigation elements |
| `brandBlue` | `#002BED` | Primary actions, focused/selected states |
| `brandPurple` | `#8E75F7` | Restrained highlights, badge accents, decorative graphics |
| `brandMist` | `#F0F2FA` | Light app backgrounds and subdued panels |
| `ink` | `#0A0A0A` | Primary body text |
| `black` | `#000000` | Neutral/asset use as appropriate |
| `white` | `#FFFFFF` | Cards, backgrounds, inverse text |

Source: Elective3_FinalProject-UI.pdf, page 1. All role assignments above are implementation recommendations; the exact color values are source-defined. Do not assume every color combination meets WCAG contrast; verify actual foreground/background pairs, especially white on purple and white on bright blue. Use accessible alternatives where needed.

### 2.2 Typography

The UI PDF lists **Google Sans, Google Sans Code, Google Sans Flex, and Open Sans** (page 1). Suggested implementation: Google Sans or Google Sans Flex for display/UI if properly available and licensed for the distribution method; Open Sans as a practical fallback for body text; Google Sans Code only for machine-readable values, IDs, or diagnostics, not long paragraphs. Check actual Flutter font availability and licenses; do not copy font files from the environment or commit unlicensed fonts. If preferred fonts are unavailable, use a close, legally distributable sans-serif and record the substitution. Maintain a coherent type scale and scalable text.

### 2.3 Logo and imagery

The UI PDF page 2 shows OrgLink symbol/wordmark variants in white-on-midnight and blue/purple-on-light, plus a standalone linked-shape icon. Reuse original project-owned logo assets when present. Do not recreate an approximate logo from the PDF or substitute an unrelated logo without approval. If no exportable logo asset is in the repository, use a clearly labeled placeholder and request the source SVG/PNG. Preserve logo aspect ratio and safe space.

### 2.4 Mood board interpretation

Page 2 depicts editorial whitespace, geometric blocks, strong navy/blue/purple contrast, abstract shapes, illustration, and dashboard-like information cards. Translate this into modern mobile Material 3 surfaces: visually clear hierarchy, generous whitespace, purposeful accent color, subtle geometry on onboarding/empty states only, readable data-rich screens, and minimal decoration around critical forms, scanner, and attendance actions. Avoid copying mood-board screenshots as UI assets.

## 3. Design system (proposed implementation defaults)

- **Theme:** light-first Material 3; use `ThemeData`, `ColorScheme`, `TextTheme`, component themes, and centralized design tokens. Do not scatter hardcoded hex colors across screens. Dark mode may be deferred unless already supported.
- **Spacing:** 4-pt baseline; common increments 4, 8, 12, 16, 24, 32. Typical screen horizontal padding 16–20; adjust for small phones and safe areas.
- **Shape:** cards 12–16 px radius, fields 10–12 px, buttons 10–14 px; consistent icon sizes and elevation. These are design recommendations, not PDF measurements.
- **Hierarchy:** high-contrast page title, short supporting text, clear primary CTA, low-emphasis secondary actions, destructive actions visually distinct.
- **Status semantics:** success/present, warning/pending, error/absent must have text labels and icons; never convey status by color alone. Do not recolor purple/blue to imply success when semantics require a different accessible status treatment.
- **Components:** reusable app header, section heading, primary/secondary/destructive buttons, outlined fields, search/filter bars, organization/event cards, status chips, confirmation dialogs, loading/empty/error/retry panels, participant rows, badge tiles, and summary statistic cards.
- **Feedback:** disable duplicate submissions; show pending, success, failure, stale/conflict, offline and permission-denied states with actionable messages. Use confirmation for irreversible/destructive or security-sensitive actions.
- **Responsive:** test at least compact and large Android phone sizes; handle text scaling, keyboard insets, long labels, scroll overflow, landscape where supported, and bottom navigation safe areas.
- **Accessibility:** semantic labels, readable touch targets (aim for >=48dp), visible focus states, sufficient text contrast (aim for >=4.5:1 for normal text), and screen-reader-friendly progress/status updates.
- **Motion:** brief, nonblocking transitions; respect reduced-motion settings; avoid animation that obstructs QR scanning, form submission, or attendance verification.

## 4. Navigation and information architecture

**Preserve the currently implemented authenticated shell:** `Home | Organizations | QR | Events | Profile`, with emphasized central QR Hub. The original general PDF mentions `Home | Organizations | Events | Badges | Profile`; the existing Module 4 QR navigation is a deliberate functional evolution. Do not replace QR with Badges without an explicit product decision. Make Badge Collection discoverable from Home, Profile, or another clearly labeled entry point; manager Badge Management should be a role-scoped management action.

Keep `go_router` guards and direct-link authorization. Preserve all current attendance routes and QR scanner behavior. Provide back navigation and organization context consistently.

## 5. Screen-family requirements and refinement

| Area | Functional reference | UI refinement focus | Non-negotiable behavior |
|---|---|---|---|
| Authentication/profile | Sign-in, profile completion, profile/settings wireframes | Branded entry, concise forms, validation hierarchy | Google sign-in, profile/account guards, no privileged profile edits |
| Home | Role-aware dashboard | Welcome header, grouped quick actions, compact status cards | Existing role-specific actions remain reachable |
| Organizations | Discovery, organization detail, memberships, officer management | Search, organization identity cards, status labels, consistent dialogs | Scoped permissions and approval/assignment flows unchanged |
| Events | Event list/detail, editing, registration, participant list | Timeline/date clarity, readable event cards, strong register/manage CTAs | Lifecycle, capacity, registration, permissions unchanged |
| QR Hub | Existing Module 4 QR routes | Strong scanner/pass choice, expiry clarity, camera error states | Existing center QR tab and secure pass flow retained |
| Attendance | Screens 22–24 + Module 4 corrections | Searchable roster, Present/Absent/Pending labels, action confirmation, report readability | Server-confirmed marking, permission guards, corrections, immutable normal writes |
| Badge Collection | Screen 25 | Grid/list of earned badge icon/name/description/date; useful empty state | Mock UI only until trusted awarding backend exists |
| Badge Management | Screen 26 | Organization selector, badge catalog, editor fields, criteria and active state | Manager-scoped UI; do not write awards from Flutter |
| Ratings/calendar/notifications/admin | Other screens in general PDF | Future UI consistency targets | Do not implement new modules as part of this refinement pass |

**Module 5 presentation-only boundary:** create reusable badge cards and screens with an isolated mock repository or fixture, clearly labeled preview/demo. Do not create Firestore badge documents, grant badge privileges, add new Worker endpoints, or claim automatic awards work. Structure UI models so real repositories can replace mock data later. Progress bars, streaks, notifications, and award animations are optional.

## 6. Implementation strategy for Codex

1. **Audit before editing.** Inventory existing themes, typography, assets, routes, shared widgets, and screens. Cross-reference the two PDFs and `docs/module4.md`. Identify where current UI already meets requirements.
2. **Foundation first.** Introduce/normalize centralized theme tokens, typography, shared components, and asset references. Keep dependencies minimal. Avoid broad codebase churn.
3. **Incremental screen batches.** Start with Home + authenticated shell, then Organizations, Events, QR/Attendance, Profile. Review each batch for navigation regressions and consistent states before moving on.
4. **Module 5 UI scaffold.** Add Screen 25/26 with isolated mock data and protected manager entry point; no backend awarding implementation.
5. **Validate.** `dart format` touched files, focused widget/router tests, `flutter analyze`, and a smoke run on compact and large Android devices. Use existing tests where possible; do not rerun the full suite for every minor styling edit.
6. **Document.** Update README/docs with design tokens, screen inventory, intentional deviations from the general wireframes, pending assets, and future Module 5 backend integration points.

## 7. Acceptance criteria

- Both PDFs are used in their intended roles: functional wireframes vs specific styling.
- All eight palette colors are centrally available; consistent use and accessible text contrast.
- Typography is cohesive; any font substitutions and logo asset gaps are documented.
- No loss of working routes, role-based controls, QR Hub, manual attendance, correction, or report functionality.
- Screens have intentional loading/empty/error/success and confirmation states.
- Badge Collection and Badge Management previews are visually integrated but cannot mint real awards.
- Existing architecture (View → ViewModel → Repository → Service → Model, Provider, go_router) is retained.
- No changes to Firestore Rules, IAM, service-account secrets, Cloudflare Worker, backend schema, or billing.
- Focused checks pass and visual differences are summarized by screen.

## 8. Known source limitations / requests

- The UI PDF includes **logo images and a mood board**, not a complete per-screen high-fidelity component specification; exact spacing/radius/type-size values in this document are proposed defaults.
- The PDF references **Group-5-BarkadaBase-Project-Document.pdf**, but its contents are not incorporated unless that separate file is supplied and reviewed.
- The UI PDF mentions a separate screenshot of Flutter font code; that screenshot is not included in the two-page document. Verify font package/API rather than assuming the screenshot's code.
- Some original PDF screens specify optional features. Avoid presenting those as already implemented.
- Final screenshot-by-screenshot approval remains a product/design review step.


## 9. Phase 1 implementation record - 27 October 2026

### Audit and reference decisions

The existing app already had a central Material 3 ThemeData, Provider/go_router,
shared loading/error panels, organization/event cards and the authenticated
Home | Organizations | QR | Events | Profile shell. Module 4 navigation, scanner,
window refresh, ordinary marking and correction controls were functional. The old
theme used an unrelated #315DA8 seed, no registered font, mostly default component
styles, and local spacing values. Status text existed but there was no shared
semantic status treatment or width-bounded page primitive.

Both pages of the visual PDF were visually reviewed, along with functional
screen requirements and design-system guidance on functional PDF pages 4, 9 and
21. The functional reference preserves controls and permissions; the UI PDF
supplies the exact palette and font options; Module 4/current implementation
preserves the working QR-centered navigation and corrections; this specification
supplies proposed spacing/radius/component defaults. The earlier separate
production Firebase/environment suggestion is outside this UI task: the existing
orglink-dev setup remains unchanged. No application assets were copied from the
mood board or approximated from the PDF.

The supplied general PDF is a functional screen inventory/design brief, not a
complete set of rendered screen mockups. The visual PDF is a brand/mood-board
reference, not a pixel-perfect specification. No attempt was made to invent
screen-by-screen fidelity that the supplied references do not define.

### Implemented foundation

- `lib/core/theme/app_tokens.dart`: all eight exact brand values; accessible
  supplemental semantic success/warning/error pairs; 4/8/12/16/24/32 spacing;
  12px fields/buttons, 16px cards, 48dp minimum control targets; 600dp layout
  breakpoint; 960dp general/560dp form content bounds.
- `lib/core/theme/app_theme.dart`: light Material 3 scheme with exact brand blue
  primary/navy secondary/purple tertiary, white surfaces/mist scaffold background,
  readable ink text and midnight app-bar emphasis. Open Sans type scale uses
  12/14/16px body sizes and 22/24/28/32/36px title/display sizes, scalable heights,
  semibold/bold hierarchy. Existing cards, buttons, fields, navigation, dialogs,
  snackbars and progress indicators inherit the central component themes.
- White is used on blue/navy, while ink is used on purple. Tested normal-text
  pairs meet 4.5:1; field outlines on white meet 3:1. Purple remains a restrained
  accent; semantic state colors do not reuse it as a success/error signal.
- `lib/core/widgets/app_components.dart`: AppPageBody (safe, scrollable,
  width-bounded Scaffold body), AppSectionHeading, AppSurfaceCard, AppStatusChip,
  AppActionButton and AppSearchField. Statuses use labels plus distinct icons;
  callers explicitly choose display labels/tones, never permissions or stored
  status values. Action buttons support primary/secondary/destructive, disabled
  and busy states. Search preserves entered casing and exposes a labeled clear
  action. AppPageBody owns its scroll view and must not nest inside another one.
- `lib/core/widgets/app_feedback.dart`: existing AppLoadingView/AppErrorView
  signatures, messages and callbacks preserved; scrollable constrained panels,
  semantic progress/live feedback and themed retry action. Added AppEmptyView
  with optional real callback; no fabricated data or feature-specific logic.

### Typography and assets

Open Sans is one of the UI PDF's supplied options. Its variable TrueType font and
complete SIL OFL 1.1 license were checked against the official Google Fonts source
and bundled locally. Source links, download date and SHA-256 hashes are recorded
in `assets/fonts/open_sans/README.md`. Flutter's LicenseRegistry includes the
bundled notice. No font/network package was added; fonts work offline. Preferred
Google Sans variants were not bundled or assumed interchangeable with Open Sans.

No usable original OrgLink wordmark/symbol SVG or PNG is registered in the repo.
The Android launcher image was inspected and is the Flutter logo. Original
project-owned light/dark wordmarks and standalone symbol exports are still needed
for a later branding batch. This phase does not invent a replacement, crop a PDF
logo, modify the launcher icon, or replace live organization logos.

### Scope preserved and deferred

This is foundation/shared components only. Existing feature layouts retain all
functional controls and receive inherited theme changes; migration to the new
page/card/status primitives is deferred to screen-specific batches. No router,
navigation destination, Provider, ViewModel, repository, service, business rule,
Firebase initialization, Firestore schema/Rules, Worker, IAM or billing changes
were made. Module 4 behavior/documentation remains authoritative and unchanged.

Module 5 Badge Collection/Management and its isolated, explicitly labeled mock
fixtures remain a later phase; no badge screens, routes, awards, documents or
permissions were added in Phase 1. Proposed follow-on batches:

1. Home + authenticated shell: hierarchy, quick-action grouping and responsive
   layout, retaining all five destinations and the central QR Hub.
2. Organizations/membership screens, then Events/registration/participants.
3. QR Hub/attendance/report/corrections, then authentication/profile forms.
4. Isolated Module 5 mock-only presentation after confirming manager-scoped entry
   and source badge/logo assets; no awarding/backend implementation.

### Validation and visual review

- `flutter pub get` completed through Flutter tooling; no dependency versions or
  new packages were added.
- `test/design_system_test.dart`: 11 focused tests passed using the real local
  Open Sans and Material Icons assets. Tests cover palette/contrast, font/license
  availability, busy/disabled action callbacks, preserved search text, retry/empty
  actions, and layout at 320x640, 430x932 and 900x700 with 1x/2x text scaling.
- Android touch-target, labeled-target and rendered text-contrast guidelines
  passed for the component gallery. Body/status text is never truncated to force
  a fit. Short 320x240 feedback layouts remain scrollable at 2x text size.
- Full Flutter suite: 98 passed, including existing auth, routing, membership,
  event, QR, attendance and correction tests. Flutter analysis reported no issues.
- Component previews at all three widths were visually inspected for typography,
  alignment, spacing, icons, surfaces and visible controls. Regenerate with
  `flutter test test/design_system_test.dart`; PNGs are written under ignored
  `build/ui-phase1/`. These are component-gallery previews, not redesigned app
  screens or an assertion of device acceptance.
- Final Dart formatting and diff whitespace checks passed. No deployment or
  backend/live-data checks were performed. Physical-device font rendering,
  TalkBack and keyboard acceptance remain manual checks for the next screen batch.

Changed files: app_theme.dart, new app_tokens.dart, new app_components.dart,
app_feedback.dart, pubspec.yaml, new Open Sans font/license/provenance assets,
new test/design_system_test.dart, and this implementation record. Source PDFs
were inspected without modification.
