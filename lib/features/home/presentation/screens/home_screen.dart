import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/placeholder_screen.dart';
import '../../../auth/presentation/screens/auth_screens.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return PlaceholderScreen(
      title: 'Home Dashboard',
      message:
          'Welcome, ${auth.profile?.details.fullName ?? "student"}. Your student profile is complete.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (auth.failure != null) Text(auth.failure!.message),
          FilledButton(
            onPressed: auth.isBusy
                ? null
                : () => context.go(AppRoutes.completeProfile),
            child: const Text('Edit student profile'),
          ),
          FilledButton.tonal(
            onPressed: () => context.go(AppRoutes.organizations),
            child: const Text('Discover organizations'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.myOrganizations),
            child: const Text('My organizations'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.membershipRequests),
            child: const Text('Membership requests'),
          ),
          const SignOutButton(),
        ],
      ),
    );
  }
}
