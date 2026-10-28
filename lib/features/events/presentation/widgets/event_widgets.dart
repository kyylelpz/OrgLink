import '../../../../core/utils/display_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../organizations/presentation/widgets/organization_widgets.dart'
    show displayDate;
import '../../../../core/widgets/app_components.dart';
import '../../data/models/event.dart';
import '../../../../core/widgets/app_asset_icon.dart';

enum EventCardStyle { standard, featured, compact }

String schedule(DateTime? value) => value == null
    ? 'Not recorded'
    : '${displayDate(value)} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.organizationName,
    this.registrationStatus,
    this.style = EventCardStyle.standard,
  });
  final OrgEvent event;
  final String organizationName;
  final String? registrationStatus;
  final EventCardStyle style;
  @override
  Widget build(BuildContext context) => style != EventCardStyle.standard
      ? _EventPreview(
          event: event,
          organizationName: organizationName,
          featured: style == EventCardStyle.featured,
        )
      : Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                context.go(AppRoutes.event(event.organizationId, event.id)),
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
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.brandBlue,
                        ),
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

/// Home variants reuse the event model and detail route; no new catalog selection.
class _EventPreview extends StatelessWidget {
  const _EventPreview({
    required this.event,
    required this.organizationName,
    required this.featured,
  });
  final OrgEvent event;
  final String organizationName;
  final bool featured;

  String _when(BuildContext context) {
    final start = event.startAt?.toLocal();
    return start == null
        ? 'Schedule not recorded'
        : '${MaterialLocalizations.of(context).formatShortMonthDay(start)} · ${TimeOfDay.fromDateTime(start).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      constraints: const BoxConstraints(minHeight: 174),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.buttonHorizontal),
      decoration: const BoxDecoration(
        color: AppColors.brandBlue,
        borderRadius: AppShape.action,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Event',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            organizationName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '${_when(context)} · ${event.venue}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: AppShape.action,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.event(event.organizationId, event.id)),
        borderRadius: AppShape.action,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: featured
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (event.posterURL?.trim().isNotEmpty == true)
                      ClipRRect(
                        borderRadius: AppShape.action,
                        child: Image.network(
                          event.posterURL!,
                          height: 174,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : fallback,
                          errorBuilder: (_, error, stack) => fallback,
                        ),
                      )
                    else
                      fallback,
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.brandMidnight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$organizationName · ${_when(context)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 40,
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.successSurface,
                        borderRadius: AppShape.button,
                      ),
                      child: Text(
                        event.startAt?.toLocal().day.toString().padLeft(
                              2,
                              '0',
                            ) ??
                            '—',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_when(context)} · ${event.venue}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const AppAssetIcon('arrow', size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}
