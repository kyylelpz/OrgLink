import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/features/auth/data/services/firebase_auth_service.dart';
import 'firebase_auth_service_test.dart' show TestGoogle;

class GoogleIdentityInfo extends Fake implements UserInfo {
  @override
  String get providerId => 'google.com';
}

class Identity extends Fake implements User {
  @override
  String get uid => 'original-google-uid';
  @override
  String? get email => 'synthetic@example.edu';
  @override
  bool get emailVerified => true;
  @override
  List<UserInfo> get providerData => [GoogleIdentityInfo()];
  final calls = <String>[];
  bool rejectReauthentication = false;
  AuthCredential? linked;
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    calls.add('reauthenticate');
    expect(credential.providerId, 'google.com');
    if (rejectReauthentication) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    return Credential(this);
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    calls.add('link');
    linked = credential;
    return Credential(this);
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    calls.add('verify');
  }
}

class Credential extends Fake implements UserCredential {
  Credential(this.identity);
  final User identity;
  @override
  User get user => identity;
}

class AuthSdk extends Fake implements FirebaseAuth {
  final identity = Identity();
  String? email, password;
  int creates = 0, logins = 0, resets = 0;
  String? resetError;
  @override
  User get currentUser => identity;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    creates++;
    this.email = email;
    this.password = password;
    return Credential(identity);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    logins++;
    this.email = email;
    this.password = password;
    return Credential(identity);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resets++;
    this.email = email;
    if (resetError != null) throw FirebaseAuthException(code: resetError!);
  }
}

void main() {
  test(
    'email SDK registration sends verification and preserves password verbatim',
    () async {
      final sdk = AuthSdk();
      final service = FirebaseAuthService(sdk, TestGoogle());
      await service.registerWithEmail(
        ' synthetic@example.edu ',
        ' Secret123! ',
      );
      expect(sdk.creates, 1);
      expect(sdk.email, 'synthetic@example.edu');
      expect(sdk.password, ' Secret123! ');
      expect(sdk.identity.calls, ['verify']);
      await service.signInWithEmail(' synthetic@example.edu ', ' Secret123! ');
      expect(sdk.logins, 1);
      expect(sdk.password, ' Secret123! ');
    },
  );
  test(
    'password linking reauthenticates Google before attaching to same UID',
    () async {
      final sdk = AuthSdk();
      final service = FirebaseAuthService(sdk, TestGoogle());
      await service.linkPassword('Synthetic123!');
      expect(sdk.identity.calls, ['reauthenticate', 'link']);
      expect(sdk.identity.linked?.providerId, 'password');
      expect(sdk.creates, 0);
      expect(sdk.logins, 0);
      expect(sdk.currentUser.uid, 'original-google-uid');
    },
  );
  test('different Google identity cannot attach a password', () async {
    final sdk = AuthSdk()..identity.rejectReauthentication = true;
    await expectLater(
      FirebaseAuthService(sdk, TestGoogle()).linkPassword('Synthetic123!'),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(sdk.identity.calls, ['reauthenticate']);
    expect(sdk.identity.linked, isNull);
  });
  test(
    'unknown reset address completes neutrally; network and rate limits propagate',
    () async {
      final sdk = AuthSdk()..resetError = 'user-not-found';
      final service = FirebaseAuthService(sdk, TestGoogle());
      await service.resetPassword(' synthetic@example.edu ');
      expect(sdk.email, 'synthetic@example.edu');
      for (final code in ['network-request-failed', 'too-many-requests']) {
        sdk.resetError = code;
        await expectLater(
          service.resetPassword('synthetic@example.edu'),
          throwsA(isA<FirebaseAuthException>()),
        );
      }
    },
  );
}
