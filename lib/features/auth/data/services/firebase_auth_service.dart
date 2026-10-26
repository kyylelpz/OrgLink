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
  Stream<User?> authStateChanges() => _auth.authStateChanges();

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
