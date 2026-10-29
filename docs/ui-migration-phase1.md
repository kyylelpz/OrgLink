# Figma Migration — Phase 1

> Historical migration snapshot. Current behavior and test evidence are documented in [UI/UX baseline](ui-ux-design.md) and [current QA](current-version-qa-audit.md); this file is not a current feature or deployment inventory.

The finalized [OrgLink Figma design](https://www.figma.com/design/9IIlHz8p1lc4aBAfep5UqH/OrgLink-Wireframes)
supersedes earlier visual choices in `ui-ux-design.md`: use Inter and primary
blue #152D97. Earlier implementation records are historical.

## Foundation references

- Foundations: 15:3104. Inter hero 34/700/140%, title 28/700/140%, section
  20/700/140%, body 15/400/140%, supporting 13/400/140%, label 12/600/140%.
- Button: 15:7156. Minimum 48dp target, 14dp radius, 20dp horizontal and 12dp
  vertical padding; filled, tonal, outlined, text, destructive, disabled, busy.
- Input: 15:7157. 12dp radius/padding, white fill, mist disabled fill.
- Components: 15:3218. Pill chips, 16dp cards, 24dp feature surfaces, flat
  elevation; muted #60677C, border #DDE2F0, tonal #E8EDFF, success #16704A on
  #E4F4EB, warning #825900 on #FFF3D6, error #B42335 on #FDECEF.

All input labels, stored values and existing callbacks remain intact. Flutter
controls expand for text instead of copying fixed specimen heights. The primary
Figma paint style wins over residual #002BED focus strokes in some specimens.
Material icons and dynamic progress indicators remain native Flutter controls;
their sizes/colors are centralized. The default empty illustration is a local
Figma PNG export (15:7150), not a runtime temporary URL.

## Assets

Inter is bundled from google/fonts, `ofl/inter/Inter[opsz,wght].ttf`, with its
SIL OFL notice. No runtime font fetch or font package is used.

Original official 2000×2000 PNGs are unmodified:

- `assets/icons/1.png`: white wordmark on opaque midnight canvas.
- `assets/icons/2.png`: color wordmark on opaque light canvas.
- `assets/icons/3.png`: transparent color symbol, used in shared loading feedback.

`AppLogo` selects the original variants and uses contain fitting. The opaque
wordmarks retain their square canvases/safe space; they are not compact horizontal
header exports. Phase 2 should use the transparent symbol with a text label or
request an official transparent horizontal/white variant if needed. Do not use
Figma's recreated mark or recolor the official files.

## Deferred, explicitly authorized Authentication/Profile task

College and Program are approved future additions, separate from Phase 1.
Implement them alongside Full Name, Student Number, Year Level and Section.
Cover model/serialization, form fields/validation, repository/service integration,
Firestore document compatibility and Rules/validation where required, optional
missing values for existing users, and relevant tests. Preserve Full Name rather
than automatically splitting stored names. No profile/schema/Rules changes are
included here.

## Phase 2 boundary

Home and navigation layouts are deferred. Preserve HomeViewModel, real data,
functional search, all existing management links and the five navigation items.
Keep permission-ready operators entering the scanner and other users entering
the QR Hub. Inter has no Open Sans width axis; compact navigation labels must be
visually verified. No calendar/feed/statistics/administration features are implied.

## Verification

Use `test/design_system_test.dart`, `test/phase1_components_test.dart`, and
`test/phase2_navigation_test.dart` for font/assets, controls, callbacks, semantics,
contrast, compact layouts, large text and camera/navigation regressions. Run
formatting, analysis and the full Flutter suite once after the focused checks.
Generated test renders live under ignored `build/ui-phase1/`.
Hardware acceptance still includes TalkBack, keyboard, Android safe areas and
native camera behavior. No deployment is required.

### Completed checks — 28 October 2026

- Modified Dart files formatted; `flutter analyze`: no issues.
- Focused component/theme/navigation checks passed; final `flutter test`: 131
  tests passed, including authentication, membership/event workflows, scanner
  lifecycle, attendance transport and correction tests.
- Shared controls exercised at 320/360/393/412dp and 100%/200% text scaling.
- Official assets decoded at their original dimensions; transparent symbol alpha,
  contain fitting, font registration/license, and callbacks were verified.
- Component renders visually reviewed at 320dp and 393dp. Native Material icons,
  dynamic spinners and status icons intentionally differ from Figma's static
  specimen artwork. Controls grow for accessibility. Disabled Figma text on its
  disabled surface is about 4.35:1 (inactive controls are contrast-exempt); active
  text pairs meet 4.5:1. Small regular Inter text can confuse the 1x histogram
  contrast checker; exact colors and enlarged-text pixel checks are retained.
- The organization workflow test centers the Join action before tapping, avoiding
  an obscured tap after typography changes. No production membership code changed.

### Changed files

`lib/core/theme/app_tokens.dart`, `app_theme.dart`; shared `app_components.dart`,
`app_feedback.dart`, new `app_logo.dart`; `authenticated_shell.dart` (remove the
Open Sans-only width axis); `pubspec.yaml`; `test/design_system_test.dart`,
`test/phase2_navigation_test.dart`, `test/organization_workflow_test.dart`, new
`test/phase1_components_test.dart`; bundled Inter font/license/source note;
`assets/illustrations/empty_state.png`; this record. Official `assets/icons/`
files were registered and consumed without changing their bytes. Existing
`docs/figma/` exports were left untouched.

No Firebase configuration, authentication, routes, Firestore schema/Rules,
repository, ViewModel, permission, Worker or other backend behavior changed.
