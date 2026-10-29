import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../profile/data/models/student_profile.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { loading, signedOut, signedIn, error }

enum ProfileStatus { loading, incomplete, ready, error }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository, this._profiles) {
    _listen();
  }
  final AuthRepository _repository;
  final ProfileRepository _profiles;
  StreamSubscription<AuthUser?>? _subscription;
  StreamSubscription<StudentProfile?>? _profileSubscription;
  Timer? _profileTimeout;
  int _generation = 0;
  bool _disposed = false;
  AuthStatus _status = AuthStatus.loading;
  ProfileStatus _profileStatus = ProfileStatus.loading;
  AuthUser? _user;
  StudentProfile? _profile;
  AppFailure? _failure;
  bool _isSigningIn = false;
  bool _isSigningOut = false;
  bool _isSaving = false;
  bool _signInCancelled = false;
  bool _emailBusy = false;
  String? message;
  String? resetEmail;
  bool passwordResetSucceeded = false;

  AuthStatus get status => _status;
  ProfileStatus get profileStatus => _profileStatus;
  AuthUser? get user => _user;
  StudentProfile? get profile => _profile;
  AppFailure? get failure => _failure;
  bool get isSigningIn => _isSigningIn;
  bool get isSigningOut => _isSigningOut;
  bool get isSaving => _isSaving;
  bool get isBusy => _isSigningIn || _isSigningOut || _isSaving || _emailBusy;
  bool get signInCancelled => _signInCancelled;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _listen() {
    try {
      _subscription = _repository.authStateChanges().listen(
        _onUser,
        onError: (Object error) {
          if (_disposed) return;
          _clearProfile();
          _user = null;
          _status = AuthStatus.error;
          _failure = AppFailure.from(error);
          _notify();
        },
        onDone: () {
          if (!_disposed && _status != AuthStatus.error) {
            _clearProfile();
            _user = null;
            _status = AuthStatus.error;
            _failure = const AppFailure(
              'Session monitoring stopped. Please retry.',
            );
            _notify();
          }
        },
      );
    } catch (error) {
      _status = AuthStatus.error;
      _failure = AppFailure.from(error);
      _notify();
    }
  }

  void _clearProfile() {
    _generation++;
    _profileTimeout?.cancel();
    unawaited(_profileSubscription?.cancel());
    _profileSubscription = null;
    _profile = null;
    _profileStatus = ProfileStatus.loading;
  }

  void _onUser(AuthUser? user) {
    if (_disposed) return;
    if (_user?.id == user?.id &&
        _user?.emailVerified == user?.emailVerified &&
        listEquals(_user?.providers, user?.providers) &&
        _status != AuthStatus.loading &&
        _status != AuthStatus.error) {
      return;
    }
    _clearProfile();
    if (_user?.id != user?.id) {
      resetEmail = null;
      passwordResetSucceeded = false;
      message = null;
    }
    _user = user;
    _failure = null;
    _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    if (user != null && !user.requiresEmailVerification) _watchProfile();
    _notify();
  }

  void _watchProfile() {
    final user = _user;
    if (user == null || _disposed) return;
    final generation = _generation;
    void fail(Object error) {
      if (_disposed || generation != _generation) return;
      _profileTimeout?.cancel();
      _profileStatus = ProfileStatus.error;
      _failure = AppFailure.from(error);
      _notify();
    }

    _profileTimeout = Timer(
      const Duration(seconds: 20),
      () => fail(
        const AppFailure(
          'Unable to verify your profile. Check your connection and retry.',
        ),
      ),
    );
    try {
      _profileSubscription = _profiles
          .watch(user.id)
          .listen(
            (profile) {
              if (_disposed || generation != _generation) return;
              _profileTimeout?.cancel();
              _profile = profile;
              _failure = null;
              _profileStatus = profile?.isComplete == true
                  ? ProfileStatus.ready
                  : ProfileStatus.incomplete;
              _notify();
            },
            onError: fail,
            onDone: () => fail(
              const AppFailure('Profile monitoring stopped. Please retry.'),
            ),
          );
    } catch (error) {
      fail(error);
    }
  }

  Future<void> retry() async {
    if (_disposed || isBusy) return;
    if (_user?.requiresEmailVerification == true) {
      await checkVerification();
      return;
    }
    _failure = null;
    if (_user != null && _status == AuthStatus.signedIn) {
      _clearProfile();
      _watchProfile();
      _notify();
    } else {
      _status = AuthStatus.loading;
      _notify();
      await _subscription?.cancel();
      if (!_disposed) _listen();
    }
  }

  Future<void> signInWithGoogle() async {
    if (_disposed || isBusy || _status != AuthStatus.signedOut) return;
    _isSigningIn = true;
    _failure = null;
    _signInCancelled = false;
    _notify();
    try {
      final succeeded = await _repository.signInWithGoogle();
      if (!_disposed) _signInCancelled = !succeeded;
    } catch (error) {
      if (!_disposed) _failure = AppFailure.from(error);
    } finally {
      _isSigningIn = false;
      _notify();
    }
  }

  Future<bool> _emailOperation(
    Future<void> Function() action, {
    bool changesIdentity = false,
  }) async {
    if (_disposed || isBusy) return false;
    final uid = _user?.id;
    _emailBusy = true;
    _failure = null;
    message = null;
    _notify();
    try {
      await action();
      if (!_disposed && !changesIdentity && _user?.id != uid) {
        message = null;
        resetEmail = null;
        passwordResetSucceeded = false;
        return false;
      }
      return !_disposed;
    } catch (error) {
      if (!_disposed && (_user?.id == uid || uid == null)) {
        _failure = AppFailure.from(error);
      }
      return false;
    } finally {
      _emailBusy = false;
      _notify();
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    if (_status != AuthStatus.signedOut) return false;
    return _emailOperation(
      () => _repository.signInWithEmail(email, password),
      changesIdentity: true,
    );
  }

  Future<bool> registerWithEmail(String email, String password) async {
    if (_status != AuthStatus.signedOut) return false;
    return _emailOperation(() async {
      final error = AuthInput.email(email) ?? AuthInput.newPassword(password);
      if (error != null) throw AppFailure(error);
      await _repository.registerWithEmail(email, password);
    }, changesIdentity: true);
  }

  Future<bool> resendVerification() => _emailOperation(() async {
    if (_user?.requiresEmailVerification != true) return;
    await _repository.sendVerification();
    message = 'Verification email requested. Check your inbox and spam folder.';
  });
  Future<bool> checkVerification() => _emailOperation(() async {
    final user = await _repository.reloadUser();
    if (!_disposed && _user?.id == user?.id) {
      _onUser(user);
      if (user?.requiresEmailVerification == true) {
        message =
            'Your email is not verified yet. Open the latest verification link and try again.';
      }
    }
  });
  Future<bool> forgotPassword(String email) => _emailOperation(() async {
    await _repository.resetPassword(email);
    resetEmail = email.trim();
    message =
        'If this address can receive a reset email, instructions will arrive shortly. Check your inbox and spam folder.';
  });
  Future<bool> linkPassword(String password) => _emailOperation(() async {
    if (_user?.emailVerified != true ||
        _user?.providers.contains('google.com') != true ||
        _user?.providers.contains('password') == true) {
      throw const AppFailure(
        'Sign in again with your existing method before linking a password.',
      );
    }
    final error = AuthInput.newPassword(password);
    if (error != null) throw AppFailure(error);
    await _repository.linkPassword(password);
    final user = await _repository.reloadUser();
    if (!_disposed && _user?.id == user?.id) _onUser(user);
    message = 'Password linked to your existing account.';
  });

  Future<bool> verifyResetCode(String code) => _emailOperation(() async {
    passwordResetSucceeded = false;
    if (code.isEmpty) {
      throw const AppFailure(
        'This link is invalid or has expired. Request a new email and try again.',
      );
    }
    await _repository.verifyResetCode(code);
  });
  Future<bool> confirmPasswordReset(String code, String password) =>
      _emailOperation(() async {
        if (code.isEmpty || AuthInput.newPassword(password) != null) {
          throw AppFailure(
            code.isEmpty
                ? 'Request a new reset email and open its link.'
                : AuthInput.newPassword(password)!,
          );
        }
        await _repository.confirmPasswordReset(code, password);
        if (!_disposed) passwordResetSucceeded = true;
      });
  Future<bool> applyEmailVerification(String code) => _emailOperation(() async {
    await _repository.applyEmailVerification(code);
    final user = await _repository.reloadUser();
    if (!_disposed && _user?.id == user?.id) _onUser(user);
    message = 'Your email was verified. Sign in to continue.';
  });

  Future<bool> saveProfile(StudentDetails details) async {
    final user = _user;
    if (_disposed || isBusy || user == null || user.requiresEmailVerification) {
      return false;
    }
    if (!details.isValid || !details.hasValidAcademicSelection) {
      _failure = const AppFailure('Please correct the student details.');
      _notify();
      return false;
    }
    final generation = _generation;
    _isSaving = true;
    _failure = null;
    _notify();
    try {
      await _profiles.save(user, details);
      return !_disposed && generation == _generation;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _failure = AppFailure.from(error);
      }
      return false;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    if (_disposed || isBusy) return;
    _isSigningOut = true;
    _failure = null;
    _notify();
    try {
      await _repository.signOut();
    } catch (error) {
      if (!_disposed) _failure = AppFailure.from(error);
    } finally {
      _isSigningOut = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clearProfile();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
