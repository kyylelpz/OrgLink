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

enum EventCardStyle { standard, featured, compact, managed }

String schedule(DateTime? value) {
  if (value == null) return 'Not recorded';
  final local = value.toLocal();
  final timeOfDay = TimeOfDay.fromDateTime(local);
  final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
  final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${displayDate(value)} $hour:$minute $period';
}

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
  Widget build(BuildContext context) => style == EventCardStyle.managed
      ? AppSurfaceCard(
          onTap: () =>
              context.go(AppRoutes.event(event.organizationId, event.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EventSummary(event: event, showDateBlock: false),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppStatusChip(
                    label: displayIdentifier(event.eventStatus),
                    tone: event.eventStatus == 'cancelled'
                        ? AppStatusTone.error
                        : event.eventStatus == 'published' ||
                              event.eventStatus == 'completed'
                        ? AppStatusTone.success
                        : AppStatusTone.neutral,
                  ),
                  AppStatusChip(
                    label: displayIdentifier(event.approvalStatus),
                    tone: event.approvalStatus == 'rejected'
                        ? AppStatusTone.error
                        : event.approvalStatus == 'approved'
                        ? AppStatusTone.success
                        : AppStatusTone.warning,
                  ),
                  if (event.archivedAt != null)
                    const AppStatusChip(label: 'Archived'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'View Event',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.brandBlue),
              ),
            ],
          ),
        )
      : style != EventCardStyle.standard
      ? _EventPreview(
          event: event,
          organizationName: organizationName,
          featured: style == EventCardStyle.featured,
        )
      : AppSurfaceCard(
          onTap: () =>
              context.go(AppRoutes.event(event.organizationId, event.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (registrationStatus == null) ...[
                EventPoster(event: event, organizationName: organizationName),
                const SizedBox(height: AppSpacing.md),
              ],
              EventSummary(
                event: event,
                organizationName: organizationName,
                showDateBlock: registrationStatus != null,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppStatusChip(
                    label: event.visibility == 'private'
                        ? 'Members Only'
                        : 'Public',
                    tone: AppStatusTone.info,
                  ),
                  AppStatusChip(
                    label: event.registrationOpen(DateTime.now())
                        ? 'Registration Open'
                        : 'Registration Closed',
                    tone: event.registrationOpen(DateTime.now())
                        ? AppStatusTone.success
                        : AppStatusTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${event.availableSlots} slots',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${displayIdentifier(event.eventStatus)} / ${displayIdentifier(event.approvalStatus)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (registrationStatus != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppStatusChip(
                  label:
                      'Registration: ${displayIdentifier(registrationStatus!)}',
                  tone: registrationStatus == 'registered'
                      ? AppStatusTone.success
                      : AppStatusTone.neutral,
                ),
              ],
            ],
          ),
        );
}

/// Shared dynamic poster for discovery, details, and the editor preview.
class EventPoster extends StatelessWidget {
  const EventPoster({
    super.key,
    required this.event,
    required this.organizationName,
  });
  final OrgEvent event;
  final String organizationName;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 176),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.brandBlue,
        borderRadius: AppShape.action,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: 34,
            child: Image.asset(
              'assets/illustrations/event_orbit.png',
              width: 196,
              height: 196,
              excludeFromSemantics: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  organizationName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${schedule(event.startAt)} · ${event.venue}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (event.posterURL?.trim().isNotEmpty != true) return fallback;
    return ClipRRect(
      borderRadius: AppShape.action,
      child: Image.network(
        event.posterURL!,
        height: 184,
        width: double.infinity,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Date, title and venue are shared by registration and attendance screens.
class EventSummary extends StatelessWidget {
  const EventSummary({
    super.key,
    required this.event,
    this.organizationName,
    this.showDateBlock = true,
  });
  final OrgEvent event;
  final String? organizationName;
  final bool showDateBlock;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showDateBlock) ...[
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.brandMist,
            borderRadius: AppShape.field,
          ),
          child: Column(
            children: [
              Text(
                event.startAt?.toLocal().day.toString().padLeft(2, '0') ?? '—',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.brandBlue),
              ),
              Text(
                event.startAt == null
                    ? '—'
                    : const [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec',
                      ][event.startAt!.toLocal().month - 1],
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.brandBlue),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.brandMidnight),
            ),
            if (organizationName != null)
              Text(
                organizationName!,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.brandBlue),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${schedule(event.startAt)} · ${event.venue}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
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
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: AppColors.brandMidnight),
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
    child: ColoredBox(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            AppFilterChip(
              label: 'Discover Events',
              selected: index == 0,
              onSelected: (_) => context.go(AppRoutes.events),
            ),
            AppFilterChip(
              label: 'My Events',
              selected: index == 1,
              onSelected: (_) => context.go(AppRoutes.myEvents),
            ),
          ],
        ),
      ),
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

class LiveEventCard extends StatelessWidget {
  const LiveEventCard({
    super.key,
    required this.event,
    required this.organizationName,
  });
  final OrgEvent event;
  final String organizationName;

  // Helper to format the end date and time nicely
  String _endTime(BuildContext context) {
    final end = event.endAt?.toLocal();
    if (end == null) return 'Schedule not recorded';
    return '${MaterialLocalizations.of(context).formatShortMonthDay(end)} · ${TimeOfDay.fromDateTime(end).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: AppShape.action,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.event(event.organizationId, event.id)),
        borderRadius: AppShape.action,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: AppShape.action,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Pulsing "Live" badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE NOW',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Updated to show Date + Time with AM/PM
                  Text(
                    'Ends ${_endTime(context)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                event.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.brandMidnight,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                organizationName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.venue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.brandMidnight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
