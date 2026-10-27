import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/organization_hub_view_model.dart';
import '../widgets/organization_widgets.dart';

class MyOrganizationsScreen extends StatelessWidget {
  const MyOrganizationsScreen({super.key, this.requestsOnly = false});
  final bool requestsOnly;
  @override
  Widget build(BuildContext context) {
    final model = context.watch<OrganizationHubViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(requestsOnly ? 'Membership Requests' : 'My Organizations'),
        leading: const AppBackButton(),
      ),
      bottomNavigationBar: OrganizationNavigation(requestsOnly ? 2 : 1),
      body: QueryContent(
        query: model.mine,
        builder: (records) {
          final memberships =
              (records ?? [])
                  .where((member) => !requestsOnly || member.role != 'manager')
                  .toList()
                ..sort((a, b) => a.organizationId.compareTo(b.organizationId));
          final membershipIds = memberships
              .map((member) => member.organizationId)
              .toSet();
          final assignedOnly = (model.managed.value ?? [])
              .where((org) => !membershipIds.contains(org.id))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!requestsOnly) ...[
                if (model.managed.failure != null)
                  TextButton(
                    onPressed: model.managed.retry,
                    child: const Text('Retry Managed Organizations'),
                  ),
                if (assignedOnly.isNotEmpty)
                  const Text('Organizations You Manage'),
                for (final org in assignedOnly)
                  OrganizationCard(
                    organization: org,
                    subtitle: 'Assigned Organization Manager',
                  ),
              ],
              if (memberships.isEmpty)
                Text(
                  requestsOnly
                      ? 'No membership requests yet.'
                      : 'You have no organization memberships yet.',
                ),
              for (final member in memberships)
                Builder(
                  builder: (context) {
                    final query = model.associated[member.organizationId];
                    final org = query?.value;
                    final summary =
                        'Role: ${displayIdentifier(member.role)} | Status: ${displayMembershipStatus(member.status)}\nPosition: ${member.positionTitle ?? 'Not Assigned'}\nRequested: ${displayDate(member.requestedAt)}';
                    if (org != null) {
                      return OrganizationCard(
                        organization: org,
                        subtitle: summary,
                      );
                    }
                    return Card(
                      child: ListTile(
                        title: Text(
                          query?.loading == true
                              ? 'Loading organization...'
                              : 'Organization Unavailable',
                        ),
                        subtitle: Text(
                          '$summary\n${query?.failure?.message ?? 'Details may no longer be available to your account.'}',
                        ),
                        trailing: query?.failure == null
                            ? null
                            : IconButton(
                                onPressed: query!.retry,
                                icon: const Icon(Icons.refresh),
                              ),
                        onTap: () => context.go(
                          AppRoutes.organization(member.organizationId),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
