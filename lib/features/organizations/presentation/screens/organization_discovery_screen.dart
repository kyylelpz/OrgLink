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
      appBar: AppBar(title: const Text('Organizations')),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeading(
              title: 'Find Your Community',
              description:
                  'Explore organizations and keep track of your memberships.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSearchField(
              controller: _search,
              onChanged: model.searchFor,
              label: 'Search Organizations',
              hintText: 'Search organizations',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final filter in OrganizationBrowseFilter.values)
                  FilterChip(
                    label: Text(displayIdentifier(filter.name)),
                    selected: model.browseFilter == filter,
                    onSelected: (_) => model.browse(filter),
                  ),
              ],
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
                AppSurfaceCard(
                  onTap: () => context.push(AppRoutes.organization(org.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OrganizationLogo(org.logoURL),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              org.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        org.description.isEmpty
                            ? 'No description available.'
                            : org.description,
                      ),
                      Text(
                        '${displayIdentifier(org.visibility)} | ${displayIdentifier(org.status)}',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (org.managerUid == model.uid)
                        const AppStatusChip(
                          label: 'Manager',
                          tone: AppStatusTone.info,
                        )
                      else if (model.membership(org.id) != null)
                        AppStatusChip(
                          label: displayMembershipStatus(
                            model.membership(org.id)!.status,
                          ),
                          tone: model.membership(org.id)!.status == 'active'
                              ? AppStatusTone.success
                              : AppStatusTone.neutral,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () =>
                            context.push(AppRoutes.organization(org.id)),
                        child: Text(
                          model.membership(org.id) == null &&
                                  org.managerUid != model.uid &&
                                  org.status == 'active' &&
                                  org.visibility == 'public'
                              ? 'Join'
                              : 'View',
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
