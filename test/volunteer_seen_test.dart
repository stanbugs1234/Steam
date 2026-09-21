import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_seen.dart';
import 'package:steam_app/features/volunteering/presentation/volunteer_slot_section.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/volunteer_slot.dart';

AppUser _member(String uid) => AppUser(
      uid: uid,
      name: 'Member $uid',
      email: '',
      phone: '',
      kids: const [],
      role: UserRole.member,
      status: UserStatus.approved,
    );

ClubEvent _event(
  String id, {
  Duration startsIn = const Duration(days: 2),
  bool needsVolunteers = true,
  String createdBy = 'admin',
}) {
  final start = DateTime.now().add(startsIn);
  return ClubEvent(
    id: id,
    title: 'Event $id',
    description: '',
    location: '',
    startTime: start,
    endTime: start.add(const Duration(hours: 2)),
    needsVolunteers: needsVolunteers,
    createdBy: createdBy,
  );
}

const _open = [VolunteerSlot(id: 's', label: 'Setup', capacity: 3, signedUpUserIds: ['x'])];
const _full = [VolunteerSlot(id: 's', label: 'Setup', capacity: 1, signedUpUserIds: ['x'])];

/// Lets the streams and the stored "seen" set deliver their first values.
Future<void> _settle(ProviderContainer c) async {
  await c.read(seenVolunteerEventsProvider.future);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late StreamController<List<ClubEvent>> events;
  late StreamController<void> slotsChanged;
  late Map<String, List<VolunteerSlot>> slots;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    events = StreamController<List<ClubEvent>>.broadcast();
    slotsChanged = StreamController<void>.broadcast();
    slots = {};
  });

  tearDown(() {
    events.close();
    slotsChanged.close();
  });

  ProviderContainer makeContainer({String uid = 'me'}) {
    final container = ProviderContainer(overrides: [
      currentUidProvider.overrideWithValue(uid),
      currentAppUserProvider.overrideWith((ref) => Stream.value(_member(uid))),
      eventsProvider.overrideWith((ref) => events.stream),
      eventSlotsProvider.overrideWith((ref, id) async* {
        yield slots[id] ?? const [];
        yield* slotsChanged.stream.map((_) => slots[id] ?? const <VolunteerSlot>[]);
      }),
    ]);
    addTearDown(container.dispose);
    // Keep the derived providers alive so they recompute as their inputs arrive.
    container.listen(newVolunteerOpportunitiesProvider, (_, _) {});
    return container;
  }

  Future<int> count(ProviderContainer c, List<ClubEvent> list) async {
    events.add(list);
    await _settle(c);
    return c.read(newVolunteerOpportunitiesProvider);
  }

  test('counts upcoming volunteer events that have a spot left', () async {
    slots = {'a': _open, 'b': _open, 'c': _open};
    final c = makeContainer();
    expect(await count(c, [_event('a'), _event('b'), _event('c')]), 3);
  });

  test('opening an event takes it off the count, and that survives a restart', () async {
    slots = {'a': _open, 'b': _open};
    final c = makeContainer();
    expect(await count(c, [_event('a'), _event('b')]), 2);

    await c.read(seenVolunteerEventsProvider.notifier).markSeen('a');
    await _settle(c);
    expect(c.read(newVolunteerOpportunitiesProvider), 1);

    // A fresh container (a relaunch) reads the same stored set.
    final relaunched = makeContainer();
    expect(await count(relaunched, [_event('a'), _event('b')]), 1);
  });

  test('a new opportunity after some were seen raises the count again', () async {
    slots = {'a': _open, 'b': _open};
    final c = makeContainer();
    await count(c, [_event('a'), _event('b')]);
    await c.read(seenVolunteerEventsProvider.notifier).markSeen('a');
    await c.read(seenVolunteerEventsProvider.notifier).markSeen('b');
    await _settle(c);
    expect(c.read(newVolunteerOpportunitiesProvider), 0);

    slots['new'] = _open;
    slotsChanged.add(null);
    expect(await count(c, [_event('a'), _event('b'), _event('new')]), 1);
  });

  test('an event I am signed up for does not count', () async {
    slots = {
      'a': [const VolunteerSlot(id: 's', label: 'Setup', capacity: 3, signedUpUserIds: ['me'])],
      'b': _open,
    };
    final c = makeContainer();
    expect(await count(c, [_event('a'), _event('b')]), 1);
  });

  test('full events and events with no slots yet do not count until a spot exists', () async {
    slots = {'full': _full};
    final c = makeContainer();
    expect(await count(c, [_event('full'), _event('empty')]), 0);

    slots['empty'] = _open;
    slotsChanged.add(null);
    expect(await count(c, [_event('full'), _event('empty')]), 1);
  });

  test('past events, non-volunteer events and my own events do not count', () async {
    slots = {'past': _open, 'plain': _open, 'mine': _open, 'ok': _open};
    final c = makeContainer();
    final list = [
      _event('past', startsIn: const Duration(days: -3)),
      _event('plain', needsVolunteers: false),
      _event('mine', createdBy: 'me'),
      _event('ok'),
    ];
    expect(await count(c, list), 1);
  });

  test('each member has their own seen set', () async {
    slots = {'a': _open};
    final mine = makeContainer();
    await count(mine, [_event('a')]);
    await mine.read(seenVolunteerEventsProvider.notifier).markSeen('a');
    await _settle(mine);
    expect(mine.read(newVolunteerOpportunitiesProvider), 0);

    final other = makeContainer(uid: 'someone-else');
    expect(await count(other, [_event('a')]), 1);
  });

  test('is zero until the events have loaded', () async {
    slots = {'a': _open};
    final c = makeContainer();
    await _settle(c);
    expect(c.read(newVolunteerOpportunitiesProvider), 0);
  });

  test('only remembers the most recent 200 events', () async {
    final c = makeContainer();
    await _settle(c);
    final seen = c.read(seenVolunteerEventsProvider.notifier);
    for (var i = 0; i < 205; i++) {
      await seen.markSeen('e$i');
    }
    final stored = c.read(seenVolunteerEventsProvider).value!;
    expect(stored.length, 200);
    expect(stored.contains('e0'), isFalse);
    expect(stored.contains('e204'), isTrue);
  });

  testWidgets('opening an event\'s volunteer slots marks it seen', (tester) async {
    final event = _event('e1');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('me'),
        currentAppUserProvider.overrideWith((ref) => Stream.value(_member('me'))),
        eventSlotsProvider.overrideWith((ref, id) => Stream.value(_open)),
        approvedMembersProvider.overrideWith((ref) => Stream.value([_member('me')])),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: VolunteerSlotSection(event: event))),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(find.byType(VolunteerSlotSection)));
    expect(container.read(seenVolunteerEventsProvider).value, contains('e1'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('seenVolunteerEvents:me'), ['e1']);
  });
}
