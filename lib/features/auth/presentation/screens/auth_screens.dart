import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../viewmodels/auth_view_model.dart';
import '../../data/models/auth_user.dart';
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
        backgroundColor:
            failed ? AppColors.brandMist : AppColors.splashBackground,
        body: SafeArea(
          child: failed
              ? AppErrorView(
                  message:
                      auth.failure?.message ?? 'Unable to load your profile.',
                  onRetry: auth.isBusy ? null : auth.retry,
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 320,
                        maxHeight: 320,
                      ),
                      child: Image.asset(
                        'assets/animations/loading_animation.webp',
                        fit: BoxFit.contain,
                        semanticLabel: 'Loading OrgLink...',
                      ),
                    ),
                  ),
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

/// Completed authentication frames 22:513 and 67:527–625.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context) => _AuthScaffold(
    key: const ValueKey('google-sign-in'),
    title: 'Welcome back!',
    description: 'Sign in to your OrgLink account',
    body: const _EmailFields(signUp: false),
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('New to OrgLink?'),
            TextButton(
              onPressed: context.watch<AuthViewModel>().isBusy
                  ? null
                  : () => context.push(AppRoutes.signUp),
              child: const Text('Create an Account'),
            ),
          ],
        ),
        const _TermsNote(),
      ],
    ),
  );
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});
  @override
  Widget build(BuildContext context) => _AuthFlowBack(
    child: _AuthScaffold(
      title: 'Create your account',
      description: 'Join your campus on OrgLink',
      body: const _EmailFields(signUp: true),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already have an account?'),
              TextButton(
                onPressed: context.watch<AuthViewModel>().isBusy
                    ? null
                    : () => context.go(AppRoutes.signIn),
                child: const Text('Sign In'),
              ),
            ],
          ),
          const _TermsNote(),
        ],
      ),
    ),
  );
}

class _TermsNote extends StatelessWidget {
  const _TermsNote();
  @override
  Widget build(BuildContext context) => Text(
    'By continuing, you agree to our Terms of Service and Privacy Policy.',
    textAlign: TextAlign.center,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontSize: 12, color: AppColors.muted),
  );
}

class _EmailFields extends StatefulWidget {
  const _EmailFields({required this.signUp});
  final bool signUp;
  @override
  State<_EmailFields> createState() => _EmailFieldsState();
}

