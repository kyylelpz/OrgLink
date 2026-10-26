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
          'Google Sign-In must be enabled in Firebase Authentication.',
        ),
        'invalid-credential' => const AppFailure(
          'Google credentials could not be verified. Try signing in again.',
        ),
        'account-exists-with-different-credential' => const AppFailure(
          'This email already uses another sign-in method.',
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
