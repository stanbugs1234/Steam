import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/widgets/error_state.dart';
import '../../events/domain/event_providers.dart';

const checkInQrPrefix = 'steamclub:checkin:';

class CheckInQrScreen extends ConsumerWidget {
  const CheckInQrScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Check-In QR')),
      body: eventsAsync.when(
        data: (events) {
          final event = events.firstWhereOrNull((e) => e.id == eventId);
          if (event == null) {
            return const Center(child: Text('Event not found.'));
          }
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(data: '$checkInQrPrefix${event.id}', size: 260),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Have members open Check In from the home screen and scan this code.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${event.checkedInUserIds.length} checked in so far',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load this event.", error: err, onRetry: () => ref.invalidate(eventsProvider)),
      ),
    );
  }
}
