/// Authentication identity only; profile, account status and roles are separate.
class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoURL,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoURL;
}
