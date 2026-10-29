import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'support/test_auth_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
const unverified = AuthUser(
  id: 'email',
  email: 'student@example.edu',
  emailVerified: false,
  providers: ['password'],
);
const verified = AuthUser(
  id: 'email',
  email: 'student@example.edu',
  emailVerified: true,
  providers: ['password'],
);
void main() {
  late TestAuthRepository repo;
  late TestProfileRepository profiles;
  late AuthViewModel auth;
  setUp(() {
    repo = TestAuthRepository();
    profiles = TestProfileRepository();
    auth = AuthViewModel(repo, profiles);
  });
  tearDown(() async {
    auth.dispose();
    await repo.controller.close();
    await profiles.controller.close();
  });
  test(
    'registration gates all profile access until verification; verification never approves',
    () async {
      repo.controller.add(null);
      await flush();
      repo.emailUser = unverified;
      expect(
        await auth.registerWithEmail('student@example.edu', 'Secure123!'),
        isTrue,
      );
      await flush();
      expect(auth.user!.requiresEmailVerification, isTrue);
      expect(profiles.watchCalls, 0);
      expect(await auth.saveProfile(validDetails), isFalse);
      expect(profiles.saveCalls, 0);
      for (final path in [
        AppRoutes.home,
        AppRoutes.completeProfile,
        AppRoutes.events,
        AppRoutes.qr,
        AppRoutes.organizations,
      ]) {
        expect(
          authRedirect(
            auth.status,
            path,
            profileStatus: ProfileStatus.ready,
            eligible: true,
            requiresEmailVerification: true,
          ),
          AppRoutes.verifyEmail,
        );
      }
      await auth.resendVerification();
      expect(repo.verifications, 1);
      repo.emailUser = verified;
      await auth.checkVerification();
      await flush();
      expect(profiles.watchCalls, 1);
      profiles.controller.add(profile(status: 'pending'));
      await flush();
      expect(auth.profile!.isEligible, isFalse);
      expect(
        authRedirect(
          auth.status,
          AppRoutes.home,
          profileStatus: auth.profileStatus,
          eligible: false,
        ),
        AppRoutes.accountStatus,
      );
      profiles.controller.add(profile());
      await flush();
      expect(
        authRedirect(
          auth.status,
          AppRoutes.home,
          profileStatus: auth.profileStatus,
          eligible: auth.profile!.isEligible,
        ),
        isNull,
      );
    },
  );
  test(
    'double submission is disabled and auth failures do not write a profile',
    () async {
      repo.controller.add(null);
      await flush();
      repo.signInGate = Completer<void>();
      final first = auth.registerWithEmail('student@example.edu', 'Secure123!');
      expect(
        await auth.registerWithEmail('student@example.edu', 'Secure123!'),
        isFalse,
      );
      expect(repo.emailRegistrations, 1);
      repo.signInGate!.complete();
      expect(await first, isTrue);
      await flush();
      expect(profiles.saveCalls, 0);
    },
  );
  test(
    'resend/check failure remains recoverable without granting eligibility',
    () async {
      repo.controller.add(unverified);
      await flush();
      repo.signInError = FirebaseAuthException(code: 'too-many-requests');
      expect(await auth.resendVerification(), isFalse);
      expect(auth.failure!.message, contains('Too many attempts'));
      expect(profiles.watchCalls, 0);
      repo.signInError = null;
      repo.emailUser = unverified;
      await auth.checkVerification();
      expect(auth.message, contains('not verified'));
    },
  );
  test(
    'forgot password returns neutral completion and reset codes are required',
    () async {
      repo.controller.add(null);
      await flush();
      expect(await auth.forgotPassword('unknown@example.edu'), isTrue);
      expect(auth.message, contains('If this address'));
      expect(auth.resetEmail, 'unknown@example.edu');
      expect(await auth.verifyResetCode(''), isFalse);
      expect(repo.resetChecks, 0);
      repo.signInError = FirebaseAuthException(code: 'expired-action-code');
      expect(await auth.verifyResetCode('expired'), isFalse);
      expect(auth.failure!.message, contains('expired'));
      expect(auth.passwordResetSucceeded, isFalse);
      repo.signInError = null;
      expect(await auth.verifyResetCode('valid'), isTrue);
      expect(await auth.confirmPasswordReset('valid', 'short'), isFalse);
      expect(repo.passwordChanges, 0);
      expect(await auth.confirmPasswordReset('valid', 'Secure123!'), isTrue);
      expect(auth.passwordResetSucceeded, isTrue);
      expect(repo.passwordChanges, 1);
      expect(profiles.saveCalls, 0);
    },
  );
  test('linking is explicit and requires a verified Google identity', () async {
    repo.controller.add(verified);
    await flush();
    expect(await auth.linkPassword('Secure123!'), isFalse);
    expect(repo.links, 0);
    const google = AuthUser(
      id: 'existing-google-uid',
      email: 'student@example.edu',
      providers: ['google.com'],
    );
    repo.controller.add(google);
    await flush();
    repo.emailUser = const AuthUser(
      id: 'existing-google-uid',
      email: 'student@example.edu',
      providers: ['google.com', 'password'],
    );
    expect(await auth.linkPassword('Secure123!'), isTrue);
    expect(auth.user!.id, google.id);
    expect(repo.links, 1);
    expect(profiles.saveCalls, 0);
  });
  test(
    'controlled academic values validate a college/program pair, legacy reads stay intact',
    () {
      expect(AcademicOptions.colleges, ['College of Engineering']);
      expect(AcademicOptions.programs.length, 8);
      for (final program in AcademicOptions.programs) {
        expect(
          AcademicOptions.validateProgram(AcademicOptions.college, program),
          isNull,
        );
      }
      expect(
        AcademicOptions.validateProgram(null, AcademicOptions.programs.first),
        isNotNull,
      );
      final legacy = StudentDetails.fromMap({
        ...validDetails.toMap(),
        'college': 'IEEE College',
        'program': 'iOS Research',
      });
      expect(legacy.toMap()['program'], 'iOS Research');
      expect(legacy.hasValidAcademicSelection, isFalse);
      expect(validDetails.hasValidAcademicSelection, isTrue);
    },
  );
  test(
    'errors do not enumerate account existence or include raw Firebase details',
    () {
      final generic = AppFailure.from(
        FirebaseAuthException(code: 'invalid-credential'),
      ).message;
      for (final code in [
        'wrong-password',
        'user-not-found',
        'invalid-login-credentials',
      ]) {
        expect(
          AppFailure.from(
            FirebaseAuthException(code: code, message: 'secret diagnostic'),
          ).message,
          generic,
        );
      }
      for (final code in [
        'email-already-in-use',
        'weak-password',
        'network-request-failed',
        'too-many-requests',
      ]) {
        final message = AppFailure.from(
          FirebaseAuthException(code: code, message: 'secret diagnostic'),
        ).message;
        expect(message, isNot(contains('secret diagnostic')));
        expect(message, isNot(contains('already registered')));
      }
    },
  );
  test(
    'cold action links are preserved while auth initializes; no protected route bypass',
    () {
      expect(authRedirect(AuthStatus.loading, AppRoutes.emailAction), isNull);
      expect(authRedirect(AuthStatus.signedOut, AppRoutes.signUp), isNull);
      expect(
        authRedirect(AuthStatus.signedOut, AppRoutes.home),
        AppRoutes.signIn,
      );
      expect(
        authRedirect(
          AuthStatus.signedIn,
          AppRoutes.home,
          profileStatus: ProfileStatus.ready,
          eligible: false,
        ),
        AppRoutes.accountStatus,
      );
    },
  );
}
