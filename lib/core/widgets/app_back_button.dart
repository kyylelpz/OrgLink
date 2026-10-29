import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';

String parentDestination(String path) {
  if (path.startsWith('${AppRoutes.qr}/') ||
      path == AppRoutes.myAttendance ||
      path == AppRoutes.attendanceHub) {
    return AppRoutes.qr;
  }
  if (path == AppRoutes.myEvents) return AppRoutes.events;
  if (path == AppRoutes.myOrganizations ||
      path == AppRoutes.membershipRequests) {
    return AppRoutes.organizations;
  }
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.firstOrNull == 'organizations' && parts.length > 1) {
    if (parts.length == 2) return AppRoutes.organizations;
    if (parts.length == 3 ||
        (parts.length == 4 &&
            parts[2] == 'events' &&
            ['new', 'manage'].contains(parts[3]))) {
      return '/${parts.take(2).join('/')}';
    }
    return '/${parts.take(parts.length - 1).join('/')}';
  }
  return AppRoutes.home;
}

class AppBackScope extends InheritedWidget {
  const AppBackScope({super.key, required this.back, required super.child});
  final Future<bool> Function() back;
  @override
  bool updateShouldNotify(AppBackScope oldWidget) => back != oldWidget.back;
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    icon: Icon(Icons.arrow_back, color: color),
    onPressed: () async {
      final scope = context.getInheritedWidgetOfExactType<AppBackScope>();
      if (scope != null) {
        await scope.back();
        return;
      }
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(parentDestination(GoRouterState.of(context).uri.path));
      }
    },
  );
}
