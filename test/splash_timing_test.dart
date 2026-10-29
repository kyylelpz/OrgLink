import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/app/splash_gate.dart';
import 'package:orglink/app/startup.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

class SplashTestApp {
  final accounts = TestAuthRepository(), profiles = TestProfileRepository();
  final orgs = TestOrganizationRepository(), events = TestEventRepository();
  final gate = SplashGate();
  late final auth = AuthViewModel(accounts, profiles);
  GoRouter? _router;
  GoRouter get router => _router!;
  Widget application(SplashGate timing) {
    _router ??= createAppRouter(auth, splashGate: timing);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<GoRouter>.value(value: router),
        Provider<OrganizationRepository>.value(value: orgs),
        Provider<EventRepository>.value(value: events),
      ],
      child: const OrgLinkApp(),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(application(gate));
    await visible(tester);
  }

  Future<void> signedOut(WidgetTester tester) async {
    await mount(tester);
    accounts.controller.add(null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await flushRouting(tester);
    expect(path, AppRoutes.signIn);
  }

  String get path => router.routeInformationProvider.value.uri.path;
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    _router?.dispose();
    auth.dispose();
    gate.dispose();
    await accounts.controller.close();
    await profiles.controller.close();
    await orgs.close();
    await events.close();
  }
}

Future<void> visible(WidgetTester tester) async {
  for (
    var i = 0;
    i < 8 && find.byType(AnimatedSplashView).evaluate().isEmpty;
    i++
  ) {
    await tester.pump();
  }
  expect(find.byType(AnimatedSplashView), findsOneWidget);
  // Establish the first animation-clock tick without advancing simulated time.
  await tester.pump();
}

