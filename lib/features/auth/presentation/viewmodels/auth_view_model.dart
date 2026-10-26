import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { loading, signedOut, signedIn, error }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository) {
    _listen();
  }

  final AuthRepository _repository;
  StreamSubscription<AuthUser?>? _subscription;
  AuthStatus _status = AuthStatus.loading;
  AuthUser? _user;
  AppFailure? _failure;
  bool _isSigningOut = false;
  bool _disposed = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  AppFailure? get failure => _failure;
  bool get isSigningOut => _isSigningOut;

  void _listen() {
    try {
      _subscription = _repository.authStateChanges().listen(
        (user) {
          if (_disposed) return;
          _user = user;
          _failure = null;
          _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
          notifyListeners();
        },
        onError: (Object error) => _setError(error),
        onDone: () {
          if (!_disposed && _status != AuthStatus.error) {
            _setError(
              const AppFailure(
                'Your session could not be monitored. Please try again.',
              ),
            );
          }
        },
      );
    } catch (error) {
      _setError(error);
    }
  }

  void _setError(Object error) {
    if (_disposed) return;
    _user = null;
    _failure = AppFailure.from(error);
    _status = AuthStatus.error;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_status == AuthStatus.loading || _disposed) return;
    _status = AuthStatus.loading;
    _failure = null;
    notifyListeners();
    await _subscription?.cancel();
    if (!_disposed) _listen();
  }

  Future<void> signOut() async {
    if (_isSigningOut || _disposed) return;
    _isSigningOut = true;
    _failure = null;
    notifyListeners();
    try {
      await _repository.signOut();
      // The auth stream remains the source of truth for navigation.
    } catch (error) {
      if (!_disposed) {
        _failure = AppFailure.from(error);
      }
    } finally {
      if (!_disposed) {
        _isSigningOut = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
