import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

class ProfileApp {
  final accounts = TestAuthRepository(), profiles = TestProfileRepository();
  final orgs = TestOrganizationRepository(), events = TestEventRepository();
  late final auth = AuthViewModel(accounts, profiles);
  late final router = createAppRouter(auth);
  final capture = GlobalKey();
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<GoRouter>.value(value: router),
        Provider<OrganizationRepository>.value(value: orgs),
        Provider<EventRepository>.value(value: events),
      ],
      child: RepaintBoundary(key: capture, child: const OrgLinkApp()),
    ),
  );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
    await accounts.controller.close();
    await profiles.controller.close();
    await orgs.close();
    await events.close();
  }

  Future<void> screenshot(WidgetTester tester, String name) => tester.runAsync(
    () async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-phase3/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    },
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'auth and profile at ${width}dp, ${scale}x with safe areas and keyboard',
        (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final app = ProfileApp();
          addTearDown(() => app.close(tester));
          await app.mount(tester);
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await app.screenshot(tester, 'splash-${width.toInt()}');
          }
          app.accounts.controller.add(null);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await app.screenshot(tester, 'sign-in-${width.toInt()}');
          }
          app.router.go(AppRoutes.onboarding);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await app.screenshot(tester, 'onboarding-${width.toInt()}');
          }
          app.accounts.controller.add(student);
          await tester.pump();
          app.profiles.controller.add(null);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('college-field')), findsOneWidget);
          expect(find.byKey(const ValueKey('program-field')), findsOneWidget);
          if (scale == 1) {
            await app.screenshot(tester, 'completion-${width.toInt()}');
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('college-field')),
          );
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          addTearDown(tester.view.resetViewInsets);
          await tester.enterText(
            find.byKey(const ValueKey('college-field')),
            'x',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          app.profiles.controller.add(
            profile(
              details: StudentDetails.fromMap({
                ...validDetails.toMap(),
                'fullName': "Alexandria-McDonald de la Cruz O'Neil",
                'college': 'College of Engineering',
                'program': 'IEEE / iOS Research',
              }),
            ),
          );
          await tester.pumpAndSettle();
          app.router.go(AppRoutes.home);
          await tester.pumpAndSettle();
          app.router.go(AppRoutes.completeProfile);
          await tester.pumpAndSettle();
          expect(find.text('Your Profile'), findsOneWidget);
          expect(find.textContaining('IEEE / iOS Research'), findsOneWidget);
          expect(find.textContaining('Badges'), findsNothing);
          expect(tester.takeException(), isNull);
          if (scale == 1 || width == 320) {
            await app.screenshot(
              tester,
              'profile-${width.toInt()}-${scale.toInt()}x',
            );
          }
          final semantics = tester.ensureSemantics();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          semantics.dispose();
        },
      );
    }
  }

  testWidgets(
    'editing retains academics and spelling after save failure and retry',
    (tester) async {
      final app = ProfileApp();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.add(
        profile(
          details: StudentDetails.fromMap({
            ...validDetails.toMap(),
            'college': 'IEEE College',
            'program': 'iOS Research',
          }),
        ),
      );
      await tester.pumpAndSettle();
      app.router.go(AppRoutes.completeProfile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Student Profile'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('college-field')))
            .controller!
            .text,
        'IEEE College',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('program-field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('program-field')),
        'iOS and NASA Research',
      );
      app.profiles.saveError = const AppFailure('Save failed. Try again.');
      await tester.ensureVisible(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Save failed. Try again.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('program-field')))
            .controller!
            .text,
        'iOS and NASA Research',
      );
      app.profiles.saveError = null;
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(app.profiles.savedDetails!.college, 'IEEE College');
      expect(app.profiles.savedDetails!.program, 'iOS and NASA Research');
      expect(app.profiles.savedDetails!.fullName, validDetails.fullName);
      expect(find.byKey(const ValueKey('home-dashboard')), findsOneWidget);
      expect(find.text('Your Activity'), findsNothing);
    },
  );
}
