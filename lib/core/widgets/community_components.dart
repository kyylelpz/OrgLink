import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'app_logo.dart';
import 'app_asset_icon.dart';

/// A shared introduction for community and participation destinations.
class CommunityHeader extends StatelessWidget {
  const CommunityHeader({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.auto_awesome_outlined,
    this.emphasized = false,
  });
  final String title, description;
  final IconData icon;
  final bool emphasized;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = emphasized ? AppColors.white : AppColors.brandMidnight;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppShape.feature,
        color: emphasized ? null : AppColors.white,
        gradient: emphasized
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandMidnight, AppColors.brandNavy],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: emphasized ? AppColors.white : AppColors.brandBlue,
            size: 28,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(color: foreground),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class CommunityQuickAction extends StatelessWidget {
  const CommunityQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.asset,
  });
  final String? asset;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: AppShape.button,
    child: InkWell(
      onTap: onPressed,
      borderRadius: AppShape.button,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppLayout.minTouchTarget,
              height: AppLayout.minTouchTarget,
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: AppShape.button,
              ),
              alignment: Alignment.center,
              child: asset == null
                  ? Icon(icon, size: 21, color: AppColors.brandBlue)
                  : AppAssetIcon(asset!, size: 21),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.brandNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Home-specific composition, keeping the generic CommunityHeader API intact.
class CommunityDashboardHeader extends StatelessWidget {
  const CommunityDashboardHeader({
    super.key,
    required this.greeting,
    required this.initials,
    required this.search,
    required this.onNotifications,
    required this.onProfile,
  });
  final String greeting, initials;
  final Widget search;
  final VoidCallback onNotifications, onProfile;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: Container(
      decoration: const BoxDecoration(
        color: AppColors.brandMidnight,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppShape.featureRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.contentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                6,
                AppSpacing.xl,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: AppShape.field,
                          ),
                          child: AppLogo(size: 40),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'OrgLink',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.white,
                                fontSize: 22,
                                letterSpacing: -0.7,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: onNotifications,
                        icon: const AppAssetIcon(
                          'bell',
                          size: 22,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                greeting,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontSize: 30,
                                      height: 1.15,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'A good day to get involved.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.border,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Semantics(
                        button: true,
                        label: 'Edit Student Profile',
                        child: ExcludeSemantics(
                          child: Material(
                            color: AppColors.tonal,
                            borderRadius: AppShape.card,
                            child: InkWell(
                              onTap: onProfile,
                              borderRadius: AppShape.card,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.brandBlue,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  search,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CommunitySectionHeading extends StatelessWidget {
  const CommunitySectionHeading({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });
  final String title, actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.brandMidnight),
        ),
      ),
      TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
        child: Text(actionLabel),
      ),
    ],
  );
}