class _EmailFieldsState extends State<_EmailFields> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('auth-email'),
            controller: email,
            enabled: !auth.isBusy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: _authInput(
              widget.signUp ? 'Email Address' : 'Email Address',
            ),
            validator: AuthInput.email,
          ),
          const SizedBox(height: AppSpacing.md),
          _PasswordField(
            key: const ValueKey('auth-password'),
            controller: password,
            enabled: !auth.isBusy,
            label: widget.signUp ? 'Create Password' : 'Password',
            newPassword: widget.signUp,
            validator: widget.signUp
                ? AuthInput.newPassword
                : (value) => value == null || value.isEmpty
                      ? 'Enter your password.'
                      : null,
          ),
          if (widget.signUp) ...[
            const SizedBox(height: AppSpacing.md),
            _PasswordField(
              key: const ValueKey('auth-confirm'),
              controller: confirm,
              enabled: !auth.isBusy,
              label: 'Confirm Password',
              newPassword: true,
              validator: (value) => value == null || value.isEmpty
                  ? 'Confirm your password.'
                  : value != password.text
                  ? 'Passwords do not match.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Use your email address. Your campus profile will be set up after sign-up.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: auth.isBusy
                    ? null
                    : () => context.push(AppRoutes.forgotPassword),
                child: const Text('Forgot Password?'),
              ),
            ),
          if (widget.signUp) const SizedBox(height: AppSpacing.md),
          AppActionButton(
            label: widget.signUp ? 'Create Account' : 'Sign In',
            busy: auth.isBusy,
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              if (widget.signUp) {
                await auth.registerWithEmail(email.text, password.text);
              } else {
                await auth.signInWithEmail(email.text, password.text);
              }
            },
          ),
          const _AuthFeedback(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'or',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: auth.isBusy ? null : auth.signInWithGoogle,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandMidnight,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (auth.isSigningIn)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Image.asset(
                    'assets/icons/auth_google.png',
                    width: 20,
                    height: 20,
                    excludeFromSemantics: true,
                  ),
                const SizedBox(width: AppSpacing.sm),
                const Flexible(
                  child: Text(
                    'Continue With Google',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _authInput(String label) => InputDecoration(
  labelText: label,
  constraints: const BoxConstraints(minHeight: 64),
  contentPadding: const EdgeInsets.all(12),
);

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.newPassword = false,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool enabled, newPassword;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: hidden,
    enableSuggestions: false,
    autocorrect: false,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    decoration: _authInput(widget.label).copyWith(
      suffixIcon: IconButton(
        tooltip: hidden ? 'Show Password' : 'Hide Password',
        onPressed: widget.enabled
            ? () => setState(() => hidden = !hidden)
            : null,
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: widget.validator,
  );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return _AuthFlowBack(
      child: _AuthScaffold(
        title: 'Reset your password',
        description: "Enter your email and we'll send you a reset link",
        footer: const _BackToSignIn(),
        body: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('reset-email'),
                controller: email,
                enabled: !auth.isBusy,
                keyboardType: TextInputType.emailAddress,
                decoration: _authInput('Email Address'),
                validator: AuthInput.email,
              ),
              const SizedBox(height: AppSpacing.md),
              AppActionButton(
                label: 'Send Reset Link',
                busy: auth.isBusy,
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  final success = await auth.forgotPassword(email.text);
                  if (context.mounted && success) {
                    context.go(AppRoutes.resetEmailSent);
                  }
                },
              ),
              const _AuthFeedback(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'If this address can receive a reset email, a link will arrive shortly. Check your inbox and spam folder.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.brandNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthViewModel>().checkVerification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return _AuthFlowBack(
      onBack: auth.signOut,
      child: _AuthScaffold(
        centered: true,
        title: 'Check your email',
        description: 'We sent a verification link to your email address.',
        illustration: 'verify',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EmailCard(email: auth.user?.email ?? ''),
            Text(
              "Didn't receive it? Check your spam folder or request a new link below.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: AppColors.brandNavy,
              ),
            ),
            const _AuthFeedback(),
          ],
        ),
        whiteFooter: true,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppActionButton(
              label: 'Resend Verification Email',
              style: AppActionStyle.outlined,
              busy: auth.isBusy,
              onPressed: auth.resendVerification,
            ),
            TextButton(
              onPressed: auth.isBusy ? null : auth.signOut,
              child: const Text('Back to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetEmailSentScreen extends StatelessWidget {
  const ResetEmailSentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return _AuthFlowBack(
      child: _AuthScaffold(
        centered: true,
        illustration: 'sent',
        title: 'Reset link sent',
        description:
            'If this address can receive a reset email, instructions will arrive shortly.',
        whiteFooter: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EmailCard(
              email: auth.resetEmail ?? 'Enter your email to request a link.',
            ),
            Text(
              "Open the latest link before it expires. Didn't receive it? Check your spam or request a new link.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: AppColors.brandNavy,
              ),
            ),
            const _AuthFeedback(),
          ],
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppActionButton(
              label: 'Resend Reset Email',
              style: AppActionStyle.outlined,
              busy: auth.isBusy,
              onPressed: auth.resetEmail == null
                  ? () => context.go(AppRoutes.forgotPassword)
                  : () => auth.forgotPassword(auth.resetEmail!),
            ),
            const _BackToSignIn(),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.code});
  final String code;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(), confirm = TextEditingController();
  bool checked = false, valid = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(ResetPasswordScreen old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      checked = false;
      valid = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    if (!mounted) return;
    final code = widget.code;
    final result = await context.read<AuthViewModel>().verifyResetCode(code);
    if (mounted && widget.code == code) {
      setState(() {
        checked = true;
        valid = result;
      });
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return _AuthFlowBack(
      child: _AuthScaffold(
        title: 'Create new password',
        description: 'Choose a strong password for your OrgLink account.',
        footer: const _BackToSignIn(),
        body: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!checked)
                const LinearProgressIndicator(
                  semanticsLabel: 'Checking reset link',
                ),
              _PasswordField(
                key: const ValueKey('new-password'),
                controller: password,
                label: 'New Password',
                newPassword: true,
                enabled: valid && !auth.isBusy,
                validator: AuthInput.newPassword,
              ),
              const SizedBox(height: AppSpacing.md),
              _PasswordField(
                key: const ValueKey('confirm-password'),
                controller: confirm,
                label: 'Confirm New Password',
                newPassword: true,
                enabled: valid && !auth.isBusy,
                validator: (value) => value == null || value.isEmpty
                    ? 'Confirm your password.'
                    : value != password.text
                    ? 'Passwords do not match.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Password must be at least 8 characters and include a number or special character.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppActionButton(
                label: 'Save New Password',
                busy: auth.isBusy,
                onPressed: !valid
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        final success = await auth.confirmPasswordReset(
                          widget.code,
                          password.text,
                        );
                        if (context.mounted && success) {
                          context.go(AppRoutes.resetSuccess);
                        }
                      },
              ),
              const _AuthFeedback(),
              if (checked && !valid)
                AppActionButton(
                  label: 'Request a New Link',
                  style: AppActionStyle.text,
                  onPressed: () => context.go(AppRoutes.forgotPassword),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PasswordResetSuccessScreen extends StatelessWidget {
  const PasswordResetSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) => _AuthFlowBack(
    child: _AuthScaffold(
      centered: true,
      illustration: 'check',
      title: 'Password updated',
      description:
          'Your password has been reset successfully. You can now sign in with your new password.',
      body: Text(
        'Other sessions may need to sign in again for your security.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: AppColors.brandNavy,
        ),
      ),
      whiteFooter: true,
      footer: AppActionButton(
        label: 'Sign In to OrgLink',
        onPressed: () => context.go(AppRoutes.signIn),
      ),
    ),
  );
}

class EmailActionScreen extends StatefulWidget {
  const EmailActionScreen({super.key, required this.code});
  final String code;
  @override
  State<EmailActionScreen> createState() => _EmailActionScreenState();
}

class _EmailActionScreenState extends State<EmailActionScreen> {
  bool finished = false, success = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final result = await context.read<AuthViewModel>().applyEmailVerification(
        widget.code,
      );
      if (mounted) {
        setState(() {
          finished = true;
          success = result;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => _AuthFlowBack(
    child: _AuthScaffold(
      centered: true,
      illustration: 'verify',
      title: success ? 'Email verified' : 'Verify your email',
      description: !finished
          ? 'Checking your verification link...'
          : success
          ? 'Sign in to continue. Account approval is still required.'
          : 'This verification link could not be used. Request a new email and try again.',
      body: Column(
        children: [
          if (!finished) const LinearProgressIndicator(),
          const _AuthFeedback(),
        ],
      ),
      footer: TextButton(
        onPressed: () => context.go(AppRoutes.signIn),
        child: const Text('Back to Sign In'),
      ),
    ),
  );
}

class InvalidEmailActionScreen extends StatelessWidget {
  const InvalidEmailActionScreen({super.key});
  @override
  Widget build(BuildContext context) => _AuthFlowBack(
    child: _AuthScaffold(
      title: 'Link Unavailable',
      description: 'Request a new email and open its latest link.',
      body: const SizedBox.shrink(),
      footer: const _BackToSignIn(),
    ),
  );
}

class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.email});
  final String email;
  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sent to',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(email, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _AuthFeedback extends StatelessWidget {
  const _AuthFeedback();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                auth.failure!.message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (auth.signInCancelled)
            const Text(
              'Sign-in cancelled. You can try again whenever you are ready.',
            ),
          if (auth.message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                auth.message!,
                style: const TextStyle(color: AppColors.brandNavy),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackToSignIn extends StatelessWidget {
  const _BackToSignIn();
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: context.watch<AuthViewModel>().isBusy
        ? null
        : () => context.go(AppRoutes.signIn),
    child: const Text('← Back to Sign In'),
  );
}

/// Layout adapted from the completed Figma frames, using existing theme components.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.body,
    required this.footer,
    this.centered = false,
    this.illustration,
    this.whiteFooter = false,
  });
  final String title, description;
  final Widget body, footer;
  final bool centered, whiteFooter;
  final String? illustration;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, centered ? 88 : 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!centered) ...[
                    const AuthBrandMark(size: 28),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  if (illustration != null) ...[
                    Center(
                      child: illustration == 'check'
                          ? Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: AppColors.tonal,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/icons/auth_check.png',
                                width: 36,
                                height: 36,
                                excludeFromSemantics: true,
                              ),
                            )
                          : Image.asset(
                              'assets/icons/auth_$illustration.png',
                              width: 72,
                              height: 72,
                              excludeFromSemantics: true,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: centered ? 30 : 28,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandMidnight,
                          ),
                    ),
                  ),
                  SizedBox(height: centered ? AppSpacing.lg : AppSpacing.xs),
                  Text(
                    description,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  body,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        color: whiteFooter ? AppColors.white : AppColors.brandMist,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: footer,
        ),
      ),
    ),
  );
}

