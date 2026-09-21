import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import 'volunteer_providers.dart';

/// How many "seen" event ids are remembered per member. Old ones fall off the
/// front, so the list can't grow without bound.
const _maxSeen = 200;

String _seenKey(String uid) => 'seenVolunteerEvents:$uid';

/// The volunteer events this member has already opened, remembered on this
/// device (per member, so two accounts on one phone don't share it). Drives the
/// Home "Volunteer" badge: an opportunity stops counting once it's been looked
/// at. Empty while signed out.
final seenVolunteerEventsProvider = AsyncNotifierProvider<SeenVolunteerEvents, Set<String>>(SeenVolunteerEvents.new);

class SeenVolunteerEvents extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const {};
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_seenKey(uid))?.toSet() ?? {};
    } catch (_) {
      // Storage unavailable: behave as "nothing seen yet" rather than failing.
      return {};
    }
  }

  Future<void> markSeen(String eventId) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final Set<String> current;
    try {
      current = await future;
    } catch (_) {
      return;
    }
    // The account may have switched while the stored set was loading.
    if (current.contains(eventId) || ref.read(currentUidProvider) != uid) return;

    final ids = [...current, eventId];
    final trimmed = ids.length > _maxSeen ? ids.sublist(ids.length - _maxSeen) : ids;
    state = AsyncData(trimmed.toSet());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey(uid), trimmed);
    } catch (_) {
      // Best-effort: the badge still clears for this session.
    }
  }
}

/// The volunteer opportunities that are new to this member: upcoming events that
/// need volunteers, have a spot left, that they haven't opened, aren't signed up
/// for and didn't create themselves. The Volunteer tab tags these "NEW" and the
/// Home page's Volunteer shortcut counts them. Empty until everything it depends
/// on has loaded, so nothing flashes a wrong tag or number.
final newVolunteerEventIdsProvider = Provider<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final events = ref.watch(eventsProvider).valueOrNull;
  final seen = ref.watch(seenVolunteerEventsProvider).valueOrNull;
  final commitments = ref.watch(myCommitmentsProvider).valueOrNull;
  if (uid == null || events == null || seen == null || commitments == null) return const {};

  final mine = {for (final c in commitments) c.event.id};
  final now = DateTime.now();
  final ids = <String>{};
  for (final event in events) {
    if (!event.needsVolunteers || !event.endTime.isAfter(now)) continue;
    if (event.createdBy == uid || seen.contains(event.id) || mine.contains(event.id)) continue;
    final slots = ref.watch(eventSlotsProvider(event.id)).valueOrNull;
    if (slots != null && slots.any((s) => !s.isFull)) ids.add(event.id);
  }
  return ids;
});

/// How many opportunities are new: the number on the Home page's Volunteer shortcut.
final newVolunteerOpportunitiesProvider = Provider<int>((ref) => ref.watch(newVolunteerEventIdsProvider).length);
