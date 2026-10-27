import '../../../../core/utils/display_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart'
    show displayDate;
import '../../../../core/widgets/app_components.dart';
import '../../data/models/event.dart';

String schedule(DateTime? value) => value == null
    ? 'Not recorded'
    : '${displayDate(value)} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.organizationName,
    this.registrationStatus,
  });
  final OrgEvent event;
  final String organizationName;
  final String? registrationStatus;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go(AppRoutes.event(event.organizationId, event.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.posterURL != null && event.posterURL!.isNotEmpty)
            Image.network(
              event.posterURL!,
              height: 148,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizationName,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.brandBlue),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                _EventDetail(
                  icon: Icons.calendar_today_outlined,
                  text: schedule(event.startAt),
                ),
                const SizedBox(height: AppSpacing.sm),
                _EventDetail(
                  icon: Icons.location_on_outlined,
                  text: event.venue,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppStatusChip(
                      label: event.registrationOpen(DateTime.now())
                          ? 'Registration Open'
                          : 'Registration Closed',
                      tone: event.registrationOpen(DateTime.now())
                          ? AppStatusTone.success
                          : AppStatusTone.neutral,
                    ),
                    Text(
                      '${event.availableSlots} slots',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${displayIdentifier(event.eventStatus)} / ${displayIdentifier(event.approvalStatus)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (registrationStatus != null)
                  Text(
                    'Registration: ${displayIdentifier(registrationStatus!)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.brandNavy),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}

Future<bool> confirmEventAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class EventNavigation extends StatelessWidget {
  const EventNavigation(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.go(AppRoutes.events),
          child: const Text('Discover Events'),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.myEvents),
          child: const Text('My Events'),
        ),
      ],
    ),
  );
}
