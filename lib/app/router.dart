import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../core/widgets/placeholder_screen.dart';
import '../features/auth/presentation/screens/auth_screens.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/profile/presentation/screens/complete_profile_screen.dart';

GoRouter createAppRouter(AuthViewModel auth) => GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: auth,
  redirect: (_, state) => authRedirect(auth.status, state.uri.path),
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, _) => const OnboardingScreen(),
    ),
    GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
    GoRoute(
      path: AppRoutes.completeProfile,
      builder: (_, _) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.accountStatus,
      builder: (_, _) => const AccountStatusScreen(),
    ),
    GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
  ],
  errorBuilder: (context, _) => PlaceholderScreen(
    title: 'Page unavailable',
    message: 'This page could not be found.',
    action: FilledButton(
      onPressed: () => context.go(AppRoutes.splash),
      child: const Text('Return to OrgLink'),
    ),
  ),
);

String? authRedirect(AuthStatus status, String path) {
  if (status == AuthStatus.loading || status == AuthStatus.error) {
    return path == AppRoutes.splash ? null : AppRoutes.splash;
  }
  final isPublic = path == AppRoutes.onboarding || path == AppRoutes.signIn;
  if (status == AuthStatus.signedOut) {
    if (path == AppRoutes.splash) return AppRoutes.onboarding;
    return isPublic ? null : AppRoutes.signIn;
  }
  // Fail closed until a defined profile schema and trusted eligibility checks
  // can distinguish profile completion, account status and authorized roles.
  return path == AppRoutes.accountStatus ? null : AppRoutes.accountStatus;
}
