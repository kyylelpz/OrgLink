import '../../../attendance/data/models/attendance.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart';
import '../viewmodels/event_context_view_model.dart';
import '../widgets/event_widgets.dart';
import '../widgets/event_access_view.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key});
  Future<void> _act(BuildContext context, String action) async {
    final model = context.read<EventContextViewModel>();
    if (!await confirmEventAction(
          context,
          'Confirm ${displayIdentifier(action)}',
          'Apply "$action" to this event?',
        ) ||
        !context.mounted) {
      return;
    }
    final success = await model.act(action);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Event updated.'
                : model.failure?.message ?? 'Event action failed.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.events),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: EventAccessView(
        requireEvent: true,
        builder: (context) {
          final event = model.event!.value!,
              organization = model.organization.value!;
          final canSubmit =
              model.canManageEvent &&
              event.eventStatus == 'draft' &&
              (event.submittedAt == null || event.approvalStatus == 'rejected');
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              OrganizationLogo(event.posterURL ?? organization.logoURL),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Organizer: ${organization.name}'),
              const SizedBox(height: 12),
              Text(event.description),
              const SizedBox(height: 12),
              Text('Starts: ${schedule(event.startAt)}'),
              Text('Ends: ${schedule(event.endAt)}'),
              Text('Venue: ${event.venue}'),
              Text(
                'Capacity: ${event.capacity} | Registered: ${event.registrationCount} | Available: ${event.availableSlots}',
              ),
              Text(
                'Registration Deadline: ${schedule(event.registrationDeadline)}',
              ),
              Text(
                'Visibility: ${event.visibility == 'private' ? 'Members Only' : 'Public'}',
              ),
              Text(
                'Status: ${displayIdentifier(event.eventStatus)} / ${displayIdentifier(event.approvalStatus)}${event.archivedAt == null ? '' : ' (Archived)'}',
              ),
              if (canManageAttendance(
                model.organization.value,
                model.membership.value,
                model.uid,
              ))
                TextButton(
                  onPressed: () => context.go(
                    AppRoutes.attendance(event.organizationId, event.id),
                  ),
                  child: const Text('Attendance Verification'),
                ),
              if (model.registration?.value?.status == 'registered')
                TextButton(
                  onPressed: () => context.go(AppRoutes.myQRCode),
                  child: const Text('My QR Code'),
                ),
              const Divider(),
              if (model.registration!.loading)
                const LinearProgressIndicator()
              else if (model.registration!.failure != null)
                TextButton(
                  onPressed: model.registration!.retry,
                  child: const Text('Retry Registration Status'),
                )
              else
                Text(
                  'Your Registration: ${model.registration!.value == null ? 'Not Registered' : displayIdentifier(model.registration!.value!.status)}',
                ),
              if (model.canRegister)
                FilledButton(
                  onPressed: model.busy
                      ? null
                      : () => context.go(
                          AppRoutes.confirmRegistration(
                            event.organizationId,
                            event.id,
                          ),
                        ),
                  child: const Text('Register'),
                ),
              if (model.canWithdraw)
                OutlinedButton(
                  onPressed: model.busy
                      ? null
                      : () async {
                          if (!await confirmEventAction(
                                context,
                                'Withdraw Registration?',
                                'Your registration record will be retained and your slot released.',
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          final success = await model.register(withdraw: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Registration withdrawn.'
                                      : model.failure?.message ??
                                            'Withdrawal failed.',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Withdraw Registration'),
                ),
              if (!event.registrationOpen(DateTime.now()))
                const Text('Registration is closed or capacity is full.'),
              if (event.visibility == 'private' && !model.privateEligible)
                const Text(
                  'Active organization membership is required to register.',
                ),
              if (model.failure != null) Text(model.failure!.message),
              if (model.busy) const LinearProgressIndicator(),
              if (model.canEdit)
                OutlinedButton(
                  onPressed: model.busy
                      ? null
                      : () => context.go(
                          AppRoutes.editEvent(event.organizationId, event.id),
                        ),
                  child: const Text('Edit Draft'),
                ),
              if (canSubmit)
                FilledButton.tonal(
                  onPressed: model.busy ? null : () => _act(context, 'submit'),
                  child: const Text('Submit for Approval'),
                ),
              if (model.canReview)
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: model.busy
                          ? null
                          : () => _act(context, 'approve'),
                      child: const Text('Approve Event'),
                    ),
                    OutlinedButton(
                      onPressed: model.busy
                          ? null
                          : () => _act(context, 'reject'),
                      child: const Text('Reject Event'),
                    ),
                  ],
                ),
              if (model.canPublish)
                FilledButton(
                  onPressed: model.busy ? null : () => _act(context, 'publish'),
                  child: const Text('Publish Event'),
                ),
              if (model.isManager &&
                  organization.status == 'active' &&
                  event.archivedAt == null) ...[
                if (['draft', 'published'].contains(event.eventStatus))
                  OutlinedButton(
                    onPressed: model.busy
                        ? null
                        : () => _act(context, 'cancel'),
                    child: const Text('Cancel Event'),
                  ),
                if (event.eventStatus == 'published' &&
                    event.endAt?.isBefore(DateTime.now()) == true)
                  OutlinedButton(
                    onPressed: model.busy
                        ? null
                        : () => _act(context, 'complete'),
                    child: const Text('Mark Completed'),
                  ),
                if (['completed', 'cancelled'].contains(event.eventStatus))
                  OutlinedButton(
                    onPressed: model.busy
                        ? null
                        : () => _act(context, 'archive'),
                    child: const Text('Archive Event'),
                  ),
              ],
              if (model.canViewParticipants)
                OutlinedButton(
                  onPressed: () => context.go(
                    AppRoutes.participants(event.organizationId, event.id),
                  ),
                  child: const Text('View Participants'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RegistrationConfirmationScreen extends StatelessWidget {
  const RegistrationConfirmationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Confirmation'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go(AppRoutes.event(model.organizationId, model.eventId!)),
        ),
      ),
      body: EventAccessView(
        requireEvent: true,
        builder: (context) {
          final event = model.event!.value!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(model.organization.value!.name),
              Text(schedule(event.startAt)),
              Text('Venue: ${event.venue}'),
              Text('Available slots: ${event.availableSlots}'),
              Text('Deadline: ${schedule(event.registrationDeadline)}'),
              Text(
                event.visibility == 'private'
                    ? 'Requires active organization membership.'
                    : 'Requires an active OrgLink account and completed profile.',
              ),
              if (model.failure != null) Text(model.failure!.message),
              if (model.busy) const LinearProgressIndicator(),
              FilledButton(
                onPressed: model.canRegister
                    ? () async {
                        final success = await model.register(withdraw: false);
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Registration successful.'),
                            ),
                          );
                          context.go(
                            AppRoutes.event(event.organizationId, event.id),
                          );
                        }
                      }
                    : null,
                child: const Text('Confirm Registration'),
              ),
              TextButton(
                onPressed: model.busy
                    ? null
                    : () => context.go(
                        AppRoutes.event(event.organizationId, event.id),
                      ),
                child: const Text('Back to Event'),
              ),
            ],
          );
        },
      ),
    );
  }
}
