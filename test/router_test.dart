import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  const paths = [
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.signIn,
    AppRoutes.completeProfile,
    AppRoutes.accountStatus,
    AppRoutes.home,
    '/unknown',
  ];

  test('unresolved or failed sessions can only see splash', () {
    for (final status in [AuthStatus.loading, AuthStatus.error]) {
      for (final path in paths) {
        expect(
          authRedirect(status, path),
          path == AppRoutes.splash ? null : AppRoutes.splash,
        );
      }
    }
  });

  test('signed-out sessions cannot open protected deep links', () {
    for (final path in [
      AppRoutes.completeProfile,
      AppRoutes.accountStatus,
      AppRoutes.home,
    ]) {
      expect(authRedirect(AuthStatus.signedOut, path), AppRoutes.signIn);
    }
    expect(
      authRedirect(AuthStatus.signedOut, AppRoutes.splash),
      AppRoutes.onboarding,
    );
    expect(authRedirect(AuthStatus.signedOut, AppRoutes.onboarding), isNull);
    expect(authRedirect(AuthStatus.signedOut, AppRoutes.signIn), isNull);
  });

  test('authentication alone cannot grant dashboard or profile access', () {
    for (final path in paths) {
      expect(
        authRedirect(AuthStatus.signedIn, path),
        path == AppRoutes.accountStatus ? null : AppRoutes.accountStatus,
      );
    }
  });
}