class LinkPasswordScreen extends StatefulWidget {
  const LinkPasswordScreen({super.key});
  @override
  State<LinkPasswordScreen> createState() => _LinkPasswordScreenState();
}

class _LinkPasswordScreenState extends State<LinkPasswordScreen> {
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Password'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.completeProfile),
        ),
      ),
      body: AppPageBody(
        maxWidth: AppLayout.formWidth,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeading(
                title: 'Add a Sign-In Method',
                description:
                    'Confirm your Google account to add a password to this same account. Your profile and memberships stay with the same user ID.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: AuthInput.newPassword,
              ),
              AppActionButton(
                label: 'Confirm Google and Link Password',
                busy: auth.isBusy,
                onPressed: () {
                  if (form.currentState!.validate()) {
                    auth.linkPassword(password.text);
                  }
                },
              ),
              if (auth.message != null) Text(auth.message!),
              if (auth.failure != null)
                Text(
                  auth.failure!.message,
                  style: const TextStyle(color: AppColors.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Native Back from direct auth deep links returns to Sign-In; pushed forms pop.
class _AuthFlowBack extends StatelessWidget {
  const _AuthFlowBack({required this.child, this.onBack});
  final Widget child;
  final Future<void> Function()? onBack;
  @override
  Widget build(BuildContext context) {
    Future<bool> back() async {
      if (onBack != null) {
        await onBack!();
        return true;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.signIn);
      }
      return true;
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: BackButtonListener(onBackButtonPressed: back, child: child),
    );
  }
}

class _EntryLayout extends StatelessWidget {
  const _EntryLayout({
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
                'Use your email or Google account to get started.',
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
        // Made the icon red to indicate a destructive action
        icon: const Icon(Icons.logout_outlined, color: AppColors.error),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: OutlinedButton(
        onPressed: auth.isBusy ? null : auth.signOut,
        style: OutlinedButton.styleFrom(
          // Dark red border and text
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          minimumSize: const Size(
            double.infinity,
            48,
          ), // Full width for better tapping
        ),
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
      'rejected' =>
        'Your account application was not approved. Contact your school for assistance.',
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
