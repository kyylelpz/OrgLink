import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/utils/live_query.dart';
import '../../../../core/constants/app_routes.dart';
import '../../data/models/organization.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';

class QueryContent<T> extends StatelessWidget {
  const QueryContent({super.key, required this.query, required this.builder});
  final LiveQuery<T> query;
  final Widget Function(T? value) builder;
  @override
  Widget build(BuildContext context) {
    if (query.loading) return const AppLoadingView();
    if (query.failure != null) {
      return AppErrorView(
        message: query.failure!.message,
        onRetry: query.retry,
      );
    }
    return builder(query.value);
  }
}

/// Dynamic organization artwork is contained, never cropped or replaced by OrgLink branding.
class OrganizationLogo extends StatelessWidget {
  const OrganizationLogo(this.url, {super.key, this.size = 48});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.tonal,
        borderRadius: AppShape.card,
      ),
      child: url == null || url!.trim().isEmpty
          ? Icon(
              Icons.groups_outlined,
              size: size / 2,
              color: AppColors.brandBlue,
            )
          : Image.network(
              url!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.groups_outlined,
                size: size / 2,
                color: AppColors.brandBlue,
              ),
            ),
    ),
  );
}

/// Shared discovery, membership and Home preview presentation.
/// Callers retain their existing route semantics and membership decisions.
class OrganizationCard extends StatelessWidget {
  const OrganizationCard({
    super.key,
    required this.organization,
    this.subtitle,
    this.preview = false,
    this.status,
    this.actionLabel = 'View Organization',
    this.onTap,
  });
  final Organization organization;
  final String? subtitle;
  final bool preview;
  final Widget? status;
  final String actionLabel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    void open() {
      if (onTap != null) {
        onTap!();
      } else if (preview) {
        context.push(AppRoutes.organization(organization.id));
      } else {
        context.go(AppRoutes.organization(organization.id));
      }
    }

    return AppSurfaceCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrganizationLogo(organization.logoURL),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.brandMidnight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!preview) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${displayIdentifier(organization.visibility)} | ${displayIdentifier(organization.status)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            organization.description.isEmpty
                ? 'No description available.'
                : organization.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (status != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(alignment: Alignment.centerLeft, child: status!),
          ],
          const SizedBox(height: AppSpacing.xs),
          if (preview)
            Text(
              actionLabel,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.brandBlue),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: AppActionButton(
                label: actionLabel,
                icon: Icons.arrow_forward,
                style: AppActionStyle.text,
                onPressed: open,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact Figma page hierarchy, with adaptive height for large text.
class OrganizationPageHeading extends StatelessWidget {
  const OrganizationPageHeading({
    super.key,
    required this.title,
    required this.description,
  });
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.brandMidnight,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        description,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpacing.lg),
    ],
  );
}

class OrganizationNavigation extends StatelessWidget {
  const OrganizationNavigation(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ColoredBox(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            for (final entry in [
              ('Discover', AppRoutes.organizations),
              ('My Organizations', AppRoutes.myOrganizations),
              ('Requests', AppRoutes.membershipRequests),
            ].indexed)
              AppFilterChip(
                label: entry.$2.$1,
                selected: index == entry.$1,
                onSelected: (_) => context.go(entry.$2.$2),
              ),
          ],
        ),
      ),
    ),
  );
}

String displayDate(DateTime? value) => value == null
    ? 'Not recorded'
    : '${value.toLocal().year}-${value.toLocal().month.toString().padLeft(2, '0')}-${value.toLocal().day.toString().padLeft(2, '0')}';

/// Canonical statuses are read only to choose a presentation color.
AppStatusTone membershipStatusTone(String status) => switch (status) {
  'active' => AppStatusTone.success,
  'pending' => AppStatusTone.warning,
  'rejected' || 'removed' => AppStatusTone.error,
  _ => AppStatusTone.neutral,
};
