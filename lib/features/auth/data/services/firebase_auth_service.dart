import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._auth, this._google);
  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _initialization;

  // Android reads the web OAuth client from the Gradle-generated
  // default_web_client_id resource supplied by google-services.json.
  Future<void> _initializeGoogle() => _initialization ??= _google.initialize();
  Stream<User?> authStateChanges() => _auth.userChanges();

  void _logFailure(String stage, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    final description = switch (error) {
      GoogleSignInException() =>
        'GoogleSignInException code=${error.code.name}, description=${error.description}',
      FirebaseAuthException() =>
        'FirebaseAuthException code=${error.code}, message=${error.message}',
      _ => error.runtimeType.toString(),
    };
    // Do not dump exception details, credentials, tokens or account information.
    debugPrint('[OrgLink auth] $stage: $description');
    debugPrintStack(stackTrace: stackTrace);
  }

  Future<bool> signInWithGoogle() async {
    var stage = 'Google initialization';
    try {
      await _initializeGoogle();
      stage = 'Google authentication';
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Google did not return an ID token.',
        );
      }
      stage = 'Firebase credential exchange';
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return true;
    } catch (error, stackTrace) {
      _logFailure(stage, error, stackTrace);
      if (error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> registerWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.sendEmailVerification();
  }

  Future<void> sendVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  Future<User?> reloadUser() async {
    final uid = _auth.currentUser?.uid;
    await _auth.currentUser?.reload();
    if (_auth.currentUser?.uid != uid) return null;
    await _auth.currentUser?.getIdToken(true);
    return _auth.currentUser;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Keep identical completion behavior with enumeration protection on or off.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  /// Explicitly attach a password to this authenticated Google UID only.
  /// Fresh Google authentication proves ownership; never look up accounts by email.
  Future<void> linkPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null ||
        !user.emailVerified ||
        user.email == null ||
        !user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        ) ||
        user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await _initializeGoogle();
    final account = await _google.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw FirebaseAuthException(code: 'invalid-credential');
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
    if (_auth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await user.linkWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
  }

  Future<void> verifyResetCode(String code) async {
    await _auth.verifyPasswordResetCode(code);
  }

  Future<void> confirmPasswordReset(String code, String password) =>
      _auth.confirmPasswordReset(code: code, newPassword: password);

  Future<void> applyEmailVerification(String code) async {
    final info = await _auth.checkActionCode(code);
    if (info.operation != ActionCodeInfoOperation.verifyEmail) {
      throw FirebaseAuthException(code: 'invalid-action-code');
    }
    await _auth.applyActionCode(code);
  }

  Future<void> signOut() async {
    // Attempt both providers even when one fails. Firebase remains authoritative.
    Object? googleError;
    StackTrace? googleStackTrace;
    try {
      await _initializeGoogle();
      await _google.signOut();
    } catch (error, stackTrace) {
      _logFailure('Google sign-out', error, stackTrace);
      googleError = error;
      googleStackTrace = stackTrace;
    }
    try {
      await _auth.signOut();
    } catch (error, stackTrace) {
      _logFailure('Firebase sign-out', error, stackTrace);
      rethrow;
    }
    if (googleError != null) {
      Error.throwWithStackTrace(googleError, googleStackTrace!);
    }
  }
}
