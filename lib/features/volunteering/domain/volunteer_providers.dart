import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/club_event.dart';
import '../../../models/volunteer_slot.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../data/volunteer_repository.dart';

final volunteerRepositoryProvider = Provider<VolunteerRepository>((ref) {
  return VolunteerRepository(ref.watch(firestoreProvider));
});

final eventSlotsProvider = StreamProvider.family<List<VolunteerSlot>, String>((ref, eventId) {
  return ref.watch(volunteerRepositoryProvider).watchSlots(eventId);
});

class MyCommitment {
  final ClubEvent event;
  final VolunteerSlot slot;
  const MyCommitment({required this.event, required this.slot});
}

/// The signed-in member's volunteer sign-ups across all events, derived by
/// watching every volunteer-eligible event's slots and keeping the ones that
/// include their uid.
final myCommitmentsProvider = Provider<AsyncValue<List<MyCommitment>>>((ref) {
  final myUid = ref.watch(currentAppUserProvider).value?.uid;
  final eventsAsync = ref.watch(eventsProvider);

  return eventsAsync.when(
    data: (events) {
      final commitments = <MyCommitment>[];
      for (final event in events.where((e) => e.needsVolunteers)) {
        final slots = ref.watch(eventSlotsProvider(event.id)).value;
        if (slots == null || myUid == null) continue;
        for (final slot in slots) {
          if (slot.signedUpUserIds.contains(myUid)) {
            commitments.add(MyCommitment(event: event, slot: slot));
          }
        }
      }
      commitments.sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
      return AsyncValue.data(commitments);
    },
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
  );
});
