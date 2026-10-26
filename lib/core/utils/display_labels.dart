/// Formats stored role/status identifiers for display, never user-entered names.
String displayIdentifier(String value) {
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
