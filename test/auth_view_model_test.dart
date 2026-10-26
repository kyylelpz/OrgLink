import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'support/test_auth_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late TestAuthRepository repository;
  late TestProfileRepository profiles;
  late AuthViewModel auth;
  setUp(() {
    repository = TestAuthRepository();
    profiles = TestProfileRepository();
    auth = AuthViewModel(repository, profiles);
  });
  tearDown(() async {
    auth.dispose();
    await repository.controller.close();
    await profiles.controller.close();
  });

  test(
    'restored sessions load profile once; duplicates do not refetch',
    () async {
      expect(auth.status, AuthStatus.loading);
      repository.controller.add(student);
      await flush();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.profileStatus, ProfileStatus.loading);
      profiles.controller.add(profile());
      await flush();
      expect(auth.profile?.isEligible, isTrue);
      repository.controller.add(student);
      await flush();
      expect(profiles.watchCalls, 1);
      await auth.signOut();
      await flush();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.user, isNull);
      expect(auth.profile, isNull);
    },
  );
  test('Google cancellation and failure leave the user signed out', () async {
    repository.controller.add(null);
    await flush();
    repository.cancelSignIn = true;
    await auth.signInWithGoogle();
    expect(auth.signInCancelled, isTrue);
    expect(auth.failure, isNull);
    expect(auth.status, AuthStatus.signedOut);
    repository.signInError = const AppFailure('Google failed');
    await auth.signInWithGoogle();
    expect(auth.failure?.message, 'Google failed');
    expect(auth.isBusy, isFalse);
  });
  test('sign-in prevents duplicates; success follows auth stream', () async {
    repository.controller.add(null);
    await flush();
    repository.signInGate = Completer<void>();
    final first = auth.signInWithGoogle();
    await auth.signInWithGoogle();
    expect(repository.signInCalls, 1);
    expect(auth.isSigningIn, isTrue);
    repository.signInGate!.complete();
    await first;
    await flush();
    expect(auth.user?.id, student.id);
    expect(auth.profileStatus, ProfileStatus.loading);
  });
  test('missing profile can be saved once and becomes eligible', () async {
    repository.controller.add(student);
    await flush();
    profiles.controller.add(null);
    await flush();
    expect(auth.profileStatus, ProfileStatus.incomplete);
    profiles.saveGate = Completer<void>();
    final save = auth.saveProfile(validDetails);
    expect(auth.isSaving, isTrue);
    expect(await auth.saveProfile(validDetails), isFalse);
    profiles.saveGate!.complete();
    expect(await save, isTrue);
    await flush();
    expect(profiles.saveCalls, 1);
    expect(auth.profile?.isEligible, isTrue);
  });
  test('save errors preserve entered profile and allow retry', () async {
    repository.controller.add(student);
    await flush();
    profiles.controller.add(profile());
    await flush();
    profiles.saveError = const AppFailure('Permission denied');
    expect(await auth.saveProfile(validDetails), isFalse);
    expect(auth.failure?.message, 'Permission denied');
    expect(auth.isSaving, isFalse);
    expect(auth.profile?.details.fullName, validDetails.fullName);
  });
  test(
    'profile failures fail closed and retry only the profile listener',
    () async {
      repository.controller.add(student);
      await flush();
      profiles.controller.addError(const AppFailure('Offline'));
      await flush();
      expect(auth.profileStatus, ProfileStatus.error);
      expect(auth.user, isNotNull);
      await auth.retry();
      expect(auth.profileStatus, ProfileStatus.loading);
      profiles.controller.add(profile(status: 'suspended'));
      await flush();
      expect(auth.profile?.isEligible, isFalse);
      expect(profiles.watchCalls, 2);
    },
  );
  test('switching account discards old profile immediately', () async {
    repository.controller.add(student);
    await flush();
    profiles.controller.add(profile());
    await flush();
    repository.controller.add(const AuthUser(id: 'other'));
    await flush();
    expect(auth.profile, isNull);
    expect(auth.profileStatus, ProfileStatus.loading);
  });
  test('failed sign-out keeps current Firebase identity', () async {
    repository.controller.add(student);
    await flush();
    repository.signOutError = const AppFailure('Sign-out failed');
    await auth.signOut();
    expect(auth.user?.id, student.id);
    expect(auth.failure?.message, 'Sign-out failed');
  });
  test('auth stream failure and closure fail closed', () async {
    repository.controller.add(student);
    await flush();
    profiles.controller.add(profile());
    await flush();
    repository.controller.addError(const AppFailure('Session unavailable'));
    await flush();
    expect(auth.status, AuthStatus.error);
    expect(auth.profile, isNull);
    await auth.retry();
    await repository.controller.close();
    expect(auth.status, AuthStatus.error);
  });
  test('dispose cancels both listeners', () async {
    final other = AuthViewModel(repository, profiles);
    repository.controller.add(student);
    await flush();
    other.dispose();
    profiles.controller.add(profile());
    await flush();
    expect(other.profile, isNull);
  });
}
