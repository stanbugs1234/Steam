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
}
