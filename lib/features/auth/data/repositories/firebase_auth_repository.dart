import '../../../../core/errors/app_failure.dart';
import '../models/auth_user.dart';
import '../services/firebase_auth_service.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._service);

  final FirebaseAuthService _service;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    try {
      await for (final user in _service.authStateChanges()) {
        yield user == null
            ? null
            : AuthUser(
                id: user.uid,
                email: user.email,
                displayName: user.displayName,
              );
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _service.signOut();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}
