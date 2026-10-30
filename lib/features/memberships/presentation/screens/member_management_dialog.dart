import 'package:flutter/material.dart';
import '../../../../core/utils/display_labels.dart';
import '../../../../core/theme/app_tokens.dart'; // Ensure this is imported for AppColors/AppSpacing
import '../../data/models/membership.dart';
import '../viewmodels/member_list_view_model.dart';

Future<void> showMemberManagement(
  BuildContext context,
  MemberListViewModel model,
  Membership selected,
  String action,
  List<String> positions,
) async {
  final preview = await model.preview(selected);
  if (!context.mounted || preview == null) return;
  final data = Map<String, dynamic>.from(preview['membership'] as Map);
  for (final key in [
    'requestedAt',
    'joinedAt',
    'updatedAt',
    'reviewedAt',
    'endedAt',
  ]) {
    if (data[key] is num) {
      data[key] = DateTime.fromMillisecondsSinceEpoch(
        (data[key] as num).toInt(),
        isUtc: true,
      );
    }
  }
  final member = Membership.fromMap(data);
  if (action != 'details' &&
      (!model.canManage(member) ||
          (action == 'permissions' && member.role != 'officer'))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This membership changed. Review the roster before trying again.',
        ),
      ),
    );
    return;
  }
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MemberManagementDialog(
      model: model,
      member: member,
      action: action,
      version: preview['version'] as String,
      positions: positions,
    ),
  );
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Membership updated.')));
  }
}

class _MemberManagementDialog extends StatefulWidget {
  const _MemberManagementDialog({
    required this.model,
    required this.member,
    required this.action,
    required this.version,
    required this.positions,
  });
  final MemberListViewModel model;
  final Membership member;
  final String action, version;
  final List<String> positions;
  @override
  State<_MemberManagementDialog> createState() =>
      _MemberManagementDialogState();
}

class _MemberManagementDialogState extends State<_MemberManagementDialog> {
  final _form = GlobalKey<FormState>(), _reason = TextEditingController();
  final _requestId = MemberListViewModel.requestId();
  late String _role = widget.member.role == 'officer' ? 'officer' : 'member';
  late final List<String> _positions = {
    'President',
    'Vice President',
    'Secretary',
    'Treasurer',
    'Auditor',
    'Public Relations Officer',
    'Committee Head',
    ...widget.positions,
    if (widget.member.positionTitle?.isNotEmpty == true)
      widget.member.positionTitle!,
  }.toList();
  late String _position = widget.member.positionTitle?.isNotEmpty == true
      ? widget.member.positionTitle!
      : _positions.first;
  late final Map<String, bool> _permissions = {
    for (final key in ['manageEvents', 'manageAttendance', 'viewRoster'])
      key: widget.member.permissions[key] == true,
  };
  Map<String, dynamic>? _command;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.member, busy = widget.model.processing.contains(m.uid);
      final editable = !busy && _command == null;
      final title = {
        'details': 'Member Details',
        'role': 'Assign/Change Role',
        'permissions': 'Manage Permissions',
        'end': 'End Membership',
      }[widget.action]!;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(title),
          content: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER INFO
                Text(
                  m.applicantName.isEmpty ? m.uid : m.applicantName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandMidnight,
                      ),
                ),
                const SizedBox(height: 4),
                Text('Role: ${displayIdentifier(m.role)}'),
                Text('Status: ${displayMembershipStatus(m.status)}'),
                
                if (widget.action == 'details') ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('UID: ${m.uid}'),
                  Text('Position: ${m.positionTitle ?? 'Not Assigned'}'),
                  Text('Joined: ${m.joinedAt?.toLocal().toString() ?? 'Not recorded'}'),
                  Text('Updated: ${m.updatedAt?.toLocal().toString() ?? 'Not recorded'}'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final entry in _permissions.entries)
                    Text('${displayIdentifier(entry.key)}: ${entry.value ? 'Yes' : 'No'}'),
                  if (m.endedAt != null) Text('Ended: ${m.endedAt!.toLocal()}'),
                  if (m.endedBy != null) Text('Ended By: ${m.endedBy}'),
                  if (m.endReason?.isNotEmpty == true) Text('Reason: ${m.endReason}'),
                ],

                if (widget.action == 'end') ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'End this active membership and revoke its organization permissions? Membership history, event registrations and attendance records will be preserved.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _reason,
                    enabled: editable,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason (Optional)',
                    ),
                  ),
                ],

                if (widget.action == 'role') ...[
                  const SizedBox(height: AppSpacing.lg), 
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    itemHeight: null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Membership Role',
                    ),
                    items: [
                      for (final role in ['member', 'officer'])
                        DropdownMenuItem(
                          value: role,
                          child: Text(displayIdentifier(role)),
                        ),
                    ],
                    onChanged: editable ? (v) => setState(() => _role = v!) : null,
                  ),
                  
                  if (_role == 'officer') ...[
                    const SizedBox(height: AppSpacing.md), 
                    DropdownButtonFormField<String>(
                      initialValue: _position,
                      itemHeight: null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Officer Position',
                      ),
                      items: [
                        for (final p in _positions)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: editable ? (v) => setState(() => _position = v!) : null,
                    ),
                  ],
                  
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Promotion starts without officer capabilities. Demotion clears all organization permissions. Manager assignment and platform roles are unchanged.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],

                if (widget.action == 'permissions') ...[
                  const SizedBox(height: AppSpacing.md),
                  for (final entry in const {
                    'manageEvents': 'Manage Events',
                    'manageAttendance': 'Manage Attendance',
                    'viewRoster': 'View Roster',
                  }.entries)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      value: _permissions[entry.key],
                      onChanged: editable
                          ? (v) => setState(() => _permissions[entry.key] = v!)
                          : null,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Event management applies to the officer’s own events. These capabilities do not grant manager or platform administrator privileges.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],

                if (busy) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(),
                ],
                if (widget.model.failure != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.model.failure!.message,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(widget.action == 'details' ? 'Close' : 'Cancel'),
            ),
            if (widget.action != 'details' && widget.model.canManage(m))
              FilledButton(
                style: widget.action == 'end'
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onPressed: busy
                    ? null
                    : () async {
                        if (!_form.currentState!.validate()) return;
                        setState(
                          () => _command ??= {
                            'operation': widget.action,
                            'version': widget.version,
                            'requestId': _requestId,
                            if (widget.action == 'end') 'reason': _reason.text,
                            if (widget.action == 'role') ...{
                              'role': _role,
                              'positionTitle': _role == 'officer'
                                  ? _position
                                  : null,
                            },
                            if (widget.action == 'permissions')
                              'permissions': Map<String, bool>.from(
                                _permissions,
                              ),
                          },
                        );
                        final success = await widget.model.manage(m, _command!);
                        if (context.mounted && success) {
                          Navigator.pop(context, true);
                        }
                      },
                child: Text(
                  _command != null
                      ? 'Retry Change'
                      : widget.action == 'end'
                      ? 'End Membership'
                      : 'Save Changes',
                ),
              ),
          ],
        ),
      );
    },
  );
}