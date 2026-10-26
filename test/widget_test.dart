import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'support/test_auth_repository.dart';

void main() {
  testWidgets(
    'Google sign-in, validation, profile saving, status changes and sign-out',
    (tester) async {
      final repository = TestAuthRepository();
      final profiles = TestProfileRepository();
      final auth = AuthViewModel(repository, profiles);
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
      repository.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Google Sign-In'), findsOneWidget);
      repository.cancelSignIn = true;
      await tester.tap(find.text('Continue With Google'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sign-in cancelled'), findsOneWidget);
      repository.cancelSignIn = false;
      await tester.tap(find.text('Continue With Google'));
      await tester.pump();
      profiles.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Student Profile'), findsOneWidget);
      await tester.ensureVisible(find.text('Save Student Profile'));
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Use 3?30 letters, digits or hyphens.'), findsOneWidget);
      expect(find.text('Select a year level.'), findsOneWidget);
      final fields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(fields.at(0)).initialValue,
        student.email,
      );
      await tester.enterText(fields.at(2), '2026-001');
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year 1').last);
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(3), 'A');
      await tester.ensureVisible(find.text('Save Student Profile'));
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Home Dashboard'), findsOneWidget);
      expect(profiles.saveCalls, 1);
      await tester.tap(find.text('Edit Student Profile'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .controller
            ?.text,
        '2026-001',
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      profiles.controller.add(profile(status: 'suspended'));
      await tester.pumpAndSettle();
      expect(find.text('Account Status'), findsOneWidget);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.text('Home Dashboard'), findsNothing);
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.text('Google Sign-In'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
      await repository.controller.close();
      await profiles.controller.close();
    },
  );
}
