import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../viewmodels/organization_details_view_model.dart';
import '../widgets/organization_widgets.dart';

class OrganizationDetailsScreen extends StatelessWidget {
  const OrganizationDetailsScreen({super.key});
  Widget _section(String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(text.isEmpty ? 'Not published yet.' : text),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final model = context.watch<OrganizationDetailsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.organizations),
        ),
      ),
      body: QueryContent(
        query: model.organization,
        builder: (org) {
          if (org == null) {
            return const Center(child: Text('Organization not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              OrganizationLogo(org.logoURL),
              const SizedBox(height: 12),
              Text(org.name, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                '${displayIdentifier(org.visibility)} | ${displayIdentifier(org.status)}',
              ),
              _section('Description', org.description),
              _section('Mission', org.mission),
              _section('Vision', org.vision),
              _section('Goals', org.goals.join('\n')),
              _section(
                'Membership Structure',
                org.positions.isEmpty
                    ? 'Manager, officers and general members. Position titles have not been published.'
                    : org.positions.join('\n'),
              ),
              _section(
                'Membership Requirements',
                org.membershipRequirements.join('\n'),
              ),
              _section(
                'Public Officers',
                org.publicOfficers.isEmpty
                    ? 'No public officer information.'
                    : org.publicOfficers
                          .map(
                            (officer) =>
                                '${officer.name} - ${officer.positionTitle}',
                          )
                          .join('\n'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Upcoming Published Events',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (model.events.loading)
                const LinearProgressIndicator()
              else if (model.events.failure != null)
                TextButton(
                  onPressed: model.events.retry,
                  child: const Text('Retry Events'),
                )
              else if ((model.events.value ?? []).isEmpty)
                const Text('No upcoming published events.')
              else
                for (final event in model.events.value!)
                  ListTile(
                    title: Text(event.title),
                    subtitle: Text(displayDate(event.startAt)),
                    onTap: () => context.go(AppRoutes.event(org.id, event.id)),
                  ),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.events),
                child: const Text('Browse Events'),
              ),
              if (model.isManager ||
                  (model.membership.value?.role == 'officer' &&
                      model.membership.value?.status == 'active' &&
                      model.membership.value?.permissions['manageEvents'] ==
                          true))
                FilledButton.tonal(
                  onPressed: () => context.go(AppRoutes.manageEvents(org.id)),
                  child: const Text('Manage Organization Events'),
                ),
              const Divider(),
              if (model.membership.loading)
                const LinearProgressIndicator()
              else if (model.membership.failure != null)
                TextButton(
                  onPressed: model.membership.retry,
                  child: const Text('Retry Membership Status'),
                )
              else ...[
                Text(
                  model.isManager
                      ? 'You manage this organization.'
                      : 'Membership: ${model.membership.value == null ? (model.submitted ? 'Pending' : 'Not a Member') : displayMembershipStatus(model.membership.value!.status)}',
                ),
                if ([
                  'rejected',
                  'removed',
                ].contains(model.membership.value?.status))
                  const Text('Reapplication is not currently available.'),
                if (model.membership.value == null && !model.isManager)
                  FilledButton(
                    onPressed: model.canRequest
                        ? () async {
                            final success = await model.request();
                            if (context.mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Membership request submitted.',
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Text(
                      model.busy
                          ? 'Submitting...'
                          : model.submitted
                          ? 'Request Pending'
                          : 'Request to Join',
                    ),
                  ),
                if (!org.acceptsRequests)
                  const Text(
                    'This organization is not accepting new requests.',
                  ),
              ],
              if (model.actionFailure != null)
                Text(
                  model.actionFailure!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (model.isManager)
                FilledButton.tonal(
                  onPressed: () => context.go(AppRoutes.manageMembers(org.id)),
                  child: const Text('Manage Membership Requests'),
                ),
              if (model.canViewRoster)
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.memberRoster(org.id)),
                  child: const Text('View Member Roster'),
                ),
            ],
          );
        },
      ),
    );
  }
}
