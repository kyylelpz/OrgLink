import '../../../../core/errors/app_failure.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_user.dart';
import '../services/firebase_auth_service.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._service);

  final FirebaseAuthService _service;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    try {
      await for (final user in _service.authStateChanges()) {
        yield user == null
            ? null
            : AuthUser(
                id: user.uid,
                email: user.email,
                displayName: user.displayName,
                photoURL: user.photoURL,
                emailVerified: user.emailVerified,
                providers: user.providerData.map((p) => p.providerId).toList(),
              );
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      return await _service.signInWithGoogle();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _emailAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _emailAction(() => _service.signInWithEmail(email, password));
  @override
  Future<void> registerWithEmail(String email, String password) =>
      _emailAction(() => _service.registerWithEmail(email, password));
  @override
  Future<void> sendVerification() => _emailAction(_service.sendVerification);
  @override
  Future<void> resetPassword(String email) =>
      _emailAction(() => _service.resetPassword(email));
  @override
  Future<void> linkPassword(String password) =>
      _emailAction(() => _service.linkPassword(password));
  @override
  Future<AuthUser?> reloadUser() async {
    try {
      final User? user = await _service.reloadUser();
      return user == null
          ? null
          : AuthUser(
              id: user.uid,
              email: user.email,
              displayName: user.displayName,
              photoURL: user.photoURL,
              emailVerified: user.emailVerified,
              providers: user.providerData.map((p) => p.providerId).toList(),
            );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> verifyResetCode(String code) =>
      _emailAction(() => _service.verifyResetCode(code));
  @override
  Future<void> confirmPasswordReset(String code, String password) =>
      _emailAction(() => _service.confirmPasswordReset(code, password));
  @override
  Future<void> applyEmailVerification(String code) =>
      _emailAction(() => _service.applyEmailVerification(code));

  @override
  Future<void> signOut() async {
    try {
      await _service.signOut();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}
