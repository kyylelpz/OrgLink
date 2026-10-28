# UI Migration — Combined Phases 5–6

Completed October 28, 2026. Presentation only. No infrastructure deployed.

## Figma references inspected through MCP

Finalized OrgLink file `9IIlHz8p1lc4aBAfep5UqH`, session `61457099-44e2-466c-8360-bf3c631a4556`:

- Events: Discovery `15:4727`, Details `15:4158`, Registration `15:4183`, My Events `15:4323`, Management `15:5469`, Editor `15:5591` / `15:5639`, Participants `15:5688`.
- QR/Attendance: Hub `15:4593`, Pass `15:4652`, Scanner `15:5281`, Roster `15:5235`, Report `15:5371`, Correction `15:5407`.

Retrieved design context and screenshots for all 14 frames. Reused Inter, #152D97, midnight/mist surfaces, 24dp gutters, 16dp cards, 20dp poster corners, shared buttons/chips/feedback, and existing official OrgLink assets. The exact Figma poster orbit is bundled locally as transparent SVG and a 784×784 PNG, displayed in its 196dp slot. No package or asset-registration changes were needed.

## Modified files and presentation changes

- `lib/core/widgets/app_components.dart`: opt-in prominent section headings and shared adaptive `AppMetricTiles` with separate accessible label/value semantics. Existing callers retain default heading behavior.
- `lib/features/events/presentation/widgets/event_widgets.dart`: refactored standard event cards, a compact managed variant, reusable `EventPoster` and `EventSummary`, selected event navigation, and scrollable confirmation dialogs. Existing Home preview variants retain their behavior.
- `lib/features/events/presentation/screens/event_discovery_screen.dart`: finalized page hierarchy, scrollable search/filter/results viewport, poster cards and shared empty/error feedback. Existing period and organization filters retained.
- `lib/features/events/presentation/screens/my_events_screen.dart`: registration hierarchy, shared date summaries and registration chips, selected navigation, responsive unavailable-event retry controls. Name refresh and withdrawal handlers retained.
- `lib/features/events/presentation/screens/event_details_screen.dart`: large poster, organizer identity, white information surface, registration review summary and clear hierarchy. All registration, withdrawal, draft, submission, approval, rejection, publication, cancellation, completion, archiving, participant and attendance actions retain their original guards and callbacks.
- `lib/features/events/presentation/screens/event_management_screen.dart`: compact lifecycle/approval cards, existing search/status filter, fixed Create Event action, participant summary and actual reserved/capacity metrics. Participant names remain event-scoped.
- `lib/features/events/presentation/screens/event_editor_screen.dart`: grouped details/schedule sections, retained poster preview, responsive visibility control and safe, bounded scrolling. Original validators, date pickers, capitalization suggestion, save payload and single-form draft workflow retained.
- `lib/features/attendance/presentation/screens/qr_screens.dart`: midnight personalized hub, white pass surface with actual profile name when available, responsive real QR sizing, privacy guidance, midnight live-camera presentation and framing overlay, readable verification/error feedback and manual lookup actions. Existing permission-aware QR landing and all scanner lifecycle methods remain unchanged.
- `lib/features/attendance/presentation/screens/attendance_screens.dart`: organization/event selection cards, reusable event summaries, actual attendance metrics, status chips, roster/report surfaces, personal history hierarchy and correction success feedback.
- `lib/features/attendance/presentation/screens/attendance_correction_dialog.dart`: scrollable organization/event/applicant context, Before/After status previews and required reason styling. Conflict errors, confirmation, busy guards, back prevention and audit calls unchanged.
- `assets/illustrations/event_orbit.svg` and `.png`: exact Figma decorative poster artwork; dynamic event posters remain dynamic and use contained image rendering with a fallback.
- `test/attendance_test.dart`: exact-text summary expectation updated to validate the redesigned metric/chip values.
- `test/phase5_6_ui_test.dart`: nine combined layout, state, asset and accessibility checks using explicitly synthetic test repositories/camera.
- `docs/ui-migration-phase5-6.md`: this consolidated report.

