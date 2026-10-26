import 'dart:async';

import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/data/repositories/auth_repository.dart';

class TestAuthRepository implements AuthRepository {
  final controller = StreamController<AuthUser?>.broadcast();
  Object? signOutError;

  @override
  Stream<AuthUser?> authStateChanges() => controller.stream;

  @override
  Future<void> signOut() async {
    if (signOutError case final error?) throw error;
    controller.add(null);
  }
}
