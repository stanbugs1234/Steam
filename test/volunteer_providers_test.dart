import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/volunteering/data/volunteer_repository.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/volunteer_slot.dart';

class _NoFirestore extends Fake implements FirebaseFirestore {}

/// Counts how many times each event's slots are read from "Firestore".
class _CountingRepo extends VolunteerRepository {
  _CountingRepo(this.slots) : super(_NoFirestore());

  final Map<String, List<VolunteerSlot>> slots;
  int reads = 0;

  @override
  Future<List<VolunteerSlot>> getSlotsOnce(String eventId) async {
    reads++;
    return slots[eventId] ?? const [];
  }
}

ClubEvent _event(String id, {required DateTime start, Duration length = const Duration(hours: 2), String title = 'Event'}) =>
    ClubEvent(
      id: id,
      title: title,
      description: '',
      location: '',
      startTime: start,
      endTime: start.add(length),
      needsVolunteers: true,
      createdBy: 'admin',
    );

void main() {
  late StreamController<List<ClubEvent>> events;
  late _CountingRepo repo;
  late ProviderContainer container;

  final past = _event('past', start: DateTime.now().subtract(const Duration(days: 3)));
  final upcoming = _event('soon', start: DateTime.now().add(const Duration(days: 3)));

  setUp(() {
    events = StreamController<List<ClubEvent>>();
    repo = _CountingRepo({
      'past': [
        const VolunteerSlot(id: 's1', label: 'Setup', capacity: 3, signedUpUserIds: ['a', 'b']),
        const VolunteerSlot(id: 's2', label: 'Cleanup', capacity: 3, signedUpUserIds: ['a']),
      ],
    });
    container = ProviderContainer(overrides: [
      eventsProvider.overrideWith((ref) => events.stream),
      volunteerRepositoryProvider.overrideWithValue(repo),
    ]);
    container.listen(pastVolunteerEventsProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    events.close();
  });

  test('reads past events\' slots once and credits each member once per event', () async {
    events.add([past, upcoming]);
    final hours = await container.read(volunteerHoursProvider.future);

    expect(repo.reads, 1, reason: 'only the past event needs its slots read');
    expect(hours['a'], 2.0, reason: 'in two slots of one 2h event, but counted once');
    expect(hours['b'], 2.0);
  });

  test('an unrelated events update does not re-read every past event', () async {
    events.add([past, upcoming]);
    await container.read(pastVolunteerEventsProvider.future);
    expect(repo.reads, 1);

    // An admin edits an *upcoming* event (or a check-in touches one): the set
    // of past events is unchanged, so nothing should be re-fetched.
    events.add([past, _event('soon', start: upcoming.startTime, title: 'Renamed')]);
    await pumpEventQueue();
    await container.read(pastVolunteerEventsProvider.future);
    expect(repo.reads, 1);
  });

  test('correcting a past event\'s times does re-read and update hours', () async {
    events.add([past]);
    expect((await container.read(volunteerHoursProvider.future))['a'], 2.0);

    events.add([_event('past', start: past.startTime, length: const Duration(hours: 4))]);
    await pumpEventQueue();
    expect((await container.read(volunteerHoursProvider.future))['a'], 4.0);
    expect(repo.reads, 2);
  });
}
