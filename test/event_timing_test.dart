import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/events/domain/event_timing.dart';
import 'package:steam_app/models/club_event.dart';

ClubEvent _event(DateTime start, DateTime end) => ClubEvent(
  id: 'e',
  title: 'Meeting',
  description: '',
  location: '',
  startTime: start,
  endTime: end,
  needsVolunteers: false,
  createdBy: 'u',
);

void main() {
  final now = DateTime(2026, 9, 20, 14, 30);

  group('dayTiming', () {
    test('compares calendar dates, not times', () {
      expect(dayTiming(DateTime(2026, 9, 20, 0, 1), now), DayTiming.today);
      expect(dayTiming(DateTime(2026, 9, 20, 23, 59), now), DayTiming.today);
      expect(dayTiming(DateTime(2026, 9, 19, 23, 59), now), DayTiming.past);
      expect(dayTiming(DateTime(2026, 9, 21), now), DayTiming.future);
    });

    test('matches the UTC-normalized days TableCalendar passes in', () {
      expect(dayTiming(DateTime.utc(2026, 9, 20), now), DayTiming.today);
      expect(dayTiming(DateTime.utc(2026, 9, 19), now), DayTiming.past);
      expect(dayTiming(DateTime.utc(2026, 9, 21), now), DayTiming.future);
    });

    test('turns over at midnight', () {
      expect(dayTiming(DateTime(2026, 9, 20), DateTime(2026, 9, 20, 23, 59, 59)), DayTiming.today);
      expect(dayTiming(DateTime(2026, 9, 20), DateTime(2026, 9, 21, 0, 0, 1)), DayTiming.past);
    });
  });

  group('eventTiming', () {
    final start = DateTime(2026, 9, 20, 14);
    final end = DateTime(2026, 9, 20, 16);
    final event = _event(start, end);

    test('upcoming before it starts', () {
      expect(eventTiming(event, start.subtract(const Duration(minutes: 1))), EventTiming.upcoming);
    });

    test('live from the moment it starts until it ends', () {
      expect(eventTiming(event, start), EventTiming.live);
      expect(eventTiming(event, end.subtract(const Duration(minutes: 1))), EventTiming.live);
    });

    test('past once it has ended', () {
      expect(eventTiming(event, end), EventTiming.past);
      expect(eventTiming(event, end.add(const Duration(days: 3))), EventTiming.past);
    });
  });

  group('dayRelativeLabel / dayHeading', () {
    test('names the days around today', () {
      expect(dayRelativeLabel(DateTime(2026, 9, 20), now), 'Today');
      expect(dayRelativeLabel(DateTime(2026, 9, 19), now), 'Yesterday');
      expect(dayRelativeLabel(DateTime(2026, 9, 21), now), 'Tomorrow');
    });

    test('counts days further out', () {
      expect(dayRelativeLabel(DateTime(2026, 9, 18), now), '2 days ago');
      expect(dayRelativeLabel(DateTime(2026, 9, 25), now), 'in 5 days');
    });

    test('heading leads with the relative word when it is today, yesterday or tomorrow', () {
      expect(dayHeading(DateTime(2026, 9, 20), now), 'Today · Sun, Sep 20');
      expect(dayHeading(DateTime(2026, 9, 19), now), 'Yesterday · Sat, Sep 19');
      expect(dayHeading(DateTime(2026, 9, 21), now), 'Tomorrow · Mon, Sep 21');
    });

    test('heading leads with the date when it is further away', () {
      expect(dayHeading(DateTime(2026, 9, 18), now), 'Fri, Sep 18 · 2 days ago');
      expect(dayHeading(DateTime(2026, 9, 25), now), 'Fri, Sep 25 · in 5 days');
    });
  });
}
