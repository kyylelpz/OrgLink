import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../theme/app_tokens.dart';
import 'app_back_button.dart';
import 'app_asset_icon.dart';

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
    AppRoutes.events, // Changed from AppRoutes.calendar
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
        : path == AppRoutes.events || path == AppRoutes.myEvents
        ? 1 // Changed from AppRoutes.calendar
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
            bottomNavigationBar: OrgLinkNavigationBar(
              selectedIndex: index,
              onDestinationSelected: (index) => context.go(roots[index]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma 15:7293. Label height grows with text scaling; routes stay in the shell.
class OrgLinkNavigationBar extends StatelessWidget {
  const OrgLinkNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  
  // Changed 'Calendar' to 'Events'
  static const labels = ['Home', 'Events', 'QR', 'Organizations', 'Profile'];
  
  // Changed 'calendar' to 'calendar' (reusing the same icon, or change to 'event' if you have it)
  static const _icons = ['home', 'calendar', 'qr', 'organizations', 'profile'];

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    child: SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: labels[i],
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () => onDestinationSelected(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 96),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              2,
                              0,
                              2,
                              AppSpacing.xl,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: i == 2
                                        ? Transform.translate(
                                            offset: const Offset(0, -7),
                                            child: OverflowBox(
                                              maxHeight: 56,
                                              maxWidth: 56,
                                              child: Container(
                                                key: const ValueKey(
                                                  'raised-qr-action',
                                                ),
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: AppColors.brandBlue,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: AppColors.white,
                                                    width: 4,
                                                  ),
                                                ),
                                                alignment: Alignment.center,
                                                child: const AppAssetIcon(
                                                  'qr',
                                                  size: 25,
                                                  color: AppColors.white,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Transform.translate(
                                            offset: const Offset(0, 4),
                                            child: AppAssetIcon(
                                              _icons[i],
                                              size: 22,
                                              color: i == selectedIndex
                                                  ? AppColors.brandBlue
                                                  : AppColors.muted,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: i == selectedIndex
                                            ? AppColors.brandBlue
                                            : AppColors.muted,
                                        fontWeight: i == selectedIndex
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}