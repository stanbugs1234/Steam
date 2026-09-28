import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/notifications/data/reminder_service.dart';
import 'package:steam_app/features/notifications/domain/notification_providers.dart';
import 'package:steam_app/features/notifications/domain/reminder_sync.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/volunteer_slot.dart';

/// Lets every pending microtask (each stream's emission, and every provider
/// rebuild it triggers in turn) drain before assertions run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Records whatever `reminderSyncProvider` last asked to be synced, instead
/// of touching a real notifications plugin.
class _RecordingReminderService extends ReminderService {
  _RecordingReminderService() : super(FlutterLocalNotificationsPlugin());

  List<ReminderTarget>? lastTargets;

  @override
  Future<void> syncReminders(List<ReminderTarget> targets) async {
    lastTargets = targets;
  }
}

void main() {
  final approved = AppUser(
    uid: 'u1',
    name: 'Mia',
    email: 'mia@example.com',
    phone: '',
    kids: const [],
    role: UserRole.member,
    status: UserStatus.approved,
  );

  final eventWithShift = ClubEvent(
    id: 'e1',
    title: 'Book Fair',
    description: '',
    location: '',
    startTime: DateTime.now().add(const Duration(days: 2)),
    endTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
    needsVolunteers: true,
    createdBy: 'admin1',
  );

  final plainEvent = ClubEvent(
    id: 'e2',
    title: 'Movie Night',
    description: '',
    location: '',
    startTime: DateTime.now().add(const Duration(days: 3)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 2)),
    needsVolunteers: false,
    createdBy: 'admin1',
  );

  final pastEvent = ClubEvent(
    id: 'e3',
    title: 'Old Meeting',
    description: '',
    location: '',
    startTime: DateTime.now().subtract(const Duration(days: 3)),
    endTime: DateTime.now().subtract(const Duration(days: 3, hours: -1)),
    needsVolunteers: false,
    createdBy: 'admin1',
  );

  const slot = VolunteerSlot(id: 's1', label: 'Setup', capacity: 2, signedUpUserIds: ['u1']);

  late _RecordingReminderService recorder;
  ProviderContainer? container;

  setUp(() => recorder = _RecordingReminderService());
  tearDown(() => container?.dispose());

  ProviderContainer build({
    required AppUser user,
    required List<ClubEvent> events,
    required List<MyCommitment> commitments,
  }) {
    final c = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(user)),
        eventsProvider.overrideWith((ref) => Stream.value(events)),
        myCommitmentsProvider.overrideWithValue(AsyncValue.data(commitments)),
        reminderServiceProvider.overrideWithValue(recorder),
      ],
    );
    container = c;
    c.listen(reminderSyncProvider, (_, _) {});
    return c;
  }

  test(
    'a member volunteering for an event gets only the shift reminder, not a duplicate event reminder, '
    'while an unrelated upcoming event still gets its own',
    () async {
      build(
        user: approved,
        events: [eventWithShift, plainEvent, pastEvent],
        commitments: [MyCommitment(event: eventWithShift, slot: slot)],
      );
      await _settle();

      final targets = recorder.lastTargets;
      expect(targets, isNotNull);

      final shiftTarget = targets!.where((t) => t.eventId == 'e1');
      expect(shiftTarget, hasLength(1));
      expect(shiftTarget.single.slotId, 's1');

      final plainTarget = targets.where((t) => t.eventId == 'e2');
      expect(plainTarget, hasLength(1));
      expect(plainTarget.single.slotId, isNull);

      // A past event never gets a reminder.
      expect(targets.where((t) => t.eventId == 'e3'), isEmpty);
    },
  );

  test('reminders switched off produces no targets, even with upcoming events and a live commitment', () async {
    build(
      user: approved.copyWith(remindersEnabled: false),
      events: [eventWithShift, plainEvent],
      commitments: [MyCommitment(event: eventWithShift, slot: slot)],
    );
    await _settle();

    expect(recorder.lastTargets, isEmpty);
  });
}
