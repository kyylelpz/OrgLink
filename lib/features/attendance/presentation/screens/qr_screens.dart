import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_asset_icon.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/theme/app_tokens.dart';
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
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

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
    
    if (!attendancePermissionsReady(hub)) {
      return const Scaffold(
        backgroundColor: AppColors.brandMidnight,
        body: Center(child: CircularProgressIndicator(color: AppColors.white)),
      );
    }

    // Instantly check if they have any valid attendance permissions
    final permissions = attendanceOrganizations(hub);

    // If they have permissions, take them straight to the camera
    if (permissions.isNotEmpty) {
      return const ScannerScreen();
    }

    // Otherwise, show the QR Hub (Member view)
    return const QRHubScreen();
  }
}

class QRHubScreen extends StatelessWidget {
  const QRHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final hub = context.watch<EventHubViewModel>();
    final permissions = attendanceOrganizations(hub);
    final orgs = hub.organizations;
    final name = context.watch<AuthViewModel?>()?.profile?.details.fullName;

    // Check if they hold an officer/manager role but lack attendance permissions
    final isOfficer = orgs.mine.value?.any(
          (m) => m.role == 'officer' || m.role == 'manager',
        ) ==
        true;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          // ... (Keep your existing AppBar code)
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          backgroundColor: AppColors.brandMidnight,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppShape.featureRadius),
            ),
          ),
          leading: const AppBackButton(),
          title: const Text('QR Hub'),
        ),
        body: AppPageBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const AppSectionHeading(
                  title: 'Your Event Pass',
                  description: 'Student QR',
                  prominent: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                
                // ... (Keep your existing dark Event Pass Card)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: const BoxDecoration(
                    color: AppColors.brandMidnight,
                    borderRadius: AppShape.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name?.isNotEmpty == true) ...[
                        Text(
                          name!,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppColors.white),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        'Your registered events, ready to go.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.white),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const AppAssetIcon(
                        'qr',
                        size: 44,
                        color: AppColors.brandPurple,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        "Show up.\nWe'll take it from here.",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // ... (Keep your existing buttons)
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.myQRCode),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('My QR Code'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  onPressed: () => context.go(AppRoutes.myAttendance),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('My Attendance'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),

                // ─── ORGANIZER TOOLS ───
                if (permissions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const AppSectionHeading(title: 'Organizer Tools'),
                  const SizedBox(height: AppSpacing.sm),

                  FilledButton.tonalIcon(
                    onPressed: () => context.go(AppRoutes.qrScan),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR Code'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go(AppRoutes.attendanceHub),
                    icon: const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.success,
                    ),
                    label: const Text('Attendance Management'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success.withValues(alpha: 0.15),
                      foregroundColor: AppColors.success,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],

                // ─── OFFICER WITHOUT PERMISSION NOTICE ───
                if (isOfficer && permissions.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.brandMidnight.withValues(alpha: 0.05),
                      borderRadius: AppShape.card,
                      border: Border.all(
                        color: AppColors.brandMidnight.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.brandMidnight,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Text(
                            'Attendance scanning permission is required. Contact your organization manager to request access.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.brandMidnight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandMist,
        appBar: AppBar(
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          backgroundColor: AppColors.brandMidnight,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppShape.featureRadius),
            ),
          ),
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
        body: AppPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              const AppSectionHeading(
                title: 'Ready to Check In',
                prominent: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Select a registered event.'),
              const SizedBox(height: AppSpacing.lg),

              // Selector
              if (hub.mine.loading) const LinearProgressIndicator(),
              if (hub.mine.failure != null)
                AppErrorView(
                  message: hub.mine.failure!.message,
                  onRetry: hub.mine.retry,
                ),
              if (!hub.mine.loading && eligible.isEmpty)
                const Text('You have no active event registrations.'),

              if (eligible.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(selected),
                  initialValue:
                      eligible.any(
                        (r) => '${r.organizationId}/${r.eventId}' == selected,
                      )
                      ? selected
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Registered Event',
                    border: OutlineInputBorder(),
                  ),
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

              const SizedBox(height: AppSpacing.lg),

              // Premium Event Card
              if (selected != null)
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Use the existing EventSummary for clean title/date
                      if (event != null) ...[
                        EventSummary(event: event),
                        const Divider(height: AppSpacing.xl),
                      ],

                      // Details
                      Text(
                        hub
                                .availableOrganizations[selected.split('/')[0]]
                                ?.name ??
                            'Organization Unavailable',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.brandBlue,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${schedule(event?.startAt)} - ${schedule(event?.endAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Status Chips
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          const AppStatusChip(
                            label: 'Registered',
                            tone: AppStatusTone.success,
                          ),
                          if (record?.loading == false &&
                              record?.failure == null)
                            AttendanceStatusBadge(record?.value),
                        ],
                      ),

                      if (hub.registeredEvents[selected]?.loading == true ||
                          record?.loading == true)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.md),
                          child: LinearProgressIndicator(),
                        ),
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

                      const SizedBox(height: AppSpacing.lg),

                      // QR Generation Area
                      if (record?.value != null) ...[
                        const Center(
                          child: Text(
                            'Already Verified',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Center(child: Text(verificationLabel(record!.value))),
                      ] else ...[
                        // if (name?.isNotEmpty == true) ...[
                        //   Text(
                        //     name!,
                        //     textAlign: TextAlign.center,
                        //     style: Theme.of(context).textTheme.titleMedium,
                        //   ),
                        //   const SizedBox(height: AppSpacing.md),
                        // ],
                        if (model.windowMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Text(
                              model.windowMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        if (model.credential != null &&
                            model.secondsRemaining > 0)
                          LayoutBuilder(
                            builder: (context, constraints) => Center(
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: AppShape.card,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: QrImageView(
                                  data: model.credential!.payload.encoded,
                                  size: constraints.maxWidth.clamp(0, 230),
                                  backgroundColor: Colors.white,
                                  semanticsLabel: 'Short-lived attendance pass',
                                ),
                              ),
                            ),
                          ),
                        if (model.credential != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              model.secondsRemaining > 0
                                  ? 'Expires in ${model.secondsRemaining} seconds. The server determines validity.'
                                  : 'This pass has expired. Generate another before scanning.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
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
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Keep your pass private. Show it only to an authorized attendance operator.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (model.busy) const LinearProgressIndicator(),
              if (model.failure != null) Text(model.failure!.message),

              const SizedBox(height: AppSpacing.md),
              FilledButton.tonalIcon(
                onPressed: () => context.go(AppRoutes.myAttendance),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('My Attendance'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
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
          toolbarHeight:
              56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
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
      backgroundColor: AppColors.brandMidnight,
      appBar: AppBar(
        toolbarHeight:
            56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
        backgroundColor: AppColors.brandMidnight,
        foregroundColor: AppColors.white,
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: AppColors.white),
        leading: const AppBackButton(),
        title: const Text('Scan QR Code'),
      ),
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.white),
        child: AppPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify an Event Pass',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Scan an OrgLink attendance pass from any organization you are authorized to verify. Visually confirm the participant before scanning.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Offstage(
                offstage: model.paused,
                child: ClipRRect(
                  borderRadius: AppShape.feature,
                  child: SizedBox(
                    height: 398,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
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
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      error.errorCode ==
                                              MobileScannerErrorCode
                                                  .permissionDenied
                                          ? 'Camera permission was denied. Enable camera access in Android settings.'
                                          : 'The camera is unavailable. Check camera access and retry.',
                                    ),
                                    OutlinedButton(
                                      onPressed: _syncCamera,
                                      child: const Text('Retry Camera'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Center(
                            child: FractionallySizedBox(
                              widthFactor: 0.7,
                              heightFactor: 0.65,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 3,
                                  ),
                                  borderRadius: AppShape.feature,
                                ),
                                child: const Center(
                                  child: Divider(
                                    color: AppColors.brandPurple,
                                    thickness: 2,
                                    indent: 12,
                                    endIndent: 12,
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
              const SizedBox(height: AppSpacing.lg),
              if (_cameraFailure != null)
                AppSurfaceCard(
                  child: AppErrorView(
                    message: _cameraFailure!,
                    onRetry: _syncCamera,
                  ),
                ),
              if (model.paused && !model.busy) ...[
                if (model.result != null)
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppStatusChip(
                          label: model.result!.duplicate
                              ? 'Already Verified'
                              : 'Attendance Verified',
                          tone: AppStatusTone.success,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          model.result!.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          model.result!.organizationName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          model.result!.eventTitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          attendanceLabel(model.result!.record),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          verificationLabel(model.result!.record),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                if (model.failure != null)
                  AppSurfaceCard(
                    child: Text(
                      model.failure!.message,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                FilledButton(
                  onPressed: () {
                    model.next();
                    _syncCamera();
                  },
                  child: const Text('Scan Next Participant'),
                ),
              ],
              if (model.busy)
                const AppSurfaceCard(
                  child: DefaultTextStyle(
                    style: TextStyle(color: AppColors.ink),
                    child: AppLoadingView(message: 'Verifying attendance...'),
                  ),
                ),
              AppSurfaceCard(
                onTap: () => context.go(AppRoutes.attendanceHub),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandMidnight.withValues(alpha: 0.05),
                        borderRadius: AppShape.button,
                      ),
                      child: const Icon(
                        Icons.search,
                        color: AppColors.brandMidnight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Text(
                        'Manual Lookup',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.brandMidnight,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),

              // OPTIMIZED MORE QR ACTIONS
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'More QR Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Action 1: My QR Code
                    AppSurfaceCard(
                      onTap: () => context.push(AppRoutes.myQRCode),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.brandBlue.withValues(alpha: 0.1),
                              borderRadius: AppShape.button,
                            ),
                            child: const Icon(
                              Icons.qr_code,
                              color: AppColors.brandBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: Text(
                              'My QR Code',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Action 2: My Attendance
                    AppSurfaceCard(
                      onTap: () => context.push(AppRoutes.myAttendance),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: AppShape.button,
                            ),
                            child: const Icon(
                              Icons.fact_check_outlined,
                              color: AppColors.success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: Text(
                              'My Attendance',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Action 3: QR Hub Actions
                    AppSurfaceCard(
                      onTap: () => context.go(AppRoutes.qrActions),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.tonal,
                              borderRadius: AppShape.button,
                            ),
                            child: const Icon(
                              Icons.search,
                              color: AppColors.brandMidnight,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: Text(
                              'QR Hub Actions',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