Concurrent organization/profile edits were preserved. The organization discovery edit referenced undefined `AppColors.background`; only that reference was corrected to `AppColors.brandMist`, and the touched file was formatted. `test/organization_workflow_test.dart` now checks its current Find Your People heading instead of the AppBar removed by that concurrent edit. The profile file was not edited by this migration.

## Preserved workflows and permissions

No ViewModels, repositories, services, models, routes/redirects, Firebase configuration, Firestore schemas/rules, Workers, authentication, authorization or College/Program persistence changed. Existing server transactions remain authoritative for capacity, eligibility, deadlines, duplicate registrations, event lifecycle, QR issuance/redemption and audited attendance corrections.

Manager/officer differences, private event eligibility, event-scoped participant visibility, attendance permission checks, self-verification restrictions, manual marking windows and immutable normal verification remain intact. Missing attendance stays Not Marked; it is never inferred as Absent. Report totals/rates use the existing summary and real records. QR pixels encode only the credential returned by the existing repository; the Figma sample pattern is not bundled or displayed. No future ratings, announcements, badges, export service or analytics were added.

## Validation

- Formatted touched Dart files; `git diff --check` passes.
- `flutter analyze`: no issues.
- Focused checks cover event creation/submission/approval/publication, registration/withdrawal/name refresh, manual attendance, correction validation/conflicts/auditing, QR window boundaries, credential invalidation and camera permission/error/retry/route/lifecycle behavior.
- Full `flutter test`: **169 tests passed**. A final focused nine-case screen matrix also passes after the final heading-alignment adjustment.
- New matrix checks Events, QR and Attendance screens at 320/360/393/412dp with 100%/200% text, long titles/names, safe areas, keyboard insets, pass issuance and responsive QR display, roster/report/correction layouts, cancellation, missing poster fallback, empty catalog, denied camera/retry and metric semantics.
- Captured renders under ignored `build/ui-phase5-6/`. Compared discovery, details, registration, management/editor, participants, hub/pass, scanner, roster/report and correction presentation against Figma. Reviewed 320dp/200% dialog renders; their content scrolls while actions remain available.
- Verified scanner lifecycle source against HEAD: unchanged. Verified orbit PNG transparency/resolution and its local callsite/geometry. Existing font/official asset registration remains intact; no temporary Figma URLs appear in runtime code.

## Adaptations and remaining issues

- Preserved existing AppBars, five-item shell and back behavior. Figma sometimes omits that shell; existing narrow/large-text navigation-label wrapping remains outside this migration.
- Retained functional period/organization/status dropdowns and their canonical values rather than adding Figma-only month, participant search or extra filters. No unsupported share/calendar/flashlight/export controls were introduced.
- Kept the existing single event form and Save Draft behavior rather than adding Figma's staged editor or published-event editing. Publication remains a separate authorized action. Event fields, dates, URL validation and stored spelling are unchanged.
- Missing posters use real organization identity/schedule with the Figma orbit instead of sample editorial event artwork. Network posters retain aspect ratio. Figma leaf/category illustrations are not assigned to arbitrary real events.
- Participants display actual reserved/capacity values; attendance percentages appear only where the existing attendance summary is available. No fabricated participation metrics or academic applicant data.
- QR pass expiry, regeneration, already-verified and restricted states reflect existing models, replacing Figma's nonfunctional demo labels. The scanner remains authorized across organizations rather than pretending an event is selected before a scan. Its scan frame is visual guidance and does not change detection/redemption logic.
- Registration actions stay in the scrollable page; Create Event uses a fixed action area. Correction retains the current audited modal workflow rather than introducing a new route. Large text expands/scrolls instead of using fixed Figma heights.

## Manual Android acceptance still required

Check real-device camera permission denial/re-enable, background/foreground and rapid navigation; real Worker-issued QR recognition, expiry and duplicate verification; poster/network loading; TalkBack reading/focus order; Android keyboard/gesture insets; and daylight QR readability on target devices. Automated camera tests use a clearly identified test platform, not physical camera hardware. No production credentials or backend deployments were used for validation.

Stop after Phases 5–6. No unrelated feature or additional migration has begun.
