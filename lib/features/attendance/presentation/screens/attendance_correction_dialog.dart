import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_components.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../events/data/models/event_registration.dart';
import '../../data/models/attendance.dart';
import '../viewmodels/attendance_view_model.dart';

class AttendanceCorrectionDialog extends StatefulWidget {
  const AttendanceCorrectionDialog({
    super.key,
    required this.model,
    required this.registration,
    required this.preview,
  });
  final AttendanceViewModel model;
  final EventRegistration registration;
  final AttendanceCorrectionPreview preview;
  @override
  State<AttendanceCorrectionDialog> createState() =>
      _AttendanceCorrectionDialogState();
}

class _AttendanceCorrectionDialogState
    extends State<AttendanceCorrectionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late AttendanceCorrectionStatus _status =
      widget.preview.previousStatus == AttendanceStatus.present
      ? AttendanceCorrectionStatus.absent
      : AttendanceCorrectionStatus.present;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) => PopScope(
      canPop: !widget.model.busy,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: AppColors.brandMidnight),
        title: const Text('Confirm Attendance Correction'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.model.context.organization.value?.name ??
                      'Organization Unavailable',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.brandBlue),
                ),
                Text(
                  widget.model.context.event?.value?.title ??
                      'Event Unavailable',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.model.nameFor(widget.registration.uid),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          const Text(
                            'Current Status:',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          AppStatusChip(
                            label: displayIdentifier(
                              widget.preview.previousStatus.name,
                            ),
                            tone:
                                widget.preview.previousStatus ==
                                    AttendanceStatus.present
                                ? AppStatusTone.success
                                : AppStatusTone.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<AttendanceCorrectionStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Correct Status To',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(borderRadius: AppShape.action),
                  ),
                  items: [
                    for (final status in AttendanceCorrectionStatus.values)
                      if (status.name != widget.preview.previousStatus.name)
                        DropdownMenuItem(
                          value: status,
                          child: Text(displayIdentifier(status.name)),
                        ),
                  ],
                  onChanged: widget.model.busy
                      ? null
                      : (value) => setState(() => _status = value!),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _reason,
                  enabled: !widget.model.busy,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Correction',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a correction reason.'
                      : null,
                ),
                if (widget.model.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: LinearProgressIndicator(),
                  ),
                if (widget.model.failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      widget.model.failure!.message,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This replaces the active result and permanently records your reason. Pending removes the active result; old QR passes will not work.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.model.busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: widget.model.busy
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    final success = await widget.model.correct(
                      widget.registration,
                      widget.preview,
                      _status,
                      _reason.text,
                    );
                    if (context.mounted && success) Navigator.pop(context);
                  },
            child: const Text('Confirm Correction'),
          ),
        ],
      ),
    ),
  );
}
