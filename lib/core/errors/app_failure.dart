import 'package:firebase_core/firebase_core.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is FirebaseException) {
      return switch (error.code) {
        'network-request-failed' || 'unavailable' => const AppFailure(
          'Unable to connect. Check your internet connection and try again.',
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
