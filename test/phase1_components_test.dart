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
import 'package:orglink/core/widgets/app_logo.dart';

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'official logo variants decode, retain canvases and transparency',
    (tester) async {
      for (final variant in AppLogoVariant.values) {
        await tester.runAsync(() async {
          final bytes = await rootBundle.load(AppLogo.assetFor(variant));
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 2000);
          expect(frame.image.height, 2000);
          final pixels = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(
            pixels!.getUint8(3),
            variant == AppLogoVariant.symbol ? 0 : 255,
          );
          frame.image.dispose();
          codec.dispose();
        });
        await tester.pumpWidget(host(AppLogo(variant: variant, size: 120)));
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.contain);
        expect(image.color, isNull);
        expect(tester.getSize(find.byType(Image)), const Size(120, 120));
        expect(tester.takeException(), isNull);
      }
      expect(
        (await rootBundle.load(
          'assets/illustrations/empty_state.png',
        )).lengthInBytes,
        greaterThan(1000),
      );
    },
  );

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('button variants and chips fit $width at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        var calls = 0;
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: AppColors.brandMist,
                child: AppPageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeading(
                        title: 'Design Foundations',
                        description: 'Shared component preview',
                      ),
                      for (final variant in AppActionStyle.values) ...[
                        const SizedBox(height: 8),
                        AppActionButton(
                          label: 'Confirm Membership Registration',
                          onPressed: () => calls++,
                          style: variant,
                          icon: Icons.check,
                        ),
                      ],
                      const SizedBox(height: 8),
                      const AppActionButton(
                        label: 'Unavailable',
                        onPressed: null,
                      ),
                      const SizedBox(height: 8),
                      AppFilterChip(
                        label: 'Computer Science Society',
                        selected: true,
                        onSelected: (_) => calls++,
                      ),
                      const SizedBox(height: 8),
                      AppFilterChip(
                        label: 'Discover Organizations',
                        selected: false,
                        onSelected: (_) => calls++,
                      ),
                      const SizedBox(height: 8),
                      const AppStatusChip(
                        label: 'Awaiting Membership Approval',
                        tone: AppStatusTone.warning,
                      ),
                      const SizedBox(height: 8),
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Student Number',
                          errorText: 'Enter a valid student number.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        // The 1x histogram samples antialiased edge gray as the foreground on
        // sparse small Inter text. Exact color pairs are checked separately in
        // design_system_test; enlarged text also receives the pixel check.
        if (scale == 2) {
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
        semantics.dispose();
        final tonal = find
            .widgetWithText(FilledButton, 'Confirm Membership Registration')
            .at(1);
        await tester.ensureVisible(tonal);
        await tester.tap(tonal);
        expect(calls, 1);
        await tester.ensureVisible(find.text('Computer Science Society'));
        await tester.tap(find.text('Computer Science Society'));
        expect(calls, 2);
        if (width == 393 && scale == 1) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = File('build/ui-phase1/variants-393.png');
            await output.parent.create(recursive: true);
            await output.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }

  testWidgets(
    'success feedback is accessible and calls the supplied action only',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          AppSuccessView(
            title: 'Profile Saved',
            message: 'Your changes were saved.',
            actionLabel: 'Continue',
            onAction: () => calls++,
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );

  testWidgets(
    'busy tonal and destructive actions preserve colors without submitting',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              AppActionButton(
                label: 'Saving',
                onPressed: () => calls++,
                busy: true,
                style: AppActionStyle.tonal,
              ),
              AppActionButton(
                label: 'Removing',
                onPressed: () => calls++,
                busy: true,
                style: AppActionStyle.destructive,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Saving'));
      await tester.tap(find.text('Removing'));
      expect(calls, 0);
      final buttons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      expect(
        buttons[0].style!.backgroundColor!.resolve({WidgetState.disabled}),
        AppColors.tonal,
      );
      expect(
        buttons[1].style!.backgroundColor!.resolve({WidgetState.disabled}),
        AppColors.error,
      );
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    },
  );
}
