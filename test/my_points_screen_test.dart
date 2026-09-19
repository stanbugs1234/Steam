import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/attendance/domain/attendance_providers.dart';
import 'package:steam_app/features/attendance/presentation/my_points_screen.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/attendance_record.dart';
import 'package:steam_app/models/club_event.dart';

Widget _app({required PointsSummary points, required List<VolunteerRecord> volunteer}) {
  return ProviderScope(
    overrides: [
      myPointsSummaryProvider.overrideWithValue(points),
      myVolunteerRecordProvider.overrideWithValue(AsyncValue.data(volunteer)),
    ],
    child: const MaterialApp(home: MyPointsScreen()),
  );
}

ClubEvent _event(String title, DateTime start) => ClubEvent(
      id: title,
      title: title,
      description: '',
      location: '',
      startTime: start,
      endTime: start.add(const Duration(hours: 2, minutes: 30)),
      needsVolunteers: true,
      createdBy: 'u',
    );

void main() {
  test('PointsSummary adds roster points to check-in points', () {
    final summary = PointsSummary(
      rosterPoints: 10,
      checkIns: [
        AttendanceRecord(eventId: 'a', eventTitle: 'A', eventStartTime: DateTime(2026, 9, 18), points: 1),
        AttendanceRecord(eventId: 'b', eventTitle: 'B', eventStartTime: DateTime(2026, 9, 25), points: 1),
      ],
    );
    expect(summary.checkInPoints, 2);
    expect(summary.total, 12);
  });

  testWidgets('lists each check-in with its date, the roster line, and the volunteer record', (tester) async {
    await tester.pumpWidget(_app(
      points: PointsSummary(
        rosterPoints: 5,
        checkIns: [
          AttendanceRecord(
            eventId: 'm1',
            eventTitle: 'September Meeting',
            eventStartTime: DateTime(2026, 9, 18, 19),
            points: 1,
          ),
        ],
      ),
      volunteer: [
        VolunteerRecord(event: _event('Fish Fry', DateTime(2026, 9, 12, 16)), slotLabels: const ['Kitchen'], hours: 2.5),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('6'), findsOneWidget);
    expect(find.text('September Meeting'), findsOneWidget);
    expect(find.text('Attended meeting · Fri, Sep 18, 2026'), findsOneWidget);
    expect(find.text('+1 pt'), findsOneWidget);
    expect(find.text('Club roster'), findsOneWidget);
    expect(find.text('+5 pts'), findsOneWidget);
    expect(find.text('Fish Fry'), findsOneWidget);
    expect(find.text('Sat, Sep 12, 2026 · Kitchen'), findsOneWidget);
    expect(find.text('2.5 hrs'), findsWidgets);
  });

  testWidgets('shows friendly empty states with no points or volunteering', (tester) async {
    await tester.pumpWidget(_app(points: const PointsSummary(rosterPoints: 0, checkIns: []), volunteer: const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('No points yet'), findsOneWidget);
    expect(find.textContaining('No volunteer shifts yet'), findsOneWidget);
  });
}
