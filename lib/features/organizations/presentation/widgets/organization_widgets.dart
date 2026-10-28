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

class OrganizationLogo extends StatelessWidget {
  const OrganizationLogo(this.url, {super.key});
  final String? url;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: url == null || url!.isEmpty
        ? const Icon(Icons.groups, size: 40)
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.groups, size: 40),
          ),
  );
}

class OrganizationCard extends StatelessWidget {
  const OrganizationCard({
    super.key,
    required this.organization,
    this.subtitle,
    this.preview = false,
  });
  final Organization organization;
  final String? subtitle;
  final bool preview;
  @override
  Widget build(BuildContext context) => preview
      ? AppSurfaceCard(
          onTap: () => context.push(AppRoutes.organization(organization.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: AppShape.card,
                    child: OrganizationLogo(organization.logoURL),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      organization.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.brandMidnight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                'View Organization',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.brandBlue),
              ),
            ],
          ),
        )
      : Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: OrganizationLogo(organization.logoURL),
            title: Text(organization.name),
            subtitle: Text(
              '${organization.description.isEmpty ? 'No description available.' : organization.description}\n${displayIdentifier(organization.visibility)} | ${displayIdentifier(organization.status)}${subtitle == null ? '' : '\n$subtitle'}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.organization(organization.id)),
          ),
        );
}

class OrganizationNavigation extends StatelessWidget {
  const OrganizationNavigation(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.go(AppRoutes.organizations),
          child: const Text('Discover'),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.myOrganizations),
          child: const Text('My Organizations'),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.membershipRequests),
          child: const Text('Requests'),
        ),
      ],
    ),
  );
}

String displayDate(DateTime? value) => value == null
    ? 'Not recorded'
    : '${value.toLocal().year}-${value.toLocal().month.toString().padLeft(2, '0')}-${value.toLocal().day.toString().padLeft(2, '0')}';
