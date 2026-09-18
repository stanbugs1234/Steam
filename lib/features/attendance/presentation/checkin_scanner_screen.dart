import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../models/club_event.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_providers.dart';
import 'checkin_qr_screen.dart';

class CheckInScannerScreen extends ConsumerStatefulWidget {
  const CheckInScannerScreen({super.key});

  @override
  ConsumerState<CheckInScannerScreen> createState() => _CheckInScannerScreenState();
}

class _CheckInScannerScreenState extends ConsumerState<CheckInScannerScreen> {
  bool _busy = false;
  String? _message;

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
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in! +1 point.')),
        );
      }
    } on AlreadyCheckedInException {
      if (mounted) setState(() => _message = "You're already checked in to this event.");
    } on CheckInNotAvailableException {
      if (mounted) setState(() => _message = "This code isn't set up for check-in.");
    } catch (e) {
      if (mounted) setState(() => _message = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check In')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleDetect),
          if (_message != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
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
