import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../organizations/presentation/viewmodels/organization_details_view_model.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../viewmodels/member_list_view_model.dart';
import '../../data/models/membership.dart';

class MemberListScreen extends StatelessWidget {
  const MemberListScreen({super.key, required this.pending});
  final bool pending;
  @override
  Widget build(BuildContext context) {
    final details = context.watch<OrganizationDetailsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          pending ? 'Membership Request Management' : 'Member Roster',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.organization(details.id)),
        ),
      ),
      body: QueryContent(
        query: details.organization,
        builder: (org) {
          if (org == null) {
            return const Center(child: Text('Organization not found.'));
          }
          if (details.membership.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!(pending ? details.isManager : details.canViewRoster)) {
            return const Center(
              child: Text('You do not have permission to access this page.'),
            );
          }
          return ChangeNotifierProvider(
            create: (_) => MemberListViewModel(
              details.repository,
              details.id,
              details.uid,
              pending: pending,
            ),
            child: _MemberList(pending: pending),
          );
        },
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.pending});
  final bool pending;
  Future<void> _review(
    BuildContext context,
    MemberListViewModel model,
    Membership member,
    bool approve,
  ) async {
    final decision = approve ? 'Approve' : 'Reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$decision Membership Request?'),
        content: Text(
          '$decision the request from ${member.applicantName.isEmpty ? member.uid : member.applicantName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(decision),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await model.review(member, approve: approve);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (approve ? 'Membership approved.' : 'Membership rejected.')
                : model.failure?.message ?? 'The request could not be updated.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MemberListViewModel>();
    return QueryContent(
      query: model.records,
      builder: (members) {
        if ((members ?? []).isEmpty) {
          return Center(
            child: Text(
              pending ? 'No pending requests.' : 'No active members.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (model.failure != null) Text(model.failure!.message),
            for (final member in members!)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.applicantName.isEmpty
                            ? member.uid
                            : member.applicantName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Role: ${displayIdentifier(member.role)} | Status: ${displayMembershipStatus(member.status)}',
                      ),
                      Text(
                        'Position: ${member.positionTitle ?? 'Not Assigned'}',
                      ),
                      Text(
                        pending
                            ? 'Requested: ${displayDate(member.requestedAt)}'
                            : 'Joined: ${displayDate(member.joinedAt)}',
                      ),
                      if (pending && member.uid != model.uid)
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton(
                              onPressed: model.processing.contains(member.uid)
                                  ? null
                                  : () => _review(context, model, member, true),
                              child: const Text('Approve'),
                            ),
                            OutlinedButton(
                              onPressed: model.processing.contains(member.uid)
                                  ? null
                                  : () =>
                                        _review(context, model, member, false),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      if (pending && member.uid == model.uid)
                        const Text('You cannot review your own request.'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
