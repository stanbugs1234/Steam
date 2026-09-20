import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/notifications/data/reminder_service.dart';

void main() {
  group('stableNotificationId', () {
    test('same inputs produce the same id', () {
      expect(stableNotificationId('event1', 'slotA'), stableNotificationId('event1', 'slotA'));
    });

    test('different inputs produce different ids', () {
      expect(stableNotificationId('event1', 'slotA'), isNot(stableNotificationId('event1', 'slotB')));
      expect(stableNotificationId('event1', 'slotA'), isNot(stableNotificationId('event2', 'slotA')));
    });

    test('always returns a non-negative 32-bit id', () {
      final id = stableNotificationId('some-long-event-id-123', 'some-slot-id-456');
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThan(1 << 31));
    });
  });

  group('reminderFireTime', () {
    test('returns 24 hours before the event by default', () {
      final eventStart = DateTime.now().add(const Duration(days: 3));
      final fireTime = reminderFireTime(eventStart);
      expect(fireTime, eventStart.subtract(const Duration(hours: 24)));
    });

    test('returns null when the lead time has already passed', () {
      final eventStart = DateTime.now().add(const Duration(hours: 2));
      expect(reminderFireTime(eventStart), isNull);
    });

    test('respects a custom lead duration', () {
      final eventStart = DateTime.now().add(const Duration(hours: 3));
      final fireTime = reminderFireTime(eventStart, lead: const Duration(hours: 1));
      expect(fireTime, eventStart.subtract(const Duration(hours: 1)));
    });
  });

  group('staleReminderIds', () {
    test('cancels scheduled reminders nothing wants any more', () {
      expect(staleReminderIds(pending: [1, 2, 3], desired: [2]), {1, 3});
    });

    test('keeps every reminder that is still wanted', () {
      expect(staleReminderIds(pending: [1, 2], desired: [1, 2, 9]), isEmpty);
    });

    test('with reminders switched off (nothing wanted) cancels them all', () {
      expect(staleReminderIds(pending: [4, 5], desired: const []), {4, 5});
    });

    test('a target maps to the same id used to schedule and cancel it', () {
      final target = ReminderTarget(
        eventId: 'e1',
        slotId: 's1',
        eventTitle: 'Meeting',
        slotLabel: 'Setup',
        eventStart: DateTime.now().add(const Duration(days: 3)),
      );
      expect(target.id, stableNotificationId('e1', 's1'));
    });
  });
}
