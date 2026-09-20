import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/club_event.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_providers.dart';
import 'checkin_qr_screen.dart';
import '../../../core/utils/friendly_error.dart';

class CheckInScannerScreen extends ConsumerStatefulWidget {
  const CheckInScannerScreen({super.key});

  @override
  ConsumerState<CheckInScannerScreen> createState() => _CheckInScannerScreenState();
}

class _CheckInScannerScreenState extends ConsumerState<CheckInScannerScreen> {
  final _controller = MobileScannerController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !raw.startsWith(checkInQrPrefix)) {
      setState(() => _message = "That's not a STEAM Club check-in code.");
      return;
    }

    final eventId = raw.substring(checkInQrPrefix.length);
    final events = ref.read(eventsProvider).value ?? const <ClubEvent>[];
    final event = events.firstWhereOrNull((e) => e.id == eventId);
    if (event == null || !event.checkInEnabled) {
      setState(() => _message = "This code isn't set up for check-in.");
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check in?'),
        content: Text(event.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Check In')),
        ],
      ),
    );

    if (confirmed != true) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    final uid = ref.read(currentAppUserProvider).value?.uid;
    if (uid == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      await ref.read(attendanceRepositoryProvider).checkIn(uid: uid, event: event);
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked in! +1 point.')));
      }
    } on AlreadyCheckedInException {
      if (mounted) setState(() => _message = "You're already checked in to this event.");
    } on CheckInNotAvailableException {
      if (mounted) setState(() => _message = "This code isn't set up for check-in.");
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                tooltip: on ? 'Turn flashlight off' : 'Turn flashlight on',
                onPressed: state.isRunning ? _controller.toggleTorch : null,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) => _CameraProblem(error: error),
          ),
          // A frame to aim the code into.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: IgnorePointer(
              child: Text(
                'Point your camera at the meeting\'s check-in code',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
            ),
          ),
          if (_message != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

/// Shown instead of the camera when it can't run — most often because camera
/// access was denied, which otherwise looks like a blank screen.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final canOpenSettings = denied && defaultTargetPlatform == TargetPlatform.iOS;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 56, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              denied ? 'Camera access is off' : "The camera isn't available",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              denied
                  ? 'Allow camera access for STEAM Club in Settings to scan the check-in code.'
                  : 'Close this screen and try again, or ask the person running the meeting to check you in.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (canOpenSettings) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: () => launchUrl(Uri.parse('app-settings:')), child: const Text('Open Settings')),
            ],
          ],
        ),
      ),
    );
  }
}
