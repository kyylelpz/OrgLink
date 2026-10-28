import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../theme/app_tokens.dart';
import 'app_back_button.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({
    super.key,
    required this.child,
    required this.path,
  });
  final Widget child;
  final String path;
  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  static const roots = [
    AppRoutes.home,
    AppRoutes.calendar,
    AppRoutes.qr,
    AppRoutes.organizations,
    AppRoutes.completeProfile,
  ];
  late final List<String> _history;
  bool _confirmingExit = false;
  @override
  void initState() {
    super.initState();
    _history = [widget.path];
  }

  @override
  void didUpdateWidget(AuthenticatedShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == widget.path) return;
    final index = _history.indexOf(widget.path);
    if (index >= 0) {
      _history.removeRange(index + 1, _history.length);
    } else {
      _history.add(widget.path);
    }
    if (_history.length > 30) _history.removeAt(0);
  }

  Future<bool> _back() async {
    final router = GoRouter.of(context);
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      await root.maybePop();
      return true;
    }
    if (_confirmingExit) return true;
    if (router.canPop()) {
      router.pop();
      return true;
    }
    if (widget.path != AppRoutes.home) {
      final destination = roots.contains(widget.path)
          ? AppRoutes.home
          : _history.length > 1
          ? _history[_history.length - 2]
          : parentDestination(widget.path);
      router.go(destination);
      return true;
    }
    _confirmingExit = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit OrgLink?'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (mounted && exit == true) await SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final index =
        path.startsWith('/qr') ||
            path == AppRoutes.myAttendance ||
            path == AppRoutes.attendanceHub
        ? 2
        : path == AppRoutes.calendar
        ? 1
        : path == AppRoutes.completeProfile
        ? 4
        : path.startsWith('/organizations') ||
              path == AppRoutes.myOrganizations ||
              path == AppRoutes.membershipRequests
        ? 3
        : 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_back());
      },
      child: BackButtonListener(
        onBackButtonPressed: _back,
        child: AppBackScope(
          back: _back,
          child: Scaffold(
            body: widget.child,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppShape.featureRadius),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppShape.featureRadius),
                ),
                child: NavigationBar(
                  labelPadding: const EdgeInsets.symmetric(vertical: 2),
                  labelTextStyle: WidgetStatePropertyAll(
                    Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 0,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  selectedIndex: index,
                  onDestinationSelected: (index) {
                    context.go(roots[index]);
                  },
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: CircleAvatar(
                        radius: 23,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      label: 'QR',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups),
                      label: 'Organizations',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
