import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/theme/app_theme.dart';
import 'package:orglink/core/theme/app_tokens.dart';
import 'package:orglink/core/widgets/app_components.dart';
import 'package:orglink/core/widgets/app_feedback.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() async {
    // Exercise the bundled production font, rather than Flutter test's Ahem font.
    final loader = FontLoader(
      AppTheme.fontFamily,
    )..addFont(rootBundle.load('assets/fonts/open_sans/OpenSans-Variable.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test('brand palette, Material 3 role contrast and typography', () {
    expect(
      [
        AppColors.brandMidnight,
        AppColors.brandNavy,
        AppColors.brandBlue,
        AppColors.brandPurple,
        AppColors.brandMist,
        AppColors.ink,
        AppColors.black,
        AppColors.white,
      ],
      const [
        Color(0xFF000246),
        Color(0xFF1E2A78),
        Color(0xFF002BED),
        Color(0xFF8E75F7),
        Color(0xFFF0F2FA),
        Color(0xFF0A0A0A),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
      ],
    );
    final theme = AppTheme.light, colors = theme.colorScheme;
    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.bodyLarge!.fontFamily, 'Open Sans');
    expect(theme.textTheme.bodyLarge!.height, 1.5);
    for (final (foreground, background) in [
      (colors.onPrimary, colors.primary),
      (colors.onSecondary, colors.secondary),
      (colors.onTertiary, colors.tertiary),
      (colors.onSurface, colors.surface),
      (colors.onSurfaceVariant, colors.surfaceContainer),
      (colors.onError, colors.error),
      (AppColors.success, AppColors.successSurface),
      (AppColors.warning, AppColors.warningSurface),
      (AppColors.error, AppColors.errorSurface),
      (AppColors.brandNavy, AppColors.brandMist),
    ]) {
      expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
    }
    expect(
      contrast(AppColors.outline, AppColors.white),
      greaterThanOrEqualTo(3),
    );
    // Purple is an accent; white-on-purple is deliberately not a text pairing.
    expect(colors.onTertiary, AppColors.ink);
  });

  testWidgets(
    'licensed font loads from local assets with its distributed notice',
    (tester) async {
      final notice = await rootBundle.loadString(
        'assets/fonts/open_sans/OFL.txt',
      );
      expect(notice, contains('Copyright 2020 The Open Sans Project Authors'));
      expect(notice, contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(
        (await rootBundle.load(
          'assets/fonts/open_sans/OpenSans-Variable.ttf',
        )).lengthInBytes,
        greaterThan(100000),
      );
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(900, 700),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shared components fit $size at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final search = TextEditingController();
        final gallery = GlobalKey();
        await tester.pumpWidget(
          app(
            RepaintBoundary(
              key: gallery,
              child: ColoredBox(
                color: AppColors.brandMist,
                child: SizedBox.expand(
                  child: AppPageBody(
                    maxWidth: AppLayout.formWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionHeading(
                          title: 'Organization Overview',
                          description:
                              'A clear foundation for your student community.',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppSearchField(
                          controller: search,
                          onChanged: (_) {},
                          label: 'Search Participants',
                          hintText: 'Search by name',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const AppSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSectionHeading(
                                title: 'Attendance Overview',
                                description:
                                    'Demonstration of shared components only.',
                              ),
                              SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  AppStatusChip(
                                    label: 'Present',
                                    tone: AppStatusTone.success,
                                  ),
                                  AppStatusChip(
                                    label: 'Pending',
                                    tone: AppStatusTone.warning,
                                  ),
                                  AppStatusChip(
                                    label: 'Absent',
                                    tone: AppStatusTone.error,
                                  ),
                                  AppStatusChip(
                                    label: 'For Review',
                                    tone: AppStatusTone.info,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppActionButton(
                          label: 'Confirm Attendance Correction',
                          onPressed: () {},
                          icon: Icons.check,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppActionButton(
                          label: 'Cancel',
                          onPressed: () {},
                          style: AppActionStyle.secondary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppActionButton(
                          label: 'Remove Registration',
                          onPressed: () {},
                          style: AppActionStyle.destructive,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(AppSurfaceCard)).width,
          lessThanOrEqualTo(AppLayout.formWidth),
        );
        final topSemantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        topSemantics.dispose();
        if (scale == 1) {
          await tester.runAsync(() async {
            final boundary =
                gallery.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final screenshot = await boundary.toImage(pixelRatio: 1);
            final bytes = await screenshot.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/ui-phase1/components-${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            screenshot.dispose();
          });
        }
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Remove Registration'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        search.dispose();
      });
    }
  }

  testWidgets(
    'busy and disabled actions never submit; enabled actions preserve callback',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          Column(
            children: [
              AppActionButton(label: 'Save Profile', onPressed: () => calls++),
              AppActionButton(
                label: 'Saving Profile',
                onPressed: () => calls++,
                busy: true,
              ),
              const AppActionButton(label: 'Unavailable', onPressed: null),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Saving Profile'));
      await tester.tap(find.text('Unavailable'));
      expect(calls, 0);
      await tester.tap(find.text('Save Profile'));
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('search preserves intentional casing and clear notifies once', (
    tester,
  ) async {
    final controller = TextEditingController();
    final values = <String>[];
    await tester.pumpWidget(
      app(AppSearchField(controller: controller, onChanged: values.add)),
    );
    await tester.enterText(
      find.byType(TextField),
      "McDonald de la Cruz IEEE iOS",
    );
    expect(controller.text, "McDonald de la Cruz IEEE iOS");
    await tester.pump();
    await tester.tap(find.byTooltip('Clear Search'));
    expect(controller.text, isEmpty);
    expect(values, ["McDonald de la Cruz IEEE iOS", '']);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'feedback remains scrollable at large text with retry and empty actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;
      await tester.pumpWidget(
        app(
          AppErrorView(
            message:
                'Attendance could not be confirmed. Check your connection and retry.',
            onRetry: () => retries++,
          ),
          scale: 2,
        ),
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Try Again'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try Again'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          AppEmptyView(
            title: 'No Registrations',
            message: 'Discover an event to get started.',
            actionLabel: 'Discover Events',
            onAction: () => retries++,
          ),
          scale: 2,
        ),
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Discover Events'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover Events'));
      expect(retries, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const AppLoadingView(), scale: 2));
      await tester.pump();
      expect(find.text('Loading OrgLink...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
