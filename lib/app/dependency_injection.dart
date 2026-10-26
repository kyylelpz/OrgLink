import '../features/organizations/data/repositories/organization_repository.dart';
import '../features/organizations/data/repositories/firestore_organization_repository.dart';
import '../features/organizations/data/services/organization_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../features/profile/data/repositories/profile_repository.dart';
import '../features/profile/data/repositories/firestore_profile_repository.dart';
import '../features/profile/data/services/user_profile_service.dart';
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
        Provider(
          create: (_) =>
              FirebaseAuthService(FirebaseAuth.instance, GoogleSignIn.instance),
        ),
        Provider(create: (_) => FirestoreService(FirebaseFirestore.instance)),
        Provider(
          create: (context) =>
              OrganizationService(context.read<FirestoreService>()),
        ),
        Provider<OrganizationRepository>(
          create: (context) => FirestoreOrganizationRepository(
            context.read<OrganizationService>(),
          ),
        ),
        Provider<AuthRepository>(
          create: (context) =>
              FirebaseAuthRepository(context.read<FirebaseAuthService>()),
        ),
        Provider(
          create: (context) =>
              UserProfileService(context.read<FirestoreService>()),
        ),
        Provider<ProfileRepository>(
          create: (context) =>
              FirestoreProfileRepository(context.read<UserProfileService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthViewModel(
            context.read<AuthRepository>(),
            context.read<ProfileRepository>(),
          ),
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
