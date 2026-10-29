# Phase 4 — Organizations and Memberships

> Historical migration snapshot. Current behavior and test evidence are documented in [UI/UX baseline](ui-ux-design.md) and [current QA](current-version-qa-audit.md); this file is not a current feature or deployment inventory.

Completed: October 28, 2026. Presentation only; Phase 5 has not started.

## Design references

Read through Figma MCP from finalized file `9IIlHz8p1lc4aBAfep5UqH`:

- Discovery `15:3867`: mist canvas, 24dp gutters, compact search, equal-width pill filters, 48dp organization identities, white 16dp-radius cards.
- Details `15:3916`: midnight 24dp-radius cover, floating organization logo, 25dp bold identity, grouped mission/vision/goals.
- My Organizations `15:4370`: community hierarchy and reusable organization cards with actual membership information.
- Roster `15:5498`: compact member identities and permitted request actions.
- Approval `15:5718`: organization/applicant context, explicit decision consequences and confirmation before persistence.

Uses existing Inter typography and Phase 1 palette/tokens, including primary #152D97, midnight #000246, mist #F0F2FA, white surfaces and centralized status colors. Figma's exact decorative blue orbit was downloaded as SVG and rasterized at 4x with the existing local image tooling. No image dependency was added.

## Modified files

- `lib/core/widgets/app_components.dart`: opt-in expanded shared filter-chip labels for equal-width discovery slots; existing callers retain their default layout.
- `lib/features/organizations/presentation/widgets/organization_widgets.dart`: consolidated discovery/list/membership/preview OrganizationCard variants, contained dynamic OrganizationLogo with missing/error fallback, adaptive page headings, canonical-status presentation tones and selected local navigation.
- `lib/features/organizations/presentation/screens/organization_discovery_screen.dart`: finalized hierarchy, compact search, existing All/Joined/Discover filters, shared cards and existing membership navigation.
- `lib/features/organizations/presentation/screens/organization_details_screen.dart`: cover and floating logo, membership/request controls near the identity, grouped information surfaces and existing event/roster/management access.
- `lib/features/organizations/presentation/screens/my_organizations_screen.dart`: community heading, shared membership/manager cards, status chips, empty feedback and accessible unavailable-organization retry actions.
- `lib/features/memberships/presentation/screens/member_list_screen.dart`: shared adaptive MembershipMemberCard, status chips, existing permission guards, loading/empty/access feedback, scrollable approval/rejection confirmation and unchanged review handlers.
- `assets/illustrations/organization_orbit.svg` and `.png`: exact Figma decorative cover asset. Existing `assets/illustrations/` registration covers the PNG; pubspec unchanged.
- `test/phase2_navigation_test.dart`: discovery heading expectation updated.
- `test/phase4_organizations_ui_test.dart`: 10 focused layout/workflow/state checks.
- `docs/ui-migration-phase4.md`: this completion record.

## Preserved behavior

No ViewModels, repositories, services, models, routes/redirects, backend configuration, Firestore schema/rules, profile fields or Workers were changed. Existing search/filter functions, request eligibility, terminal membership states, duplicate-submit protection, manager-only decisions, officer roster/event access, self-review prohibition, confirmation/cancellation, failure feedback and server-confirmed writes remain intact. Canonical statuses are used unchanged; display labels are never saved or used for authorization.

My Organizations and Membership Requests retain their original record-selection semantics, including non-manager records in the requests view. Existing organization detail event links, public officer information, membership requirements and management controls remain available. Home keeps its existing preview-card navigation contract. The five-item shell and permission-aware QR routing are unchanged.

Organization logos remain organization-specific, use BoxFit.contain, and have a decorative fallback on missing/failed URLs. Official OrgLink assets already integrated in earlier phases remain intact; they are not substituted for unrelated organizations' identities.

## Validation

- Formatted only touched Dart files; `git diff --check` passes.
- `flutter analyze`: no issues.
- Focused organization, ViewModel, navigation, capitalization/shared presentation regression run: 47 tests passed.
- Final full `flutter test`: 160 tests passed, including Phase 1 shared component coverage.
- New tests cover 320/360/393/412dp at 100%/200% text, long organization/member names, safe areas, keyboard insets, search empty state, request/roster layouts, confirmation cancellation, rejected and failed reviews, retry, missing organization documents and failed network logos. Existing integration-style widget tests verify join, manager approval, active membership, roster, denied access and sign-out.
- Captured Flutter renders in ignored `build/ui-phase4/` and visually compared discovery, details, roster, queue and approval dialog with the five Figma references. Inspected large-text confirmation renders after widening the dialog.
- No infrastructure deployed.

## Intentional adaptations and remaining checks

- Uses actual visibility, status, description, membership roles/dates and public organization information. Figma example categories, member totals, applicant academic data and application prose are omitted when unavailable.
- Retains existing AppBars, back handling and the five-item shell; Figma frames sometimes omit that shell or show different framing. Long titles and enlarged type expand/scroll instead of using fixed Figma heights.
- Existing My Organizations/Requests links remain visible in discovery. Unsupported History tabs, roster search/filter/organization switching and future administrative actions were not added. Roster and manager decisions retain their existing separate destinations and permissions rather than merging access based on the Figma officer example.
- Approval/rejection uses the existing modal confirmation workflow rather than introducing the full-screen Figma confirmation route. At 200% text the dialog content scrolls while decision actions remain available.
- Empty logo fallback is an icon rather than a fabricated organization monogram. Existing backend-derived spelling/capitalization is preserved.
- Device TalkBack, physical Android gesture navigation and real network-logo quality still need manual device acceptance. The existing shell can wrap long navigation labels at narrow/large-text sizes; shell layout was outside Phase 4 and remains unchanged.

Stop here. Phase 5 requires separate approval.
