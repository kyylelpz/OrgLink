import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';

import 'support/test_auth_repository.dart';

Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

void main() {
  late TestAuthRepository repository;
  late AuthViewModel auth;

  setUp(() {
    repository = TestAuthRepository();
    auth = AuthViewModel(repository);
  });

  tearDown(() async {
    auth.dispose();
    await repository.controller.close();
  });

  test(
    'waits for Firebase state, exposes identity and follows sign-out',
    () async {
      expect(auth.status, AuthStatus.loading);
      repository.controller.add(null);
      await flushEvents();
      expect(auth.status, AuthStatus.signedOut);
      repository.controller.add(const AuthUser(id: 'student'));
      await flushEvents();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user?.id, 'student');
      await auth.signOut();
      await flushEvents();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.user, isNull);
    },
  );

  test('stream errors clear identity; retry resubscribes', () async {
    repository.controller.add(const AuthUser(id: 'student'));
    await flushEvents();
    repository.controller.addError(const AppFailure('Session unavailable'));
    await flushEvents();
    expect(auth.status, AuthStatus.error);
    expect(auth.user, isNull);
    expect(auth.failure?.message, 'Session unavailable');
    await auth.retry();
    expect(auth.status, AuthStatus.loading);
    repository.controller.add(null);
    await flushEvents();
    expect(auth.status, AuthStatus.signedOut);
    expect(auth.failure, isNull);
  });

  test(
    'failed sign-out exposes error without inventing a signed-out session',
    () async {
      repository.controller.add(const AuthUser(id: 'student'));
      await flushEvents();
      repository.signOutError = const AppFailure('Sign-out failed');
      await auth.signOut();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user?.id, 'student');
      expect(auth.failure?.message, 'Sign-out failed');
      expect(auth.isSigningOut, isFalse);
    },
  );

  test('an unexpectedly closed auth stream fails closed', () async {
    await repository.controller.close();
    expect(auth.status, AuthStatus.error);
  });

  test('dispose cancels the auth listener', () async {
    final other = AuthViewModel(repository);
    other.dispose();
    repository.controller.add(null);
    await flushEvents();
    expect(other.status, AuthStatus.loading);
  });
}
