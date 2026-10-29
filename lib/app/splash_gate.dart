import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_tokens.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';

/// Presentation state only. No authentication/profile operation waits on it.
class SplashGate extends ChangeNotifier {
  static const minimumDuration = Duration(seconds: 2);
  double progress = 0;
  int cycle = 0;
  bool _initial = true, _active = true, _disposed = false;
  String? _lastUid;
  Uri? pendingLocation;
  bool get minimumElapsed => progress >= 1;
  bool get holding => _active && !minimumElapsed;

  void synchronize(AuthViewModel auth) {
    final uid = auth.user?.id;
    if (!_initial && uid != null && uid != _lastUid) {
      cycle++;
      progress = 0;
      _active = true;
    } else if (!_initial && uid == null && _lastUid != null) {
      // A sign-out/account failure must never be held behind an earlier login.
      _active = false;
      progress = 1;
      pendingLocation = null;
    }
    _lastUid = uid;
    final resolved =
        auth.status != AuthStatus.loading &&
        (auth.status != AuthStatus.signedIn ||
            auth.user?.requiresEmailVerification == true ||
            auth.profileStatus != ProfileStatus.loading);
    if (_active && minimumElapsed && resolved) {
      _active = false;
      _initial = false;
    }
  }

  void recordProgress(int generation, double value) {
    if (!_disposed && generation == cycle && value > progress) progress = value;
  }

  void complete(int generation) {
    if (_disposed || generation != cycle) return;
    progress = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A lifecycle-bound display clock, started only after the splash's first frame.
/// Its progress survives the Firebase-bootstrap -> auth-router handoff.
class MinimumSplash extends StatefulWidget {
  const MinimumSplash({super.key, required this.gate, this.error});
  final SplashGate gate;
  final Widget? error;
  @override
  State<MinimumSplash> createState() => _MinimumSplashState();
}

class _MinimumSplashState extends State<MinimumSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  late final int _cycle;
  @override
  void initState() {
    super.initState();
    _cycle = widget.gate.cycle;
    _clock =
        AnimationController(
          vsync: this,
          duration: SplashGate.minimumDuration,
          animationBehavior: AnimationBehavior.preserve,
          value: widget.gate.progress,
        )..addListener(() {
          // The value reaches 1 at the exact deadline; AnimationStatus may
          // finish on the following frame. Do not add that extra frame.
          if (_clock.value >= 1 && !widget.gate.minimumElapsed && mounted) {
            widget.gate.complete(_cycle);
            setState(() {});
          } else {
            widget.gate.recordProgress(_cycle, _clock.value);
          }
        });
    // AnimationController is just a display clock: it adds no visual animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.gate.minimumElapsed) _clock.forward();
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.gate.minimumElapsed && widget.error != null
      ? widget.error!
      : const AnimatedSplashView();
}

/// The existing splash artwork, size, colors, system bars and animation asset.
class AnimatedSplashView extends StatelessWidget {
  const AnimatedSplashView({super.key});
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
              child: Image.asset(
                'assets/animations/loading_animation.webp',
                fit: BoxFit.contain,
                semanticLabel: 'Loading OrgLink...',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
