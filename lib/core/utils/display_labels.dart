/// Presentation labels only. Never use these values for persistence or queries.
const _identifierLabels = <String, String>{
  'active': 'Active',
  'present': 'Present',
  'absent': 'Absent',
  'notMarked': 'Not Marked',
  'qr': 'QR',
  'manual': 'Manual',
  'pending': 'Pending',
  'registered': 'Registered',
  'published': 'Published',
  'cancelled': 'Cancelled',
  'manager': 'Manager',
  'officer': 'Officer',
  'member': 'Member',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'removed': 'Removed',
  'draft': 'Draft',
  'completed': 'Completed',
  'archived': 'Archived',
  'suspended': 'Suspended',
  'disabled': 'Disabled',
  'public': 'Public',
  'private': 'Private',
  'user': 'User',
  'unknown': 'Unknown',
  'platformAdmin': 'Platform Admin',
  'organizationManager': 'Organization Manager',
  'organization manager': 'Organization Manager',
  'organization_manager': 'Organization Manager',
};

String displayIdentifier(String value) {
  final known =
      _identifierLabels[value] ?? _identifierLabels[value.toLowerCase()];
  if (known != null) return known;
  final words = value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .split(RegExp(r'[ _-]+'))
      .where((word) => word.isNotEmpty);
  final label = words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
  return label.isEmpty ? 'Unknown' : label;
}

/// Preserve the membership screen's existing approval context.
String displayMembershipStatus(String status) =>
    status == 'active' ? 'Approved (Active)' : displayIdentifier(status);

/// An optional preview for all-lowercase names/titles, never a save transform.
/// Mixed/uppercase input is deliberately left alone; the user reviews acronyms.
String? capitalizationSuggestion(String value) {
  if (value.trim().isEmpty ||
      value != value.toLowerCase() ||
      value == value.toUpperCase()) {
    return null;
  }
  final suggestion = value.replaceAllMapped(
    RegExp(r"(^|[\s'\u2019-])(\p{L})", unicode: true),
    (match) => '${match[1]}${match[2]!.toUpperCase()}',
  );
  return suggestion == value ? null : suggestion;
}
