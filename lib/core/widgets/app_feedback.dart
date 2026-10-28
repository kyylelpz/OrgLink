import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_components.dart';
import 'app_logo.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message = 'Loading OrgLink...'});

  final String message;

  @override
  Widget build(BuildContext context) => _FeedbackPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(),
        const SizedBox(height: AppSpacing.lg),
        CircularProgressIndicator(semanticsLabel: message),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(message, textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _FeedbackPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: AppIconSize.feedback,
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppActionButton(
            onPressed: onRetry,
            label: 'Try Again',
            icon: Icons.refresh,
          ),
        ],
      ],
    ),
  );
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));
  final String title, message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => _FeedbackPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon == Icons.inbox_outlined)
          Image.asset(
            'assets/illustrations/empty_state.png',
            width: 110,
            height: 110,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        else
          Icon(
            icon,
            size: AppIconSize.feedback,
            color: Theme.of(context).colorScheme.secondary,
          ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppActionButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    ),
  );
}

/// Render only after the caller has received a confirmed successful result.
class AppSuccessView extends StatelessWidget {
  const AppSuccessView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _FeedbackPanel(
    child: Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: AppIconSize.feedback,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.success),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppActionButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    ),
  );
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formWidth),
          child: child,
        ),
      ),
    ),
  );
}
