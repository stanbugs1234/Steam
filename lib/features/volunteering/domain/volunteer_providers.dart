import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/app_user.dart';
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

class LeaderboardEntry {
  final AppUser member;
  final double hours;
  const LeaderboardEntry({required this.member, required this.hours});
}

/// Total volunteer hours per member, derived from every past event a member
/// signed up for. An event only counts once per member even if they signed
/// up for more than one of its slots.
final volunteerHoursProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  final eventsAsync = ref.watch(eventsProvider);
  final now = DateTime.now();

  return eventsAsync.when(
    data: (events) {
      final hoursByUid = <String, double>{};
      for (final event in events.where((e) => e.needsVolunteers && e.endTime.isBefore(now))) {
        final slots = ref.watch(eventSlotsProvider(event.id)).value;
        if (slots == null) continue;
        final signedUpUids = <String>{};
        for (final slot in slots) {
          signedUpUids.addAll(slot.signedUpUserIds);
        }
        final hours = event.endTime.difference(event.startTime).inMinutes / 60;
        for (final uid in signedUpUids) {
          hoursByUid[uid] = (hoursByUid[uid] ?? 0) + hours;
        }
      }
      return AsyncValue.data(hoursByUid);
    },
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
  );
});

/// All approved members with at least one volunteer hour, ranked highest
/// first.
final volunteerLeaderboardProvider = Provider<List<LeaderboardEntry>>((ref) {
  final hours = ref.watch(volunteerHoursProvider).value ?? const {};
  final members = ref.watch(approvedMembersProvider).value ?? const [];

  final entries = members
      .where((m) => (hours[m.uid] ?? 0) > 0)
      .map((m) => LeaderboardEntry(member: m, hours: hours[m.uid]!))
      .toList()
    ..sort((a, b) => b.hours.compareTo(a.hours));
  return entries;
});

/// The uids currently holding the top 3 leaderboard spots.
final topVolunteerUidsProvider = Provider<Set<String>>((ref) {
  return ref.watch(volunteerLeaderboardProvider).take(3).map((e) => e.member.uid).toSet();
});

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
