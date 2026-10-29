import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_feedback.dart';
import 'splash_gate.dart';

/// Paint the existing splash before starting Firebase; carry its elapsed display
/// time into the router so initialization and the minimum duration overlap.
class AppStartup extends StatefulWidget {
  const AppStartup({
    super.key,
    required this.initialize,
    required this.builder,
  });
  final Future<void> Function() initialize;
  final Widget Function(SplashGate gate) builder;
  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  final _gate = SplashGate();
  bool _ready = false, _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize();
    });
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'OrgLink startup',
        ),
      );
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _gate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.builder(_gate)
      : MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: MinimumSplash(
            gate: _gate,
            error: _failed
                ? const Scaffold(
                    body: AppErrorView(
                      message:
                          'OrgLink could not start. Please close and reopen the app.',
                    ),
                  )
                : null,
          ),
        );
}
