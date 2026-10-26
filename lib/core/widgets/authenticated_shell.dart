import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';

class AuthenticatedShell extends StatelessWidget {
  const AuthenticatedShell({
    super.key,
    required this.child,
    required this.path,
  });
  final Widget child;
  final String path;
  @override
  Widget build(BuildContext context) {
    final index = path.startsWith('/qr')
        ? 2
        : path == AppRoutes.completeProfile
        ? 4
        : path.contains('events') || path == AppRoutes.myAttendance
        ? 3
        : path.startsWith('/organizations') ||
              path == AppRoutes.myOrganizations ||
              path == AppRoutes.membershipRequests ||
              path == AppRoutes.attendanceHub
        ? 1
        : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (index) => context.go(
          [
            AppRoutes.home,
            AppRoutes.organizations,
            AppRoutes.qr,
            AppRoutes.events,
            AppRoutes.completeProfile,
          ][index],
        ),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(
            icon: Icon(Icons.groups),
            label: 'Organizations',
          ),
          NavigationDestination(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.qr_code_scanner,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            label: 'QR',
          ),
          const NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
          const NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
