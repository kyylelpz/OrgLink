import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/screens/auth_screens.dart';
import 'phase3_profile_ui_test.dart' as fixture;
import 'support/test_auth_repository.dart';

Future<void> capture(
  WidgetTester tester,
  fixture.ProfileApp app,
  String name,
) => tester.runAsync(() async {
  final boundary =
      app.capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/ui-email-auth/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
});
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
      testWidgets('completed auth states ${width}dp ${scale}x and keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = fixture.ProfileApp();
        addTearDown(() => app.close(tester));
        await app.mount(tester);
        app.accounts.controller.add(null);
        await tester.pumpAndSettle();
        Future<void> visit(String name, String route) async {
          app.router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: name);
          if ((width == 393 && scale == 1) || (width == 320 && scale == 2)) {
            await capture(
              tester,
              app,
              '$name-${width.toInt()}-${scale.toInt()}x',
            );
          }
        }

        await visit('sign-in', AppRoutes.signIn);
        expect(find.text('Welcome back!'), findsOneWidget);
        await visit('sign-up', AppRoutes.signUp);
        expect(find.text('Create your account'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          app.router.routeInformationProvider.value.uri.path,
          AppRoutes.signIn,
        );
        await visit('forgot-password', AppRoutes.forgotPassword);
        await tester.enterText(
          find.byKey(const ValueKey('reset-email')),
          'student@example.edu',
        );
        await tester.ensureVisible(find.text('Send Reset Link'));
        await tester.tap(find.text('Send Reset Link'));
        await tester.pumpAndSettle();
        expect(find.text('Reset link sent'), findsOneWidget);
        expect(app.accounts.resets, 1);
        if ((width == 393 && scale == 1) || (width == 320 && scale == 2)) {
          await capture(
            tester,
            app,
            'reset-sent-${width.toInt()}-${scale.toInt()}x',
          );
        }
        await visit(
          'reset-password',
          '${AppRoutes.resetPassword}?oobCode=synthetic-code',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.byKey(const ValueKey('new-password')),
          'SecureTest123!',
        );
        await tester.enterText(
          find.byKey(const ValueKey('confirm-password')),
          'SecureTest123!',
        );
        await tester.ensureVisible(find.text('Save New Password'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Save New Password'));
        await tester.pumpAndSettle();
        expect(app.accounts.passwordChanges, 1);
        expect(find.text('Password updated'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        if ((width == 393 && scale == 1) || (width == 320 && scale == 2)) {
          await capture(
            tester,
            app,
            'reset-success-${width.toInt()}-${scale.toInt()}x',
          );
        }
        app.router.go(AppRoutes.signIn);
        await tester.pumpAndSettle();
        app.accounts.emailUser = const AuthUser(
          id: 'email',
          email: 'student@example.edu',
          emailVerified: false,
          providers: ['password'],
        );
        app.accounts.controller.add(app.accounts.emailUser);
        await tester.pumpAndSettle();
        expect(find.text('Check your email'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if ((width == 393 && scale == 1) || (width == 320 && scale == 2)) {
          await capture(
            tester,
            app,
            'verification-${width.toInt()}-${scale.toInt()}x',
          );
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          app.router.routeInformationProvider.value.uri.path,
          AppRoutes.signIn,
        );
      });
    }
  }
  testWidgets(
    'registration confirmation, resume verification and approval remain separate',
    (tester) async {
      final app = fixture.ProfileApp();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(null);
      await tester.pumpAndSettle();
      app.router.go(AppRoutes.signUp);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'student@example.edu',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'SecureTest123!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm')),
        'WrongTest123!',
      );
      await tester.ensureVisible(find.text('Create Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(app.accounts.emailRegistrations, 0);
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm')),
        'SecureTest123!',
      );
      await tester.ensureVisible(find.text('Create Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(app.profiles.saveCalls, 0);
      expect(app.profiles.watchCalls, 0);
      app.accounts.emailUser = const AuthUser(
        id: 'email-student',
        email: 'student@example.edu',
        emailVerified: true,
        providers: ['password'],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      app.profiles.controller.add(profile(status: 'pending'));
      await tester.pumpAndSettle();
      expect(find.text('Your account is awaiting approval.'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-dashboard')), findsNothing);
      app.profiles.controller.add(profile());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-dashboard')), findsOneWidget);
    },
  );
}
