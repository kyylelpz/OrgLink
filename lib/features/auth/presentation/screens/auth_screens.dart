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
    final failed =
        auth.status == AuthStatus.error ||
        auth.profileStatus == ProfileStatus.error;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: failed
                  ? AppErrorView(
                      message:
                          auth.failure?.message ??
                          'Unable to load your profile.',
                      onRetry: auth.isBusy ? null : auth.retry,
                    )
                  : const AppLoadingView(),
            ),
            if (auth.user != null) const SignOutButton(),
          ],
        ),
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
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return PlaceholderScreen(
      title: 'Google Sign-In',
      message: 'Sign in with your Google account to continue to OrgLink.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (auth.failure != null)
            Text(auth.failure!.message, textAlign: TextAlign.center),
          if (auth.signInCancelled)
            const Text(
              'Sign-in cancelled. You can try again whenever you are ready.',
            ),
          const SizedBox(height: 16),
          if (auth.isSigningIn)
            const CircularProgressIndicator()
          else
            FilledButton.icon(
              onPressed: auth.isBusy ? null : auth.signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Continue with Google'),
            ),
        ],
      ),
    );
  }
}

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: OutlinedButton(
        onPressed: auth.isBusy ? null : auth.signOut,
        child: Text(auth.isSigningOut ? 'Signing out...' : 'Sign out'),
      ),
    );
  }
}

class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final message = switch (auth.profile?.accountStatus) {
      'pending' => 'Your account is awaiting approval.',
      'suspended' =>
        'Your account is suspended. Contact your school for assistance.',
      'disabled' =>
        'Your account is disabled. Contact your school for assistance.',
      _ =>
        'Your account is not eligible for dashboard access. Contact your school for assistance.',
    };
    return PlaceholderScreen(
      title: 'Account Status',
      message: message,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (auth.failure != null) Text(auth.failure!.message),
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () => context.go(AppRoutes.completeProfile),
            child: const Text('Edit student profile'),
          ),
          TextButton(
            onPressed: auth.isBusy ? null : auth.retry,
            child: const Text('Refresh status'),
          ),
          const SignOutButton(),
        ],
      ),
    );
  }
}
