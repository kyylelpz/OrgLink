import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../../../events/presentation/widgets/event_widgets.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';
import '../viewmodels/my_attendance_view_model.dart';
import '../viewmodels/scanner_view_model.dart';
import 'attendance_screens.dart';
import '../scanner_route_observer.dart';

// The plugin owns one native camera session. Serialize operations across route
// instances as well as within one scanner (including rapid tab re-entry).
Future<void> _cameraOperations = Future<void>.value();
MobileScannerPlatform? _cameraPlatform;

Set<String> attendanceOrganizations(EventHubViewModel hub) => {
  for (final org in hub.availableOrganizations.values)
    if (canManageAttendance(
      org,
      hub.organizations.membership(org.id),
      hub.organizations.uid,
    ))
      org.id,
};

bool attendancePermissionsReady(EventHubViewModel hub) {
  final orgs = hub.organizations;
  return !orgs.mine.loading &&
      !orgs.managed.loading &&
      orgs.mine.failure == null &&
      orgs.managed.failure == null &&
      orgs.associated.values.every((q) => !q.loading && q.failure == null);
}

class QRLandingScreen extends StatelessWidget {
  const QRLandingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final hub = context.watch<EventHubViewModel>();
    return !attendancePermissionsReady(hub) ||
            attendanceOrganizations(hub).isEmpty
        ? const QRHubScreen()
        : const ScannerScreen();
  }
}

class QRHubScreen extends StatelessWidget {
  const QRHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final hub = context.watch<EventHubViewModel>();
    final permissions = attendanceOrganizations(hub);
    final orgs = hub.organizations;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('QR Hub'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Show your event pass to an authorized organizer, or scan participants when you have attendance permission.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.myQRCode),
            icon: const Icon(Icons.qr_code),
            label: const Text('My QR Code'),
          ),
          FilledButton.tonalIcon(
            onPressed: !attendancePermissionsReady(hub) || permissions.isEmpty
                ? null
                : () => context.go(AppRoutes.qrScan),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Code'),
          ),
          if (permissions.isEmpty)
            const Text(
              'Scanning requires organization manager access or an active officer assignment with attendance permission.',
            ),
          if (orgs.mine.loading ||
              orgs.managed.loading ||
              orgs.associated.values.any((q) => q.loading))
            const LinearProgressIndicator(),
          if (orgs.mine.failure != null ||
              orgs.managed.failure != null ||
              orgs.associated.values.any((q) => q.failure != null))
            AppErrorView(
              message: 'Unable to load attendance permissions.',
              onRetry: orgs.retry,
            ),
          TextButton(
            onPressed: () => context.go(AppRoutes.myAttendance),
            child: const Text('My Attendance'),
          ),
          if (permissions.isNotEmpty)
            TextButton(
              onPressed: () => context.go(AppRoutes.attendanceHub),
              child: const Text('Attendance Management'),
            ),
        ],
      ),
    );
  }
}

class MyQRCodeScreen extends StatelessWidget {
  const MyQRCodeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<MyAttendanceViewModel>(), hub = model.events;
    final eligible = (hub.mine.value ?? [])
        .where((r) => r.status == 'registered')
        .toList();
    final selected = model.selected;
    final event = hub.registeredEvents[selected]?.value;
    final record = model.records[selected];
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('My QR Code'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: model.busy ? null : model.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Select a registered event. A pass can be issued only during the attendance window and is checked by the server when scanned.',
          ),
          if (hub.mine.loading) const LinearProgressIndicator(),
          if (hub.mine.failure != null)
            AppErrorView(
              message: hub.mine.failure!.message,
              onRetry: hub.mine.retry,
            ),
          if (!hub.mine.loading && eligible.isEmpty)
            const Text('You have no active event registrations.'),
          DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue:
                eligible.any(
                  (r) => '${r.organizationId}/${r.eventId}' == selected,
                )
                ? selected
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Registered Event'),
            items: [
              for (final r in eligible)
                DropdownMenuItem(
                  value: '${r.organizationId}/${r.eventId}',
                  child: Text(
                    hub
                            .registeredEvents['${r.organizationId}/${r.eventId}']
                            ?.value
                            ?.title ??
                        'Event details unavailable',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: model.busy ? null : model.select,
          ),
          if (selected != null) ...[
            Text(
              hub.availableOrganizations[selected.split('/')[0]]?.name ??
                  'Organization Unavailable',
            ),
            Text('${schedule(event?.startAt)} - ${schedule(event?.endAt)}'),
            const Text('Registration: Registered'),
            if (record?.loading == false && record?.failure == null)
              Text('Attendance: ${attendanceLabel(record?.value)}'),
            if (hub.registeredEvents[selected]?.loading == true ||
                record?.loading == true)
              const LinearProgressIndicator(),
            if (hub.registeredEvents[selected]?.failure != null)
              TextButton(
                onPressed: hub.registeredEvents[selected]!.retry,
                child: const Text('Retry Event Details'),
              ),
            if (record?.failure != null)
              AppErrorView(
                message: record!.failure!.message,
                onRetry: record.retry,
              ),
            if (record?.value != null) ...[
              const Text('Already Verified'),
              Text(attendanceLabel(record!.value)),
              Text(verificationLabel(record.value)),
            ] else ...[
              if (model.windowMessage != null) Text(model.windowMessage!),
              if (model.credential != null && model.secondsRemaining > 0)
                Center(
                  child: QrImageView(
                    data: model.credential!.payload.encoded,
                    size: 260,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Short-lived attendance pass',
                  ),
                ),
              if (model.credential != null)
                Text(
                  model.secondsRemaining > 0
                      ? 'Expires in ${model.secondsRemaining} seconds. The server determines validity.'
                      : 'This pass has expired. Generate another before scanning.',
                ),
              FilledButton(
                onPressed: model.canGenerate ? model.generate : null,
                child: Text(
                  model.credential == null
                      ? 'Generate QR Pass'
                      : 'Regenerate QR Pass',
                ),
              ),
            ],
          ],
          if (model.busy) const LinearProgressIndicator(),
          if (model.failure != null) Text(model.failure!.message),
          TextButton(
            onPressed: () => context.go(AppRoutes.myAttendance),
            child: const Text('My Attendance'),
          ),
        ],
      ),
    );
  }
}

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final hub = context.watch<EventHubViewModel>();
    if (!attendancePermissionsReady(hub) ||
        attendanceOrganizations(hub).isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Scan QR Code'),
        ),
        body: Center(
          child:
              hub.organizations.mine.loading ||
                  hub.organizations.managed.loading
              ? const CircularProgressIndicator()
              : const Text('Attendance scanning permission is required.'),
        ),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(
        'scanner/${hub.organizations.uid}/${(attendanceOrganizations(hub).toList()..sort()).join(',')}',
      ),
      create: (context) => ScannerViewModel(
        context.read<AttendanceRepository>(),
        (org) => attendanceOrganizations(hub).contains(org),
      ),
      child: const _CameraScanner(),
    );
  }
}

