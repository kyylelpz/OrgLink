import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../attendance/data/models/attendance.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/live_query.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../../data/models/event.dart';
import '../viewmodels/participants_view_model.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../viewmodels/event_context_view_model.dart';
import '../widgets/event_access_view.dart';
import '../widgets/event_widgets.dart';
import '../widgets/event_sort.dart';

class EventManagementScreen extends StatelessWidget {
  const EventManagementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
        title: const Text('Organization Event Management'),
        leading: const AppBackButton(),
      ),
      bottomNavigationBar: model.canCreate
          ? SafeArea(
              top: false,
              child: ColoredBox(
                color: AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: AppActionButton(
                    label: 'Create Event',
                    icon: Icons.add,
                    onPressed: () =>
                        context.go(AppRoutes.createEvent(model.organizationId)),
                  ),
                ),
              ),
            )
          : null,
      body: EventAccessView(
        builder: (context) {
          if (!model.canCreate) {
            return const Center(
              child: Text('You do not have permission to manage events.'),
            );
          }
          return ChangeNotifierProvider(
            key: ValueKey('${model.organizationId}/${model.isManager}'),
            create: (_) => LiveQuery(
              () => model.repository.organizationEvents(
                model.organizationId,
                management: true,
                includePrivate: true,
                createdBy: model.isManager ? null : model.uid,
              ),
            ),
            child: const _ManagementList(),
          );
        },
      ),
    );
  }
}

class _ManagementList extends StatefulWidget {
  const _ManagementList();
  @override
  State<_ManagementList> createState() => _ManagementListState();
}

class _ManagementListState extends State<_ManagementList> {
  String filter = 'All', search = '';
  @override
  Widget build(BuildContext context) {
    final query = context.watch<LiveQuery<List<OrgEvent>>>(),
        model = context.watch<EventContextViewModel>();
    return AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionHeading(
                  title: 'Manage Events',
                  description: model.organization.value!.name,
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  onChanged: (value) => setState(() => search = value),
                  decoration: const InputDecoration(
                    labelText: 'Search Organization Events',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status in [
                      'All',
                      'draft',
                      'published',
                      'cancelled',
                      'completed',
                      'Archived',
                    ])
                      DropdownMenuItem(
                        value: status,
                        child: Text(displayIdentifier(status)),
                      ),
                  ],
                  onChanged: (value) => setState(() => filter = value!),
                ),
              ],
            ),
          ),
          QueryContent(
            query: query,
            builder: (values) {
              final events = (values ?? [])
                  .where(
                    (event) =>
                        event.title.toLowerCase().contains(
                          search.toLowerCase(),
                        ) &&
                        (filter == 'Archived'
                            ? event.archivedAt != null
                            : event.archivedAt == null &&
                                  (filter == 'All' ||
                                      event.eventStatus == filter)),
                  )
                  .toList();

              final sortedEvents = sortByChronology(events);

              if (sortedEvents.isEmpty) {
                return const AppEmptyView(
                  title: 'No Events Found',
                  message: 'No events match this view.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final event in sortedEvents)
                    EventCard(
                      event: event,
                      style: EventCardStyle.managed,
                      organizationName: model.organization.value!.name,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
        title: const Text('Event Participants'),
        actions: [
          if (model.organization.failure == null &&
              model.membership.failure == null &&
              canManageAttendance(
                model.organization.value,
                model.membership.value,
                model.uid,
              ))
            IconButton(
              tooltip: 'Attendance Verification',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => context.go(
                AppRoutes.attendance(model.organizationId, model.eventId!),
              ),
            ),
        ],
        leading: const AppBackButton(),
      ),
      body: EventAccessView(
        requireEvent: true,
        builder: (context) {
          if (!model.canViewParticipants) {
            return const Center(
              child: Text('You do not have permission to view participants.'),
            );
          }
          return ChangeNotifierProvider(
            create: (_) => ParticipantsViewModel(
              model.repository,
              model.organizationId,
              model.eventId!,
            ),
            child: const _ParticipantList(),
          );
        },
      ),
    );
  }
}

class _ParticipantList extends StatelessWidget {
  const _ParticipantList();
  String _timestamp(BuildContext context, DateTime? value) {
    if (value == null) return 'Not recorded';
    final local = value.toLocal(), format = MaterialLocalizations.of(context);
    return '${format.formatFullDate(local)}, ${format.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
  }

  @override
  Widget build(BuildContext context) {
    final participants = context.watch<ParticipantsViewModel>(),
        model = context.watch<EventContextViewModel>();
    return AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeading(
            title: "Who's Joining?",
            description: 'Private participant roster',
            prominent: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSurfaceCard(
            child: EventSummary(
              event: model.event!.value!,
              organizationName: model.organization.value!.name,
            ),
          ),
          AppMetricTiles(
            values: [
              ('${model.event!.value!.registrationCount}', 'Reserved'),
              ('${model.event!.value!.capacity}', 'Capacity'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          QueryContent(
            query: participants.registrations,
            builder: (records) {
              if ((records ?? []).isEmpty) {
                return const AppEmptyView(
                  title: 'No Participants Yet',
                  message: 'No registrations yet.',
                );
              }
              if (participants.identities.loading) {
                return const AppLoadingView(
                  message: 'Loading participant names...',
                );
              }
              return QueryContent(
                query: participants.identities,
                builder: (_) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final record in records!)
                      AppSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              participants.nameFor(record.uid),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${displayIdentifier(record.status)} \u00b7 ${_timestamp(context, record.registeredAt)}\nUpdated: ${_timestamp(context, record.updatedAt)}',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
