import 'package:flutter/foundation.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:orglink/features/auth/data/services/firebase_auth_service.dart';

class TestGoogleAccount extends Fake implements GoogleSignInAccount {
  TestGoogleAccount([this.token = 'test-id-token']);
  final String? token;
  @override
  GoogleSignInAuthentication get authentication =>
      GoogleSignInAuthentication(idToken: token);
}

class TestGoogle extends Fake implements GoogleSignIn {
  int initializations = 0;
  int signOuts = 0;
  Object? initializationError;
  Object? authError;
  Object? signOutError;
  TestGoogleAccount account = TestGoogleAccount();
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializations++;
    if (initializationError case final error?) throw error;
  }

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    if (authError case final error?) throw error;
    return account;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutError case final error?) throw error;
  }
}

class TestFirebase extends Fake implements FirebaseAuth {
  Object? credentialError;
  AuthCredential? credential;
  int signOuts = 0;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    this.credential = credential;
    if (credentialError case final error?) throw error;
    return TestUserCredential();
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class TestUserCredential extends Fake implements UserCredential {}

void main() {
  late TestGoogle google;
  late TestFirebase firebase;
  late FirebaseAuthService service;
  late DebugPrintCallback originalDebugPrint;
  late List<String> logs;
  setUp(() {
    originalDebugPrint = debugPrint;
    logs = [];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    google = TestGoogle();
    firebase = TestFirebase();
    service = FirebaseAuthService(firebase, google);
  });
  tearDown(() {
    debugPrint = originalDebugPrint;
  });
  test(
    'exchanges Google ID token for Firebase credentials and initializes once',
    () async {
      expect(await service.signInWithGoogle(), isTrue);
      expect(firebase.credential?.providerId, 'google.com');
      expect((firebase.credential as OAuthCredential).idToken, 'test-id-token');
      await service.signOut();
      await service.signInWithGoogle();
      expect(google.initializations, 1);
      expect(google.signOuts, 1);
      expect(firebase.signOuts, 1);
    },
  );
  test('cancellation never authenticates Firebase', () async {
    google.authError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    expect(await service.signInWithGoogle(), isFalse);
    expect(firebase.credential, isNull);
  });
  test('missing ID token is rejected', () async {
    google.account = TestGoogleAccount(null);
    await expectLater(
      service.signInWithGoogle(),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(firebase.credential, isNull);
  });
  test('configuration failures are not treated as cancellation', () async {
    google.authError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
    );
    await expectLater(
      service.signInWithGoogle(),
      throwsA(isA<GoogleSignInException>()),
    );
    expect(firebase.credential, isNull);
  });
  test('Firebase signs out even if Google sign-out fails', () async {
    google.signOutError = StateError('Google failed');
    await expectLater(service.signOut(), throwsStateError);
    expect(firebase.signOuts, 1);
    expect(google.signOuts, 1);
  });
  test(
    'logs original missing-server-client error before friendly mapping',
    () async {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'serverClientId must be provided on Android',
        details: 'test-sensitive-details',
      );
      google.authError = error;
      await expectLater(service.signInWithGoogle(), throwsA(same(error)));
      expect(
        logs.join('\n'),
        contains(
          'Google authentication: GoogleSignInException code=clientConfigurationError',
        ),
      );
      expect(
        logs.join('\n'),
        contains('serverClientId must be provided on Android'),
      );
      expect(logs.join('\n'), isNot(contains('test-sensitive-details')));
      expect(logs.join('\n'), isNot(contains('test-id-token')));
      expect(
        AppFailure.from(error).message,
        contains('not configured correctly'),
      );
      expect(
        AppFailure.from(StateError('unrelated')).message,
        isNot(contains('not configured correctly')),
      );
    },
  );
  test(
    'initialization failures are logged and preserve their exception',
    () async {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
        description: 'Provider setup failed',
      );
      google.initializationError = error;
      await expectLater(service.signInWithGoogle(), throwsA(same(error)));
      expect(
        logs.join('\n'),
        contains(
          'Google initialization: GoogleSignInException code=providerConfigurationError',
        ),
      );
      expect(firebase.credential, isNull);
    },
  );
  test('Firebase exchange errors include original code and message', () async {
    final error = FirebaseAuthException(
      code: 'operation-not-allowed',
      message: 'Google provider is disabled',
    );
    firebase.credentialError = error;
    await expectLater(service.signInWithGoogle(), throwsA(same(error)));
    expect(
      logs.join('\n'),
      contains(
        'Firebase credential exchange: FirebaseAuthException code=operation-not-allowed',
      ),
    );
    expect(logs.join('\n'), contains('Google provider is disabled'));
    expect(logs.join('\n'), isNot(contains('test-id-token')));
  });
}
