import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/services/firestore_service.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/data/repositories/firebase_auth_repository.dart';
import '../features/auth/data/services/firebase_auth_service.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import 'app.dart';
import 'router.dart';

class AppDependencies extends StatelessWidget {
  const AppDependencies({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => FirebaseAuthService(FirebaseAuth.instance)),
        Provider(create: (_) => FirestoreService(FirebaseFirestore.instance)),
        Provider<AuthRepository>(
          create: (context) =>
              FirebaseAuthRepository(context.read<FirebaseAuthService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthViewModel(context.read<AuthRepository>()),
        ),
        Provider<GoRouter>(
          create: (context) => createAppRouter(context.read<AuthViewModel>()),
          dispose: (_, router) => router.dispose(),
        ),
      ],
      child: const OrgLinkApp(),
    );
  }
}
