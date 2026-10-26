import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/placeholder_screen.dart';
import '../viewmodels/auth_view_model.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      body: SafeArea(
        child: auth.status == AuthStatus.error
            ? AppErrorView(message: auth.failure!.message, onRetry: auth.retry)
            : const AppLoadingView(),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: 'Welcome to OrgLink',
    message: 'Your student organization community starts here.',
    action: FilledButton(
      onPressed: () => context.go(AppRoutes.signIn),
      child: const Text('Get started'),
    ),
  );
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Google Sign-In',
    message: 'Google Sign-In will be available in a future update.',
    action: FilledButton(onPressed: null, child: Text('Continue with Google')),
  );
}

class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return PlaceholderScreen(
      title: 'Account Status',
      message:
          'You are signed in. Student profile and account eligibility '
          'checks are not available yet. Dashboard access is currently unavailable.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (auth.failure != null) ...[
            Text(auth.failure!.message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],
          if (auth.isSigningOut)
            const CircularProgressIndicator()
          else
            OutlinedButton(
              onPressed: auth.signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
    );
  }
}
