import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../viewmodels/organization_hub_view_model.dart';
import '../widgets/organization_widgets.dart';

class OrganizationDiscoveryScreen extends StatefulWidget {
  const OrganizationDiscoveryScreen({super.key});
  @override
  State<OrganizationDiscoveryScreen> createState() =>
      _OrganizationDiscoveryScreenState();
}

class _OrganizationDiscoveryScreenState
    extends State<OrganizationDiscoveryScreen> {
  final _search = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_search.text.isEmpty) {
      _search.text = context.read<OrganizationHubViewModel>().search;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<OrganizationHubViewModel>();
    final errors = [
      model.discovery.failure,
      model.mine.failure,
      model.managed.failure,
      ...model.associated.values.map((q) => q.failure),
    ];
    final failure = errors.where((e) => e != null).firstOrNull;
    final loading =
        model.discovery.loading ||
        model.mine.loading ||
        model.managed.loading ||
        model.associated.values.any((q) => q.loading);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
        title: const Text('Organizations'),
      ),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OrganizationPageHeading(
              title: 'Find Your People',
              description:
                  'Explore organizations and keep track of your memberships.',
            ),
            AppSearchField(
              controller: _search,
              onChanged: model.searchFor,
              label: 'Search Organizations',
              compact: true,
              hintText: 'Search organizations',
            ),
            const SizedBox(height: AppSpacing.md),
            Theme(
              data: Theme.of(context).copyWith(
                chipTheme: Theme.of(context).chipTheme.copyWith(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 14,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final filter in OrganizationBrowseFilter.values) ...[
                    if (filter != OrganizationBrowseFilter.values.first)
                      const SizedBox(width: 6),
                    Expanded(
                      child: AppFilterChip(
                        expanded: true,
                        label: displayIdentifier(filter.name),
                        selected: model.browseFilter == filter,
                        onSelected: (_) => model.browse(filter),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => context.push(AppRoutes.myOrganizations),
                  child: const Text('My Organizations'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.membershipRequests),
                  child: const Text('Membership Requests'),
                ),
              ],
            ),
            if (failure != null)
              AppErrorView(message: failure.message, onRetry: model.retry)
            else if (loading)
              const AppLoadingView(message: 'Loading organizations...')
            else if (model.browseResults.isEmpty)
              const AppEmptyView(
                title: 'No Organizations Found',
                message:
                    'Try another search or filter. Membership requests remain available above.',
              )
            else
              for (final org in model.browseResults)
                OrganizationCard(
                  organization: org,
                  onTap: () => context.push(AppRoutes.organization(org.id)),
                  status: org.managerUid == model.uid
                      ? const AppStatusChip(
                          label: 'Manager',
                          tone: AppStatusTone.info,
                        )
                      : model.membership(org.id) == null
                      ? null
                      : AppStatusChip(
                          label: displayMembershipStatus(
                            model.membership(org.id)!.status,
                          ),
                          tone: membershipStatusTone(
                            model.membership(org.id)!.status,
                          ),
                        ),
                  actionLabel:
                      model.membership(org.id) == null &&
                          org.managerUid != model.uid &&
                          org.status == 'active' &&
                          org.visibility == 'public'
                      ? 'Join'
                      : 'View',
                ),
          ],
        ),
      ),
    );
  }
}
