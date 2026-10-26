import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:provider/provider.dart';

import 'support/test_auth_repository.dart';

void main() {
  testWidgets(
    'startup, retry, onboarding, protected links and session changes',
    (tester) async {
      final repository = TestAuthRepository();
      final auth = AuthViewModel(repository);
      final router = createAppRouter(auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<GoRouter>.value(value: router),
          ],
          child: const OrgLinkApp(),
        ),
      );
      expect(find.text('Loading OrgLink...'), findsOneWidget);
      repository.controller.addError(const AppFailure('Session unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Session unavailable'), findsOneWidget);
      // Stream cancellation completes on the real async event loop.
      await tester.runAsync(() async {
        await tester.tap(find.text('Try again'));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(auth.status, AuthStatus.loading);

      repository.controller.add(null);
      await tester.pump();
      expect(auth.status, AuthStatus.signedOut);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to OrgLink'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Google Sign-In'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.text('Home Dashboard'), findsNothing);
      repository.controller.add(const AuthUser(id: 'student'));
      await tester.pumpAndSettle();
      expect(find.text('Account Status'), findsOneWidget);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.text('Account Status'), findsOneWidget);
      expect(find.text('Home Dashboard'), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Google Sign-In'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
      await repository.controller.close();
    },
  );
}
