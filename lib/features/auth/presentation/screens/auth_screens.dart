import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_logo.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/auth_branding.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final failed =
        auth.status == AuthStatus.error ||
        auth.profileStatus == ProfileStatus.error;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: failed ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: failed ? AppColors.brandMist : AppColors.brandMidnight,
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
                    : Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppLogo(
                                variant: AppLogoVariant.onMidnight,
                                size: 260,
                              ),
                              Text(
                                'Connect. Participate. Grow.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppColors.border),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              if (!failed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: AppColors.brandPurple,
                          backgroundColor: AppColors.brandNavy,
                          semanticsLabel: 'Loading OrgLink...',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Loading OrgLink...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.border,
                        ),
                      ),
                    ],
                  ),
                ),
              if (auth.user != null) const SignOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => _EntryLayout(
    title: 'Make campus\nfeel like yours.',
    description:
        'Explore organizations, register for events, and keep track of your participation in one place.',
    onboarding: true,
    actions: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppActionButton(
          label: 'Get Started',
          onPressed: () => context.go(AppRoutes.signIn),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.signIn),
          child: const Text('Already Part of OrgLink? Sign In'),
        ),
      ],
    ),
  );
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return _EntryLayout(
      key: const ValueKey('google-sign-in'),
      title: 'Your campus.\nCloser together.',
      description:
          'Find your community, make things happen, and keep every campus moment in sync.',
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.failure != null)
            Semantics(
              liveRegion: true,
              child: Text(
                auth.failure!.message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (auth.signInCancelled)
            Semantics(
              liveRegion: true,
              child: Text(
                'Sign-in cancelled. You can try again whenever you are ready.',
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppActionButton(
            label: 'Continue With Google',
            onPressed: auth.isBusy ? null : auth.signInWithGoogle,
            style: AppActionStyle.outlined,
            icon: Icons.login,
            busy: auth.isSigningIn,
            busyLabel: 'Signing in with Google',
          ),
        ],
      ),
    );
  }
}

class _EntryLayout extends StatelessWidget {
  const _EntryLayout({
    super.key,
    required this.title,
    required this.description,
    required this.actions,
    this.onboarding = false,
  });
  final String title, description;
  final Widget actions;
  final bool onboarding;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: AppPageBody(
        maxWidth: AppLayout.formWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandMark(),
            const SizedBox(height: AppSpacing.xxl),
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: onboarding ? 34 : 36,
                  color: AppColors.brandMidnight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!onboarding) ...[
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            const CampusIllustration(),
            const SizedBox(height: AppSpacing.lg),
            if (onboarding) ...[
              Text(
                'Discover communities. Show up. Grow.',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ] else
              Text(
                'Use your school Google account to get started.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: ColoredBox(
      color: onboarding ? AppColors.white : AppColors.brandMist,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: actions,
        ),
      ),
    ),
  );
}

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (compact) {
      return IconButton(
        tooltip: auth.isSigningOut ? 'Signing Out...' : 'Sign Out',
        onPressed: auth.isBusy ? null : auth.signOut,
        icon: const Icon(Icons.logout_outlined),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: OutlinedButton(
        onPressed: auth.isBusy ? null : auth.signOut,
        child: Text(auth.isSigningOut ? 'Signing Out...' : 'Sign Out'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Account Status')),
      body: AppPageBody(
        maxWidth: AppLayout.formWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandMark(),
            const SizedBox(height: AppSpacing.xl),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppSectionHeading(
                    title: 'Account Access',
                    description: message,
                  ),
                  if (auth.failure != null)
                    Text(
                      auth.failure!.message,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  AppActionButton(
                    label: 'Edit Student Profile',
                    onPressed: auth.isBusy
                        ? null
                        : () => context.go(AppRoutes.completeProfile),
                  ),
                  TextButton(
                    onPressed: auth.isBusy ? null : auth.retry,
                    child: const Text('Refresh Status'),
                  ),
                  const SignOutButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
