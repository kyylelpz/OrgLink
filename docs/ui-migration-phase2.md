# Figma Migration — Phase 2

> Historical migration snapshot. Current behavior and test evidence are documented in [UI/UX baseline](ui-ux-design.md) and [current QA](current-version-qa-audit.md); this file is not a current feature or deployment inventory.

Completed 28 October 2026. Presentation only; Phase 3 is not started.

## References and scope

Inspected live Figma context, screenshots, component properties and assets for
Navigation 15:7293, Home 15:3610, continuation 15:3682 and responsive variants
15:3723 / 15:3795 in [OrgLink Wireframes](https://www.figma.com/design/9IIlHz8p1lc4aBAfep5UqH/OrgLink-Wireframes).
The Phase 1 tokens, Inter registration and official logos remain authoritative.

## Implementation

- Five-item navigation keeps the existing selected-index calculation and route
  callbacks, history, Android Back/exit handling and permission-aware QR entry.
  White flat surface, top divider, 11dp selected/unselected labels, 22dp icons,
  and the raised 56dp rounded-square QR action follow the inspected component.
  Android bottom insets are supplied by SafeArea; no simulated gesture bar.
- Home uses a midnight header, time-sensitive greeting, profile initials,
  functional profile/notification actions, and integrated search with existing
  filtering/clear behavior. Four shortcuts open My Events, My Organizations,
  Notifications and My Attendance. Notifications/Calendar remain Coming Soon.
- First existing upcoming event uses the featured variant; the next uses the
  compact date/title/venue row. HomeViewModel's two-event limit, ordering and
  authorized catalog remain unchanged. Dynamic posters retain their URLs; a
  missing/failed poster uses actual organization/date/venue on a plain surface.
- Organization previews use existing authorized organization data. Management
  event links use the existing managementOrganizations getter. All previous
  participation, membership-request, attendance-management, profile and sign-out
  links remain available. No operator metrics, counts, announcements, badges or
  participation statistics were fabricated.
- The transparent official symbol is contained in a white tile beside the text
  wordmark. The opaque square wordmarks are not stretched or cropped.

## Components and changed files

- `lib/core/widgets/authenticated_shell.dart`: OrgLinkNavigationBar.
- `lib/features/home/presentation/screens/home_screen.dart`: dashboard composition.
- `lib/core/widgets/community_components.dart`: dashboard header, section/action
  heading and refined CommunityQuickAction; generic CommunityHeader retained.
- `lib/features/events/presentation/widgets/event_widgets.dart`: opt-in featured
  and compact EventCard variants; standard variant's behavior retained.
- `lib/features/organizations/presentation/widgets/organization_widgets.dart`:
  opt-in OrganizationCard preview; default presentation/behavior retained.
- `lib/core/widgets/app_components.dart`: optional compact search/leading artwork;
  existing callers retain their defaults.
- New `lib/core/widgets/app_asset_icon.dart` and `assets/icons/figma_*` SVG/PNG
  sources for ten inspected icons. Original SVGs were rasterized at 4x with the
  bundled Sharp tooling, preserving transparent canvases. Flutter consumes local
  PNGs and colors their alpha masks for selected/inverse states. No application
  package, asset registration, temporary runtime URL or image dependency added.
- Tests: `test/phase2_navigation_test.dart`, `test/widget_test.dart`,
  `test/text_formatting_test.dart` (updated Home text expectations while retaining
  stored-name and original-case assertions).

## Verification

- Touched Dart files formatted; `flutter analyze`: no issues.
- Focused navigation/Home/shared-component tests passed. Full `flutter test`:
  **139 passed**. Broader validation was warranted by the shared shell and changed
  Home entry points; affected exact-text tests were updated.
- Home/navigation renders compared with the reference at 320, 360, 393 and 412dp.
  Additional tests exercise all four widths at 200% text scaling with long names,
  organization/event titles, simulated system padding and keyboard insets.
- Empty catalog, error display, real search/navigation, management access and
  selected-tab behavior verified. Existing QR permission, camera teardown/retry,
  auth, membership, event and attendance regression tests pass.
- Local icon decoding, transparency, resolution, call sites and rendered geometry
  checked. Component semantics and touch-target checks pass at enlarged text.
- Preview files: ignored `build/ui-phase2/home-{320,360,393,412}.png`.

## Intentional adaptations and remaining acceptance

No sample editorial event poster, unread dot/count, dummy status bar or unsupported
Home filter action is shown. Real posters and data determine the featured card.
The continuation contains organization previews and functional actions rather
than unsupported statistics/campus notes. UI headings follow Title Case.

Header, shortcuts and navigation labels can grow/wrap on narrow phones and at
large text scales; full labels are retained. They do not copy fixed Figma heights
when those would clip real content. Icons use the approved primary #152D97 even
where legacy #002BED remains inside Figma specimens. Native hardware acceptance
still includes TalkBack, actual Android keyboard/system bars and camera behavior.

No ViewModel, repository, service, auth eligibility, business logic, route path,
permission, Firebase configuration, Firestore schema/Rules, Worker integration,
QR credential logic or profile fields changed. No infrastructure was deployed.
