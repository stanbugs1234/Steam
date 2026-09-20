import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/widgets/error_state.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../domain/attendance_providers.dart';
import '../domain/checkin_code.dart';

/// The QR an admin shows at a meeting. Its code carries the event's secret,
/// which is what lets members' check-ins be trusted, so only admins get here.
class CheckInQrScreen extends ConsumerWidget {
  const CheckInQrScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Check-In QR')),
      body: !isAdmin
          ? const Center(child: Text('Only admins can show the check-in code.'))
          : eventsAsync.when(
              data: (events) {
                final event = events.firstWhereOrNull((e) => e.id == eventId);
                if (event == null) {
                  return const Center(child: Text('Event not found.'));
                }
                final codeAsync = ref.watch(checkInCodeProvider(eventId));
                final count = ref.watch(checkInCountProvider(eventId)).value;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        codeAsync.when(
                          data: (code) => Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Semantics(
                              label: 'Check-in QR code for ${event.title}',
                              child: QrImageView(data: CheckInCode(eventId: event.id, secret: code).payload, size: 260),
                            ),
                          ),
                          loading: () => const SizedBox(height: 292, child: Center(child: CircularProgressIndicator())),
                          error: (err, _) => ErrorState(
                            message: "Couldn't create the check-in code.",
                            error: err,
                            onRetry: () => ref.invalidate(checkInCodeProvider(eventId)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Have members open Check In from the home screen and scan this code.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (count != null) ...[
                          const SizedBox(height: 8),
                          Text('$count checked in so far', style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorState(
                message: "Couldn't load this event.",
                error: err,
                onRetry: () => ref.invalidate(eventsProvider),
              ),
            ),
    );
  }
}
