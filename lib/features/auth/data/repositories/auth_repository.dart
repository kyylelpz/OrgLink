import '../models/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  Future<bool> signInWithGoogle();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> sendVerification();
  Future<AuthUser?> reloadUser();
  Future<void> resetPassword(String email);
  Future<void> linkPassword(String password);
  Future<void> verifyResetCode(String code);
  Future<void> confirmPasswordReset(String code, String password);
  Future<void> applyEmailVerification(String code);
  Future<void> signOut();
}
