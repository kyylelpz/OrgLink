import '../../../../core/widgets/image_editor.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../attendance/data/models/attendance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/constants/app_routes.dart';
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
          title: const Text('Event Details'),
          leading: const AppBackButton(),
        ),
        body: EventAccessView(
          requireEvent: true,
          builder: (context) {
            final event = model.event!.value!,
                organization = model.organization.value!;
            final canSubmit =
                model.canManageEvent &&
                event.eventStatus == 'draft' &&
                (event.submittedAt == null ||
                    event.approvalStatus == 'rejected');
            return AppPageBody(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    EventPoster(
                      event: event,
                      organizationName: organization.name,
                    ),
                    if (model.canEdit)
                      ImageEditor(
                        key: ValueKey('poster/${event.id}'),
                        resource: ImageResource(
                          'event',
                          organizationId: organization.id,
                          eventId: event.id,
                        ),
                        label: 'Poster',
                        currentURL: event.posterURL,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandMidnight,
                          ),
                    ),
                    Text(
                      'Organizer: ${organization.name}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(event.description),
                    const SizedBox(height: AppSpacing.lg),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppSectionHeading(title: 'At a Glance'),
                          const SizedBox(height: AppSpacing.md),
                          _infoRow(
                            Icons.schedule,
                            'Starts',
                            schedule(event.startAt),
                          ),
                          _infoRow(
                            Icons.schedule,
                            'Ends',
                            schedule(event.endAt),
                          ),
                          _infoRow(
                            Icons.location_on_outlined,
                            'Venue',
                            event.venue,
                          ),
                          _infoRow(
                            Icons.people_outline,
                            'Capacity',
                            '${event.capacity} (${event.availableSlots} available)',
                          ),
                          _infoRow(
                            Icons.how_to_reg_outlined,
                            'Registered',
                            '${event.registrationCount}',
                          ),
                          _infoRow(
                            Icons.timer_outlined,
                            'Deadline',
                            schedule(event.registrationDeadline),
                          ),
                          _infoRow(
                            Icons.visibility_outlined,
                            'Visibility',
                            event.visibility == 'private'
                                ? 'Members Only'
                                : 'Public',
                          ),
                          _infoRow(
                            Icons.info_outline,
                            'Status',
                            '${displayIdentifier(event.eventStatus)} / ${displayIdentifier(event.approvalStatus)}${event.archivedAt == null ? '' : ' (Archived)'}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ACTIONS
                    if (canManageAttendance(
                      model.organization.value,
                      model.membership.value,
                      model.uid,
                    ))
                      FilledButton.tonalIcon(
                        onPressed: () => context.go(
                          AppRoutes.attendance(event.organizationId, event.id),
                        ),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Attendance Verification'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    if (model.registration?.value?.status == 'registered') ...[
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go(AppRoutes.myQRCode),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('My QR Code'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),

                    // REGISTRATION
                    if (model.registration!.loading)
                      const LinearProgressIndicator()
                    else if (model.registration!.failure != null)
                      TextButton(
                        onPressed: model.registration!.retry,
                        child: const Text('Retry Registration Status'),
                      )
                    else ...[
                      Text(
                        'Your Registration: ${model.registration!.value == null ? 'Not Registered' : displayIdentifier(model.registration!.value!.status)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
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
                                  final success = await model.register(
                                    withdraw: true,
                                  );
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
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('Withdraw Registration'),
                        ),
                      if (!event.registrationOpen(DateTime.now()))
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            'Registration is closed or capacity is full.',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      if (event.visibility == 'private' &&
                          !model.privateEligible)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            'Active organization membership is required to register.',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                    ],

                    const SizedBox(height: AppSpacing.lg),

                    // MANAGER ACTIONS
                    if (model.failure != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          model.failure!.message,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (model.busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: LinearProgressIndicator(),
                      ),
                    if (model.canEdit)
                      OutlinedButton(
                        onPressed: model.busy
                            ? null
                            : () => context.go(
                                AppRoutes.editEvent(
                                  event.organizationId,
                                  event.id,
                                ),
                              ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Edit Draft'),
                      ),
                    if (canSubmit)
                      FilledButton.tonal(
                        onPressed: model.busy
                            ? null
                            : () => _act(context, 'submit'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
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
                        onPressed: model.busy
                            ? null
                            : () => _act(context, 'publish'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
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
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('Cancel Event'),
                        ),
                      if (event.eventStatus == 'published' &&
                          event.endAt?.isBefore(DateTime.now()) == true)
                        OutlinedButton(
                          onPressed: model.busy
                              ? null
                              : () => _act(context, 'complete'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('Mark Completed'),
                        ),
                      if ([
                        'completed',
                        'cancelled',
                      ].contains(event.eventStatus))
                        OutlinedButton(
                          onPressed: model.busy
                              ? null
                              : () => _act(context, 'archive'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('Archive Event'),
                        ),
                    ],
                    if (model.canViewParticipants)
                      OutlinedButton(
                        onPressed: () => context.go(
                          AppRoutes.participants(
                            event.organizationId,
                            event.id,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('View Participants'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: AppColors.brandMidnight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class RegistrationConfirmationScreen extends StatelessWidget {
  const RegistrationConfirmationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<EventContextViewModel>();
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
          title: const Text('Registration Confirmation'),
          leading: const AppBackButton(),
        ),
        body: EventAccessView(
          requireEvent: true,
          builder: (context) {
            final event = model.event!.value!;
            return AppPageBody(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    const AppSectionHeading(
                      title: 'One Last Check',
                      description: 'Review registration',
                      prominent: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSurfaceCard(
                      child: EventSummary(
                        event: event,
                        organizationName: model.organization.value!.name,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppSectionHeading(
                            title: 'Your Place at a Glance',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _infoRow(
                            Icons.schedule,
                            'Starts',
                            schedule(event.startAt),
                          ),
                          _infoRow(
                            Icons.location_on_outlined,
                            'Venue',
                            event.venue,
                          ),
                          _infoRow(
                            Icons.people_outline,
                            'Available slots',
                            '${event.availableSlots}',
                          ),
                          _infoRow(
                            Icons.timer_outlined,
                            'Deadline',
                            schedule(event.registrationDeadline),
                          ),
                          _infoRow(
                            Icons.info_outline,
                            'Requirement',
                            event.visibility == 'private'
                                ? 'Requires active organization membership.'
                                : 'Requires an active OrgLink account and completed profile.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Confirm your event and schedule before reserving a place. Attendance is recorded separately at the event.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (model.failure != null) Text(model.failure!.message),
                    if (model.busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: LinearProgressIndicator(),
                      ),
                    FilledButton(
                      onPressed: model.canRegister
                          ? () async {
                              final success = await model.register(
                                withdraw: false,
                              );
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Registration successful.'),
                                  ),
                                );
                                context.go(
                                  AppRoutes.event(
                                    event.organizationId,
                                    event.id,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: AppColors.brandMidnight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
