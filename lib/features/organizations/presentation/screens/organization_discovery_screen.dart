import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  void initState() {
    super.initState();
    // Default to Discover when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrganizationHubViewModel>().browse(OrganizationBrowseFilter.discover);
    });
  }

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        bottomNavigationBar: OrganizationNavigation(0), // Simplified here
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // DARK HEADER
              Container(
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
                      constraints: const BoxConstraints(
                        maxWidth: AppLayout.contentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.xl,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discover Organizations',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Find Your People',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontSize: 28,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Explore organizations and keep track of your memberships.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.border,
                                    fontSize: 12,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppSearchField(
                              controller: _search,
                              onChanged: model.searchFor,
                              label: 'Search Organizations',
                              compact: true,
                              hintText: 'Search organizations',
                              leading: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Icon(
                                  Icons.search,
                                  size: 19,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // MAIN CONTENT (Filters removed)
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.contentWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        
                        // The chips are completely removed here.
                        
                        if (failure != null)
                          AppErrorView(
                            message: failure.message,
                            onRetry: model.retry,
                          )
                        else if (loading)
                          const AppLoadingView(
                            message: 'Loading organizations...',
                          )
                        else if (model.browseResults.isEmpty)
                          const AppEmptyView(
                            title: 'No Organizations Found',
                            message:
                                'Try another search or check back later for new organizations.',
                          )
                        else
                          for (final org in model.browseResults)
                            OrganizationCard(
                              organization: org,
                              onTap: () =>
                                  context.push(AppRoutes.organization(org.id)),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}