Future<void> flushRouting(WidgetTester tester) async {
  // GoRouter's asynchronous redirect chain may span several microtask/frame turns.
  // Do not advance the clock when asserting immediate navigation after loading.
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  late SplashTestApp app;
  setUp(() {
    app = SplashTestApp();
  });

  testWidgets(
    'cold startup with fast signed-out resolution holds the visible splash for two seconds',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(null);
      await tester.pump();
      expect(
        app.auth.status,
        AuthStatus.signedOut,
      ); // Repository resolution is not delayed.
      await tester.pump(const Duration(milliseconds: 1999));
      expect(app.path, AppRoutes.splash);
      expect(find.byType(AnimatedSplashView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        app.gate.progress,
        1,
        reason: 'Display clock must be complete at the two-second boundary.',
      );
      expect(app.path, AppRoutes.signIn);
    },
  );
  testWidgets(
    'constructing routing state before mount does not start the display clock',
    (tester) async {
      addTearDown(() => app.close(tester));
      app.application(app.gate);
      await tester.pump(const Duration(seconds: 5));
      expect(app.gate.progress, 0);
      await app.mount(tester);
      app.accounts.controller.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1999));
      expect(app.path, AppRoutes.splash);
      await tester.pump(const Duration(milliseconds: 1));
      await flushRouting(tester);
      expect(app.path, AppRoutes.signIn);
    },
  );
  testWidgets(
    'slow profile loading leaves immediately after completion once the minimum has elapsed',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(app.path, AppRoutes.splash);
      expect(app.profiles.watchCalls, 1);
      app.profiles.controller.add(profile());
      await tester.pump();
      await flushRouting(tester);
      expect(app.path, AppRoutes.home);
      expect(app.gate.cycle, 0);
    },
  );
  for (final provider in ['Google', 'email/password']) {
    testWidgets(
      '$provider success starts a fresh visible splash while profile loading overlaps',
      (tester) async {
        addTearDown(() => app.close(tester));
        await app.signedOut(tester);
        if (provider == 'Google') {
          await app.auth.signInWithGoogle();
        } else {
          app.accounts.emailUser = const AuthUser(
            id: 'email',
            emailVerified: true,
            providers: ['password'],
          );
          expect(
            await app.auth.signInWithEmail(
              'synthetic@example.test',
              'Synthetic123!',
            ),
            true,
          );
        }
        await visible(tester);
        expect(app.profiles.watchCalls, 1);
        expect(app.gate.cycle, 1);
        app.profiles.controller.add(profile());
        await tester.pump();
        expect(app.auth.profileStatus, ProfileStatus.ready);
        await tester.pump(const Duration(milliseconds: 1999));
        expect(app.path, AppRoutes.splash);
        await tester.pump(const Duration(milliseconds: 1));
        await flushRouting(tester);
        expect(app.path, AppRoutes.home);
      },
    );
  }
  testWidgets(
    'startup splash covers restored/login identity without a second minimum or duplicate refetch',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      await tester.pump(const Duration(milliseconds: 1500));
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pump();
      app.accounts.controller.add(student);
      await tester.pump();
      expect(app.gate.cycle, 0);
      expect(app.profiles.watchCalls, 1);
      await tester.pump(const Duration(milliseconds: 500));
      await flushRouting(tester);
      expect(app.path, AppRoutes.home);
    },
  );
  testWidgets(
    'very fast login/profile resolution still paints a full login splash',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.signedOut(tester);
      await app.auth.signInWithGoogle();
      await tester.idle(); // Resolve streams before painting a login splash.
      app.profiles.controller.add(profile());
      await tester.idle();
      expect(app.auth.profileStatus, ProfileStatus.ready);
      await visible(tester);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(app.path, AppRoutes.splash);
      await tester.pump(const Duration(milliseconds: 1));
      await flushRouting(tester);
      expect(app.path, AppRoutes.home);
    },
  );
  testWidgets(
    'slow login profile resolution adds no fresh delay at completion',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.signedOut(tester);
      await app.auth.signInWithGoogle();
      await visible(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(app.path, AppRoutes.splash);
      app.profiles.controller.add(profile());
      await flushRouting(tester);
      expect(app.path, AppRoutes.home);
      expect(app.gate.cycle, 1);
    },
  );
  testWidgets(
    'reduced-animation accessibility does not shorten the required minimum',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1999));
      expect(app.path, AppRoutes.splash);
      await tester.pump(const Duration(milliseconds: 1));
      await flushRouting(tester);
      expect(app.path, AppRoutes.signIn);
    },
  );
  for (final status in ['pending', 'suspended', 'disabled', 'rejected']) {
    testWidgets(
      '$status account routes to Account Status after login minimum',
      (tester) async {
        addTearDown(() => app.close(tester));
        await app.signedOut(tester);
        await app.auth.signInWithGoogle();
        await visible(tester);
        app.profiles.controller.add(profile(status: status));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1999));
        expect(app.path, AppRoutes.splash);
        await tester.pump(const Duration(milliseconds: 1));
        await flushRouting(tester);
        expect(app.path, AppRoutes.accountStatus);
        expect(find.byKey(const ValueKey('home-dashboard')), findsNothing);
      },
    );
  }
  testWidgets(
    'missing profile still routes to profile completion after the minimum',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.signedOut(tester);
      await app.auth.signInWithGoogle();
      await visible(tester);
      app.profiles.controller.add(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await flushRouting(tester);
      expect(app.path, AppRoutes.completeProfile);
    },
  );
  testWidgets(
    'unverified password login displays splash then preserves verification redirect',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.signedOut(tester);
      await app.auth.signInWithEmail('synthetic@example.test', 'Synthetic123!');
      await visible(tester);
      expect(app.profiles.watchCalls, 0);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(app.path, AppRoutes.splash);
      await tester.pump(const Duration(milliseconds: 1));
      await flushRouting(tester);
      expect(app.path, AppRoutes.verifyEmail);
    },
  );
  testWidgets(
    'failed/cancelled Google and failed password login remain on Sign In without a new splash',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.signedOut(tester);
      app.accounts.cancelSignIn = true;
      await app.auth.signInWithGoogle();
      await flushRouting(tester);
      expect(app.path, AppRoutes.signIn);
      expect(app.auth.signInCancelled, true);
      app.accounts.cancelSignIn = false;
      app.accounts.signInError = const AppFailure('Synthetic login failure.');
      await app.auth.signInWithGoogle();
      await flushRouting(tester);
      expect(app.path, AppRoutes.signIn);
      expect(app.auth.failure?.message, 'Synthetic login failure.');
      expect(
        await app.auth.signInWithEmail('synthetic@example.test', 'bad'),
        false,
      );
      await flushRouting(tester);
      expect(app.path, AppRoutes.signIn);
      expect(app.gate.cycle, 0);
      expect(find.byType(AnimatedSplashView), findsNothing);
    },
  );
  testWidgets(
    'profile failure safely displays existing error UI and retries without another minimum',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.addError(
        const AppFailure('Synthetic profile failure.'),
      );
      await tester.pump();
      expect(find.byType(AnimatedSplashView), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Synthetic profile failure.'), findsOneWidget);
      await app.auth.retry();
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pump();
      await flushRouting(tester);
      expect(app.path, AppRoutes.home);
      expect(app.gate.cycle, 0);
    },
  );
  testWidgets(
    'sign-out interrupts post-login loading without a late redirect back into the app',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.signedOut(tester);
      await app.auth.signInWithGoogle();
      await visible(tester);
      await tester.pump(const Duration(milliseconds: 300));
      app.accounts.controller.add(null);
      await tester.pump();
      await flushRouting(tester);
      expect(app.path, AppRoutes.signIn);
      await tester.pump(const Duration(seconds: 3));
      expect(app.path, AppRoutes.signIn);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'live account suspension after resolution remains an immediate guard with no splash delay',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await flushRouting(tester);
      expect(app.path, AppRoutes.home);
      app.profiles.controller.add(profile(status: 'suspended'));
      await tester.pump();
      await flushRouting(tester);
      expect(app.path, AppRoutes.accountStatus);
      expect(app.gate.cycle, 0);
    },
  );
  testWidgets(
    'navigation during the minimum preserves action-link query parameters',
    (tester) async {
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(null);
      await tester.pump();
      app.router.go('${AppRoutes.resetPassword}?oobCode=synthetic-code');
      await flushRouting(tester);
      expect(app.path, AppRoutes.splash);
      await tester.pump(const Duration(seconds: 2));
      await flushRouting(tester);
      expect(app.path, AppRoutes.resetPassword);
      expect(
        app
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['oobCode'],
        'synthetic-code',
      );
    },
  );
  testWidgets('disposing the visible splash cancels its clock safely', (
    tester,
  ) async {
    addTearDown(() => app.close(tester));
    await app.mount(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    expect(app.gate.minimumElapsed, false);
  });
  testWidgets(
    'Firebase bootstrap and auth handoff share one minimum display window',
    (tester) async {
      addTearDown(() => app.close(tester));
      final initialize = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        AppStartup(
          initialize: () {
            calls++;
            return initialize.future;
          },
          builder: app.application,
        ),
      );
      await visible(tester);
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 1000));
      initialize.complete();
      await tester.pump();
      await visible(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 999));
      expect(app.path, AppRoutes.splash);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        app.path,
        AppRoutes.home,
      ); // Not a second two-second window after Firebase.
    },
  );
  testWidgets(
    'slow Firebase initialization adds no delay after Firebase and auth finish',
    (tester) async {
      addTearDown(() => app.close(tester));
      final initialize = Completer<void>();
      await tester.pumpWidget(
        AppStartup(
          initialize: () => initialize.future,
          builder: app.application,
        ),
      );
      await visible(tester);
      await tester.pump(const Duration(seconds: 3));
      initialize.complete();
      await tester.pump();
      await tester.pump();
      app.accounts.controller.add(null);
      await tester.pump();
      await flushRouting(tester);
      expect(app.path, AppRoutes.signIn);
    },
  );
  testWidgets(
    'late Firebase completion after disposal neither builds the app nor throws',
    (tester) async {
      final initialize = Completer<void>();
      var built = false;
      await tester.pumpWidget(
        AppStartup(
          initialize: () => initialize.future,
          builder: (_) {
            built = true;
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      initialize.complete();
      await tester.pump();
      expect(built, false);
      expect(tester.takeException(), isNull);
      app.auth.dispose();
      app.gate.dispose();
      await app.accounts.controller.close();
      await app.profiles.controller.close();
      await app.orgs.close();
      await app.events.close();
    },
  );
  testWidgets(
    'Firebase failure preserves the minimum then shows the existing startup error',
    (tester) async {
      final initialize = Completer<void>();
      await tester.pumpWidget(
        AppStartup(
          initialize: () => initialize.future,
          builder: (_) => const SizedBox(),
        ),
      );
      await visible(tester);
      initialize.completeError(StateError('Synthetic startup failure.'));
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(find.byType(AnimatedSplashView), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('OrgLink could not start. Please close and reopen the app.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      app.auth.dispose();
      app.gate.dispose();
      await app.accounts.controller.close();
      await app.profiles.controller.close();
      await app.orgs.close();
      await app.events.close();
    },
  );
}
