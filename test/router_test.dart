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
    AppRoutes.events,
    AppRoutes.myEvents,
    '/organizations/example/events/new',
    '/organizations/example/events/demo/registration',
    '/organizations/example/events/demo/participants',
    AppRoutes.organizations,
    AppRoutes.myOrganizations,
    AppRoutes.membershipRequests,
    '/organizations/example/requests',
    '/organizations/example/members',
    '/unknown',
  ];
  test('unresolved auth cannot access protected routes', () {
    for (final status in [AuthStatus.loading, AuthStatus.error]) {
      for (final path in paths) {
        expect(
          authRedirect(status, path),
          path == AppRoutes.splash ? null : AppRoutes.splash,
        );
      }
    }
  });
  test('signed-out startup goes directly to sign-in', () {
    for (final path in paths) {
      expect(
        authRedirect(AuthStatus.signedOut, path),
        [AppRoutes.onboarding, AppRoutes.signIn].contains(path)
            ? null
            : AppRoutes.signIn,
      );
    }
  });
  test('every profile state has stable route without redirect loops', () {
    for (final state in ProfileStatus.values) {
      for (final eligible in [false, true]) {
        for (final path in paths) {
          final target = authRedirect(
            AuthStatus.signedIn,
            path,
            profileStatus: state,
            eligible: eligible,
          );
          if (target != null) {
            expect(
              authRedirect(
                AuthStatus.signedIn,
                target,
                profileStatus: state,
                eligible: eligible,
              ),
              isNull,
            );
          }
        }
      }
    }
    expect(
      authRedirect(
        AuthStatus.signedIn,
        AppRoutes.home,
        profileStatus: ProfileStatus.incomplete,
      ),
      AppRoutes.completeProfile,
    );
    expect(
      authRedirect(
        AuthStatus.signedIn,
        AppRoutes.home,
        profileStatus: ProfileStatus.ready,
      ),
      AppRoutes.accountStatus,
    );
    expect(
      authRedirect(
        AuthStatus.signedIn,
        AppRoutes.signIn,
        profileStatus: ProfileStatus.ready,
        eligible: true,
      ),
      AppRoutes.home,
    );
  });
}
