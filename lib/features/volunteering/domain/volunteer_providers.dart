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

class EventVolunteerProgress {
  final int filled;
  final int capacity;
  const EventVolunteerProgress({required this.filled, required this.capacity});
}

/// Aggregate spot counts across all of an event's volunteer slots, or null
/// if the event has no slots yet.
final eventVolunteerProgressProvider = Provider.family<EventVolunteerProgress?, String>((ref, eventId) {
  final slots = ref.watch(eventSlotsProvider(eventId)).value;
  if (slots == null || slots.isEmpty) return null;
  return EventVolunteerProgress(
    filled: slots.fold(0, (sum, s) => sum + s.signedUpUserIds.length),
    capacity: slots.fold(0, (sum, s) => sum + s.capacity),
  );
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

/// A volunteer-eligible event that has already ended, with its final slots.
class PastVolunteerEvent {
  final ClubEvent event;
  final List<VolunteerSlot> slots;
  const PastVolunteerEvent({required this.event, required this.slots});

  double get hours => event.endTime.difference(event.startTime).inMinutes / 60;
}

/// Every past volunteer-eligible event with its slots, loaded once.
///
/// Every event this looks at has already ended (its sign-up counts can't
/// change anymore), so this reads each one's slots once via [getSlotsOnce]
/// instead of opening a live listener per event — with a growing event
/// history, a live listener per past event forever is exactly the kind of
/// unbounded fan-out that made Home/Directory (which both depend on this,
/// via the leaderboard/top-volunteer badge) slow to load. Both the hours
/// totals and a member's own volunteer record derive from this one read.
final pastVolunteerEventsProvider = FutureProvider<List<PastVolunteerEvent>>((ref) async {
  final events = await ref.watch(eventsProvider.future);
  final repo = ref.watch(volunteerRepositoryProvider);
  final now = DateTime.now();

  final past = <PastVolunteerEvent>[];
  for (final event in events.where((e) => e.needsVolunteers && e.endTime.isBefore(now))) {
    past.add(PastVolunteerEvent(event: event, slots: await repo.getSlotsOnce(event.id)));
  }
  return past;
});

/// Total volunteer hours per member, derived from every past event a member
/// signed up for. An event only counts once per member even if they signed
/// up for more than one of its slots.
final volunteerHoursProvider = FutureProvider<Map<String, double>>((ref) async {
  final past = await ref.watch(pastVolunteerEventsProvider.future);

  final hoursByUid = <String, double>{};
  for (final entry in past) {
    final signedUpUids = <String>{};
    for (final slot in entry.slots) {
      signedUpUids.addAll(slot.signedUpUserIds);
    }
    for (final uid in signedUpUids) {
      hoursByUid[uid] = (hoursByUid[uid] ?? 0) + entry.hours;
    }
  }
  return hoursByUid;
});

/// One past event the signed-in member volunteered for.
class VolunteerRecord {
  final ClubEvent event;
  final List<String> slotLabels;
  final double hours;
  const VolunteerRecord({required this.event, required this.slotLabels, required this.hours});
}

/// The signed-in member's volunteer history — past events they were signed up
/// for, newest first. Hours match what [volunteerHoursProvider] counts (once
/// per event, however many of its slots they took).
final myVolunteerRecordProvider = Provider<AsyncValue<List<VolunteerRecord>>>((ref) {
  final myUid = ref.watch(currentAppUserProvider).value?.uid;
  return ref.watch(pastVolunteerEventsProvider).whenData((past) {
    if (myUid == null) return const <VolunteerRecord>[];
    final records = <VolunteerRecord>[];
    for (final entry in past) {
      final mine = entry.slots.where((s) => s.signedUpUserIds.contains(myUid)).toList();
      if (mine.isEmpty) continue;
      records.add(VolunteerRecord(
        event: entry.event,
        slotLabels: [for (final s in mine) s.label],
        hours: entry.hours,
      ));
    }
    records.sort((a, b) => b.event.startTime.compareTo(a.event.startTime));
    return records;
  });
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

/// The signed-in member's volunteer sign-ups for events that haven't
/// happened yet, derived by watching each such event's slots live and
/// keeping the ones that include their uid. Past commitments are excluded —
/// they can't be cancelled from here anyway (see `my_commitments_screen.dart`),
/// and excluding them keeps this bounded to the small, roughly-constant set
/// of upcoming events instead of the club's entire event history.
final myCommitmentsProvider = Provider<AsyncValue<List<MyCommitment>>>((ref) {
  final myUid = ref.watch(currentAppUserProvider).value?.uid;
  final eventsAsync = ref.watch(eventsProvider);
  final now = DateTime.now();

  return eventsAsync.when(
    data: (events) {
      final commitments = <MyCommitment>[];
      for (final event in events.where((e) => e.needsVolunteers && e.endTime.isAfter(now))) {
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
