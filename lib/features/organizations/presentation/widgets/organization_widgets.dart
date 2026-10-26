import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/utils/live_query.dart';
import '../../../../core/constants/app_routes.dart';
import '../../data/models/organization.dart';

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
  });
  final Organization organization;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: OrganizationLogo(organization.logoURL),
      title: Text(organization.name),
      subtitle: Text(
        '${organization.description.isEmpty ? 'No description available.' : organization.description}\n${organization.visibility} | ${organization.status}${subtitle == null ? '' : '\n$subtitle'}',
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
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: (value) => context.go(
      [
        AppRoutes.organizations,
        AppRoutes.myOrganizations,
        AppRoutes.membershipRequests,
      ][value],
    ),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
      NavigationDestination(
        icon: Icon(Icons.groups),
        label: 'My organizations',
      ),
      NavigationDestination(
        icon: Icon(Icons.pending_actions),
        label: 'Requests',
      ),
    ],
  );
}

String displayDate(DateTime? value) => value == null
    ? 'Not recorded'
    : '${value.toLocal().year}-${value.toLocal().month.toString().padLeft(2, '0')}-${value.toLocal().day.toString().padLeft(2, '0')}';
