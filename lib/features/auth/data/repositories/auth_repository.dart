import '../models/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  Future<bool> signInWithGoogle();
  Future<void> signOut();
}
