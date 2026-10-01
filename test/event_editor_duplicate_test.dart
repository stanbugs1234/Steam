import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/events/data/event_repository.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/events/presentation/event_editor_screen.dart';
import 'package:steam_app/features/volunteering/data/volunteer_repository.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/volunteer_slot.dart';

class _NoFirestore extends Fake implements FirebaseFirestore {}

class _RecordingEventRepository extends EventRepository {
  _RecordingEventRepository() : super(_NoFirestore());

  ClubEvent? savedEvent;
  List<VolunteerSlot>? savedSlots;
  VolunteerSlot? savedSlot;

  @override
  String newEventId() => 'new-event-id';

  @override
  Future<void> createEventWithSlots(ClubEvent event, List<VolunteerSlot> slots) async {
    savedEvent = event;
    savedSlots = slots;
  }

  @override
  Future<void> createEventWithSlot(ClubEvent event, VolunteerSlot slot) async {
    savedEvent = event;
    savedSlot = slot;
  }

  @override
  Future<void> createEvent(ClubEvent event) async => savedEvent = event;
}

class _StubVolunteerRepository extends VolunteerRepository {
  _StubVolunteerRepository() : super(_NoFirestore());

  int _n = 0;

  @override
  String newSlotId(String eventId) => 'new-slot-${_n++}';
}

final _admin = AppUser(
  uid: 'duplicating-admin-uid',
  name: 'Ada',
  email: 'ada@example.com',
  phone: '',
  kids: const [],
  role: UserRole.admin,
  status: UserStatus.approved,
);

final _source = ClubEvent(
  id: 'src1',
  title: 'Spring Cleanup',
  description: 'Bring gloves.',
  location: 'Parish Hall',
  startTime: DateTime(2026, 10, 10, 9),
  endTime: DateTime(2026, 10, 10, 11),
  needsVolunteers: true,
  checkInEnabled: true,
  createdBy: 'original-admin-uid',
);

void main() {
  late _RecordingEventRepository eventRepo;
  late _StubVolunteerRepository volunteerRepo;

  setUp(() {
    eventRepo = _RecordingEventRepository();
    volunteerRepo = _StubVolunteerRepository();
  });

  Widget wrap(List<VolunteerSlot> sourceSlots) {
    return ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(_admin)),
        eventsProvider.overrideWith((ref) => Stream.value([_source])),
        eventSlotsOnceProvider('src1').overrideWith((ref) => Future.value(sourceSlots)),
        eventRepositoryProvider.overrideWithValue(eventRepo),
        volunteerRepositoryProvider.overrideWithValue(volunteerRepo),
      ],
      // Mirrors production: by the time an admin reaches this screen,
      // currentAppUserProvider has long since resolved (it's kept warm
      // app-wide from sign-in). Watching it here gives it the same head
      // start, so _save()'s ref.read of it isn't racing its first emission.
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(currentAppUserProvider);
          return MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/events/src1/duplicate',
              routes: [
                GoRoute(
                  path: '/events/src1/duplicate',
                  builder: (context, state) => const EventEditorScreen(duplicateFromId: 'src1'),
                ),
                GoRoute(path: '/events/:id', builder: (context, state) => const Scaffold(body: Text('Detail'))),
              ],
            ),
          );
        },
      ),
    );
  }

  testWidgets('prefills from the source event with zero slots, as a create not an edit', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pump();
    await tester.pump();

    expect(find.text('Duplicate Event'), findsOneWidget);
    expect(find.text('Spring Cleanup'), findsOneWidget);
    expect(find.text('Parish Hall'), findsOneWidget);
    expect(find.text('Bring gloves.'), findsOneWidget);
    expect(find.text('Create Event'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('a single source slot prefills its capacity and keeps its own label on save', (tester) async {
    await tester.pumpWidget(wrap(const [
      VolunteerSlot(id: 's1', label: 'Setup Crew', capacity: 4, signedUpUserIds: ['u9']),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(TextFormField, '4'), findsOneWidget);

    await tester.ensureVisible(find.text('Create Event'));
    await tester.tap(find.text('Create Event'));
    await tester.pump();
    await tester.pump();

    expect(eventRepo.savedSlot?.label, 'Setup Crew');
    expect(eventRepo.savedSlot?.capacity, 4);
    expect(eventRepo.savedSlot?.signedUpUserIds, isEmpty);
    expect(eventRepo.savedSlot?.id, isNot('s1'));
  });

  testWidgets('multiple source slots show a copy notice and batch-create fresh slots on save', (tester) async {
    await tester.pumpWidget(wrap(const [
      VolunteerSlot(id: 's1', label: 'Setup', capacity: 3, signedUpUserIds: ['a', 'b']),
      VolunteerSlot(id: 's2', label: 'Cleanup', capacity: 2, signedUpUserIds: ['a']),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('will be copied over'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Volunteers needed'), findsNothing);

    await tester.ensureVisible(find.text('Create Event'));
    await tester.tap(find.text('Create Event'));
    await tester.pump();
    await tester.pump();

    final slots = eventRepo.savedSlots;
    expect(slots, isNotNull);
    expect(slots!.map((s) => s.label), ['Setup', 'Cleanup']);
    expect(slots.map((s) => s.capacity), [3, 2]);
    expect(slots.every((s) => s.signedUpUserIds.isEmpty), isTrue);
    expect(slots.map((s) => s.id).toSet().intersection({'s1', 's2'}), isEmpty);
  });

  testWidgets('never carries over the source id, author, or creation time', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Create Event'));
    await tester.tap(find.text('Create Event'));
    await tester.pump();
    await tester.pump();

    expect(eventRepo.savedEvent?.id, 'new-event-id');
    expect(eventRepo.savedEvent?.createdBy, 'duplicating-admin-uid');
    expect(eventRepo.savedEvent?.createdAt, isNull);
  });
}
