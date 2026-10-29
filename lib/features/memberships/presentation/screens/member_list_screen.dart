import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          backgroundColor: AppColors.brandMidnight,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppShape.featureRadius),
            ),
          ),
          title: Text(pending ? 'Membership Requests' : 'Member Roster'),
          leading: const AppBackButton(),
        ),
        body: QueryContent(
          query: details.organization,
          builder: (org) {
            if (org == null) {
              return const AppEmptyView(
                title: 'Organization Unavailable',
                message: 'Organization not found.',
              );
            }
            if (details.membership.loading) {
              return const AppLoadingView(
                message: 'Loading membership access...',
              );
            }
            if (!(pending ? details.isManager : details.canViewRoster)) {
              return const AppEmptyView(
                title: 'Access Unavailable',
                message: 'You do not have permission to access this page.',
              );
            }
            return ChangeNotifierProvider(
              create: (_) => MemberListViewModel(
                details.repository,
                details.id,
                details.uid,
                pending: pending,
              ),
              child: _MemberList(pending: pending, organizationName: org.name),
            );
          },
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.pending, required this.organizationName});
  final bool pending;
  final String organizationName;

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
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: AppColors.brandMidnight),
        icon: Icon(
          approve ? Icons.person_add_alt : Icons.person_remove_outlined,
          color: approve ? AppColors.brandBlue : AppColors.error,
        ),
        title: Text('$decision Membership Request?'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              organizationName,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.brandBlue),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$decision the request from ${member.applicantName.isEmpty ? member.uid : member.applicantName}?',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              approve
                  ? 'Approval changes the membership from pending to active with the member role. It does not assign officer permissions.'
                  : 'Rejection closes this membership request. Reapplication is not currently available.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          AppActionButton(
            label: decision,
            style: approve
                ? AppActionStyle.primary
                : AppActionStyle.destructive,
            onPressed: () => Navigator.pop(context, true),
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
        return AppPageBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                OrganizationPageHeading(
                  title: pending ? 'Review Memberships' : 'Your Community',
                  description: organizationName,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (model.failure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Text(
                      model.failure!.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if ((members ?? []).isEmpty)
                  AppEmptyView(
                    title: pending ? 'Requests Reviewed' : 'No Members Yet',
                    message: pending
                        ? 'No pending requests.'
                        : 'No active members.',
                  ),
                for (final member in members ?? <Membership>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: MembershipMemberCard(
                      member: member,
                      pending: pending,
                      actions: pending && member.uid != model.uid
                          ? Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.sm,
                              children: [
                                AppActionButton(
                                  label: 'Approve',
                                  style: AppActionStyle.tonal,
                                  busy: model.processing.contains(member.uid),
                                  onPressed: () =>
                                      _review(context, model, member, true),
                                ),
                                AppActionButton(
                                  label: 'Reject',
                                  style: AppActionStyle.outlined,
                                  onPressed:
                                      model.processing.contains(member.uid)
                                      ? null
                                      : () => _review(
                                          context,
                                          model,
                                          member,
                                          false,
                                        ),
                                ),
                              ],
                            )
                          : pending
                          ? const Text('You cannot review your own request.')
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One adaptive member identity for both the roster and request queue.
class MembershipMemberCard extends StatelessWidget {
  const MembershipMemberCard({
    super.key,
    required this.member,
    required this.pending,
    this.actions,
  });
  final Membership member;
  final bool pending;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.tonal,
                    borderRadius: AppShape.card,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.applicantName.isEmpty
                          ? member.uid
                          : member.applicantName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandMidnight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${displayIdentifier(member.role)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.45,
                ),
                child: AppStatusChip(
                  label: displayMembershipStatus(member.status),
                  tone: membershipStatusTone(member.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Info Rows
          Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Position: ${member.positionTitle ?? 'Not Assigned'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  pending
                      ? 'Requested: ${displayDate(member.requestedAt)}'
                      : 'Joined: ${displayDate(member.joinedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),

          if (actions != null) ...[
            const Divider(height: AppSpacing.xl),
            actions!,
          ],
        ],
      ),
    ),
  );
}
