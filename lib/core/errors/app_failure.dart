import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode
            .providerConfigurationError => const AppFailure(
          'Google Sign-In is not configured correctly. Check the Firebase Google provider and Android signing fingerprints.',
        ),
        GoogleSignInExceptionCode.interrupted => const AppFailure(
          'Sign-in was interrupted. Please try again.',
        ),
        _ => const AppFailure(
          'Google Sign-In failed. Check your connection and try again.',
        ),
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'network-request-failed' || 'unavailable' => const AppFailure(
          'Unable to connect. Check your internet connection and try again.',
        ),
        'user-disabled' => const AppFailure(
          'This account has been disabled. Contact support.',
        ),
        'operation-not-allowed' => const AppFailure(
          'This sign-in method is currently unavailable. Please try another method.',
        ),
        'wrong-password' ||
        'user-not-found' ||
        'invalid-login-credentials' ||
        'invalid-credential' => const AppFailure(
          'Unable to sign in with those credentials. Check your details and try again.',
        ),
        'account-exists-with-different-credential' => const AppFailure(
          'Unable to complete sign-in. Use your existing sign-in method, then link methods from your account.',
        ),
        'email-already-in-use' ||
        'credential-already-in-use' => const AppFailure(
          'Unable to create or link this account. Try signing in or resetting your password.',
        ),
        'weak-password' ||
        'password-does-not-meet-requirements' => const AppFailure(
          'Use a stronger password that meets the account password requirements.',
        ),
        'invalid-email' => const AppFailure('Enter a valid email address.'),
        'requires-recent-login' ||
        'user-mismatch' ||
        'provider-already-linked' => const AppFailure(
          'Sign in again with your existing method before linking a password.',
        ),
        'invalid-action-code' || 'expired-action-code' => const AppFailure(
          'This link is invalid or has expired. Request a new email and try again.',
        ),
        'too-many-requests' => const AppFailure(
          'Too many attempts. Please try again later.',
        ),
        'deadline-exceeded' => const AppFailure(
          'The request timed out. Check your connection and retry.',
        ),
        'permission-denied' => const AppFailure(
          'You do not have permission to perform this action.',
        ),
        _ => const AppFailure('Something went wrong. Please try again.'),
      };
    }
    return const AppFailure('Something went wrong. Please try again.');
  }
}
