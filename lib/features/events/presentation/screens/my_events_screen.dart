import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/utils/display_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../../data/models/event.dart';
import '../viewmodels/event_hub_view_model.dart';
import '../widgets/event_sort.dart';
import '../widgets/event_widgets.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});
  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventHubViewModel>();

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
          title: const Text('My Events'),
          leading: const AppBackButton(),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandMidnight.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppFilterChip(
                      label: 'Discover Events',
                      selected: false,
                      onSelected: (_) => context.go(AppRoutes.events),
                    ),
                  ),
                  Expanded(
                    child: AppFilterChip(
                      label: 'My Events',
                      selected: true,
                      onSelected: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: AppPageBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const AppSectionHeading(
                  title: "What's Next for You",
                  description: 'Your event registrations',
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: InputDecoration(
                    labelText: 'Show',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: AppShape.action,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    for (final value in [
                      'All',
                      'Ongoing',
                      'Upcoming',
                      'Past',
                      'Cancelled',
                    ])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() => filter = value!),
                ),
                const SizedBox(height: AppSpacing.lg),
                QueryContent(
                  query: model.mine,
                  builder: (records) {
                    final now = DateTime.now();

                    final matching = (records ?? []).where((record) {
                      final event = model
                          .registeredEvents[
                              '${record.organizationId}/${record.eventId}']
                          ?.value;
                      return switch (filter) {
                        'Ongoing' =>
                          event?.startAt != null &&
                              !event!.startAt!.isAfter(now) &&
                              (event.endAt?.isAfter(now) ?? false),
                        'Cancelled' =>
                          record.status == 'cancelled' ||
                              event?.eventStatus == 'cancelled',
                        'Upcoming' =>
                          event?.startAt?.isAfter(now) == true,
                        'Past' =>
                          event?.endAt?.isBefore(now) == true,
                        _ => true,
                      };
                    }).toList();

                    // Sort using the shared canonical chronology:
                    //   ongoing → nearest future → later future
                    //   → recent past → old past → undated
                    // The helper resolves each record to its OrgEvent for the
                    // rank/direction decisions, so we wrap each record in a
                    // small adapter and unwrap after sorting.
                    final sortedEvents = sortByChronology(
                      matching
                          .map((r) => model
                              .registeredEvents[
                                  '${r.organizationId}/${r.eventId}']
                              ?.value)
                          .whereType<OrgEvent>(),
                      now: now,
                    );
                    // Map back to the original records in the sorted order.
                    final eventKey = (OrgEvent e) =>
                        '${e.organizationId}/${e.id}';
                    final orderedRecords = [
                      for (final e in sortedEvents)
                        ...matching.where(
                          (r) =>
                              '${r.organizationId}/${r.eventId}' ==
                              eventKey(e),
                        ),
                    ];
                    // Records whose event hasn't loaded yet (no OrgEvent)
                    // can't be ranked — keep them at the end, preserving
                    // their original order.
                    final unranked = matching
                        .where((r) =>
                            model.registeredEvents[
                                '${r.organizationId}/${r.eventId}']
                                ?.value ==
                            null)
                        .toList();
                    final sortedMatching = [...orderedRecords, ...unranked];

                    if (sortedMatching.isEmpty) {
                      return const AppEmptyView(
                        title: 'No Registrations Found',
                        message: 'No registrations match this view.',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final record in sortedMatching)
                          Builder(
                            builder: (context) {
                              final key =
                                      '${record.organizationId}/${record.eventId}',
                                  lookup = model.registeredEvents[key];
                              final event = lookup?.value;
                              if (event != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: EventCard(
                                    event: event,
                                    organizationName:
                                        model
                                            .availableOrganizations[event
                                                .organizationId]
                                            ?.name ??
                                        'Organization',
                                    registrationStatus: record.status,
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: Card(
                                  child: Column(
                                    children: [
                                      ListTile(
                                        title: Text(
                                          lookup?.loading == true
                                              ? 'Loading event...'
                                              : 'Event unavailable',
                                        ),
                                        subtitle: Text(
                                          'Registration: ${displayIdentifier(record.status)}\nRegistered: ${schedule(record.registeredAt)}',
                                        ),
                                        trailing: lookup?.failure == null
                                            ? null
                                            : IconButton(
                                                onPressed: lookup!.retry,
                                                tooltip: 'Retry Event Details',
                                                icon: const Icon(Icons.refresh),
                                              ),
                                        onTap: () => context.go(
                                          AppRoutes.event(
                                            record.organizationId,
                                            record.eventId,
                                          ),
                                        ),
                                      ),
                                      if (record.status == 'registered' &&
                                          lookup?.loading == false)
                                        TextButton(
                                          onPressed:
                                              model.withdrawing.contains(key)
                                              ? null
                                              : () async {
                                                  if (!await confirmEventAction(
                                                        context,
                                                        'Withdraw Registration?',
                                                        'Withdrawal is subject to the event cutoff. Your private event access will not be changed.',
                                                      ) ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  final success = await model
                                                      .withdraw(record);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          success
                                                              ? 'Registration withdrawn.'
                                                              : model
                                                                        .actionFailure
                                                                        ?.message ??
                                                                    'Withdrawal failed.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                          child: const Text(
                                            'Withdraw Registration',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}