class _CameraScanner extends StatefulWidget {
  const _CameraScanner();
  @override
  State<_CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<_CameraScanner>
    with WidgetsBindingObserver, RouteAware {
  final camera = MobileScannerController(
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  bool _disposing = false;
  String? _cameraFailure;
  ModalRoute<dynamic>? _route;
  bool _covered = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  bool get _shouldRun =>
      !_disposing &&
      !_covered &&
      _route?.isCurrent == true &&
      _lifecycle == AppLifecycleState.resumed &&
      !context.read<ScannerViewModel>().paused;
  void _syncCamera() {
    // A permission/native start may outlive a route transition. Serialize camera
    // work and recheck visibility after startup before allowing it to stay active.
    _cameraOperations = _cameraOperations
        .then((_) async {
          if (_disposing) return;
          if (_cameraFailure != null && mounted) {
            setState(() => _cameraFailure = null);
          }
          if (_shouldRun) {
            if (!camera.value.isRunning) await camera.start();
          } else {
            await camera.stop();
          }
          if (!_shouldRun) await camera.stop();
        })
        .catchError((Object error) {
          if (mounted && !_disposing) {
            setState(
              () => _cameraFailure =
                  'Camera access could not be updated. Retry camera access.',
            );
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      scannerRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) scannerRouteObserver.subscribe(this, route);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposing) _syncCamera();
      });
    }
  }

  @override
  void didPushNext() {
    _covered = true;
    _syncCamera();
  }

  @override
  void didPopNext() {
    _covered = false;
    _syncCamera();
  }

  @override
  void didPop() {
    _covered = true;
    _syncCamera();
  }

  @override
  void initState() {
    super.initState();
    // Each platform implementation owns its own native session/operation queue.
    if (!identical(_cameraPlatform, MobileScannerPlatform.instance)) {
      _cameraPlatform = MobileScannerPlatform.instance;
      _cameraOperations = Future<void>.value();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (mounted) _syncCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scannerRouteObserver.unsubscribe(this);
    _disposing = true;
    _cameraOperations = _cameraOperations.then((_) => camera.dispose()).catchError((
      Object _,
    ) {
      // A failed native cleanup must not block the next session's recovery attempt.
    });
    unawaited(_cameraOperations);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScannerViewModel>();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Scan QR Code'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Scan an OrgLink attendance pass from any organization you are authorized to verify. Visually confirm the participant before scanning.',
          ),
          Offstage(
            offstage: model.paused,
            child: SizedBox(
              height: 300,
              child: MobileScanner(
                controller: camera,
                useAppLifecycleState: false,
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    final raw = barcode.rawValue;
                    if (raw != null && !model.paused) {
                      final verification = model.scan(raw);
                      _syncCamera();
                      unawaited(verification);
                      break;
                    }
                  }
                },
                errorBuilder: (context, error) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission was denied. Enable camera access in Android settings.'
                            : 'The camera is unavailable. Check camera access and retry.',
                      ),
                      TextButton(
                        onPressed: _syncCamera,
                        child: const Text('Retry Camera'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_cameraFailure != null)
            AppErrorView(message: _cameraFailure!, onRetry: _syncCamera),
          if (model.paused && !model.busy) ...[
            if (model.result != null) ...[
              Text(
                model.result!.duplicate
                    ? 'Already Verified'
                    : 'Attendance verified.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(model.result!.fullName),
              Text(model.result!.organizationName),
              Text(model.result!.eventTitle),
              Text(attendanceLabel(model.result!.record)),
              Text(verificationLabel(model.result!.record)),
            ],
            if (model.failure != null) Text(model.failure!.message),
            FilledButton(
              onPressed: () {
                model.next();
                _syncCamera();
              },
              child: const Text('Scan Next Participant'),
            ),
          ],
          if (model.busy)
            const AppLoadingView(message: 'Verifying attendance...'),
          TextButton(
            onPressed: () => context.go(AppRoutes.attendanceHub),
            child: const Text('Manual Lookup'),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => context.push(AppRoutes.myQRCode),
                child: const Text('My QR Code'),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.myAttendance),
                child: const Text('My Attendance'),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.qrActions),
                child: const Text('QR Hub Actions'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
