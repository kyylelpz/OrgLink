import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../events/presentation/viewmodels/event_hub_view_model.dart';
import '../../../events/presentation/widgets/event_widgets.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';
import '../viewmodels/my_attendance_view_model.dart';
import '../viewmodels/scanner_view_model.dart';
import 'attendance_screens.dart';

Set<String> attendanceOrganizations(EventHubViewModel hub) => {
  for (final org in hub.availableOrganizations.values)
    if (canManageAttendance(
      org,
      hub.organizations.membership(org.id),
      hub.organizations.uid,
    ))
      org.id,
};

class QRHubScreen extends StatelessWidget {
  const QRHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final hub = context.watch<EventHubViewModel>();
    final permissions = attendanceOrganizations(hub);
    final orgs = hub.organizations;
    return Scaffold(
      appBar: AppBar(title: const Text('QR Hub')),
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
            onPressed: permissions.isEmpty
                ? null
                : () => context.go(AppRoutes.qrScan),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Code'),
          ),
          if (permissions.isEmpty)
            const Text(
              'Scanning requires organization manager access or an active officer assignment with attendance permission.',
            ),
          if (orgs.mine.loading || orgs.managed.loading)
            const LinearProgressIndicator(),
          if (orgs.mine.failure != null || orgs.managed.failure != null)
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
              if (event != null && !attendanceWindow(event, DateTime.now()))
                const Text(
                  'QR issuance is unavailable outside the published event attendance window.',
                ),
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
                onPressed:
                    model.busy ||
                        event == null ||
                        record?.loading != false ||
                        record?.failure != null ||
                        !attendanceWindow(event, DateTime.now())
                    ? null
                    : model.generate,
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
    if (attendanceOrganizations(hub).isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan QR Code')),
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
    with WidgetsBindingObserver {
  final camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !camera.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed &&
        !context.read<ScannerViewModel>().paused) {
      unawaited(camera.start());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScannerViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
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
                      unawaited(camera.stop());
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
                        onPressed: () async {
                          await camera.stop();
                          if (mounted) await camera.start();
                        },
                        child: const Text('Retry Camera'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
              onPressed: () async {
                model.next();
                await camera.start();
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
        ],
      ),
    );
  }
}
