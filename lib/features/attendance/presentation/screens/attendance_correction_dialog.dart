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
        title: const Text('Confirm Attendance Correction'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.model.nameFor(widget.registration.uid)),
                Text(
                  'Current status: ${displayIdentifier(widget.preview.previousStatus.name)}',
                ),
                const Text(
                  'This replaces the active result and permanently records your reason and identity in the correction history. Pending removes the active result; old QR passes will not work.',
                ),
                DropdownButtonFormField<AttendanceCorrectionStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'New Status'),
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
                TextFormField(
                  controller: _reason,
                  enabled: !widget.model.busy,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Correction Reason',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a correction reason.'
                      : null,
                ),
                if (widget.model.busy) const LinearProgressIndicator(),
                if (widget.model.failure != null)
                  Text(widget.model.failure!.message),
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
