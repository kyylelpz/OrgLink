import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/utils/display_labels.dart';
import '../../data/models/event_registration.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../viewmodels/event_hub_view_model.dart';
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
        title: const Text('My Events'),
        leading: const AppBackButton(),
      ),
      bottomNavigationBar: const EventNavigation(1),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeading(
              title: "What's Next for You",
              description: 'Your event registrations',
              prominent: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: DropdownButtonFormField<String>(
                initialValue: filter,
                decoration: const InputDecoration(labelText: 'Show'),
                items: [
                  for (final value in ['All', 'Upcoming', 'Past', 'Cancelled'])
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) => setState(() => filter = value!),
              ),
            ),
            QueryContent(
              query: model.mine,
              builder: (records) {
                final matching = (records ?? []).where((record) {
                  final event = model
                      .registeredEvents['${record.organizationId}/${record.eventId}']
                      ?.value;
                  return switch (filter) {
                    'Cancelled' =>
                      record.status == 'cancelled' ||
                          event?.eventStatus == 'cancelled',
                    'Upcoming' =>
                      event?.startAt?.isAfter(DateTime.now()) == true,
                    'Past' => event?.endAt?.isBefore(DateTime.now()) == true,
                    _ => true,
                  };
                }).toList();
                if (matching.isEmpty) {
                  return const AppEmptyView(
                    title: 'No Registrations Found',
                    message: 'No registrations match this view.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final record in matching)
                      Builder(
                        builder: (context) {
                          final key =
                                  '${record.organizationId}/${record.eventId}',
                              lookup = model
                                  .registeredEvents['${record.organizationId}/${record.eventId}'];
                          final event = lookup?.value;
                          if (event != null) {
                            return Column(
                              children: [
                                EventCard(
                                  event: event,
                                  organizationName:
                                      model
                                          .availableOrganizations[event
                                              .organizationId]
                                          ?.name ??
                                      'Organization',
                                  registrationStatus: record.status,
                                ),
                                _RefreshNameButton(record),
                              ],
                            );
                          }
                          return Card(
                            child: Column(
                              children: [
                                _RefreshNameButton(record),
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
                                    onPressed: model.withdrawing.contains(key)
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
                                    child: const Text('Withdraw Registration'),
                                  ),
                              ],
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
    );
  }
}

class _RefreshNameButton extends StatelessWidget {
  const _RefreshNameButton(this.record);
  final EventRegistration record;
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventHubViewModel>();
    final key = '${record.organizationId}/${record.eventId}';
    return TextButton.icon(
      icon: const Icon(Icons.person_outline),
      label: const Text('Refresh My Participant Name'),
      onPressed: model.refreshingNames.contains(key)
          ? null
          : () async {
              final success = await model.refreshName(record);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Participant name updated for this event.'
                          : model.actionFailure?.message ??
                                'Participant name could not be updated.',
                    ),
                  ),
                );
              }
            },
    );
  }
}
