/// Authentication identity only; profile, account status and roles are separate.
class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoURL,
    this.emailVerified = true,
    this.providers = const [],
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool emailVerified;
  final List<String> providers;
  bool get requiresEmailVerification =>
      providers.contains('password') && !emailVerified;
}

abstract final class AuthInput {
  static String? email(String? value) =>
      value == null ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? 'Enter a valid email address.'
      : null;
  static String? newPassword(String? value) =>
      value == null ||
          value.length < 8 ||
          !RegExp(r'[^a-zA-Z\s]').hasMatch(value)
      ? 'Use at least 8 characters, including a number or special character.'
      : null;
}
