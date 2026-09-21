import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/core/theme/app_theme.dart';
import 'package:steam_app/core/widgets/capacity_bar.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/events/presentation/events_screen.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/volunteer_slot.dart';

/// "Now" for these tests: Sunday, Sep 20, 2026, noon.
DateTime _now = DateTime(2026, 9, 20, 12);

ClubEvent _event(String id, String title, DateTime start, DateTime end, {bool volunteers = false}) => ClubEvent(
  id: id,
  title: title,
  description: '',
  location: 'Parish Hall',
  startTime: start,
  endTime: end,
  needsVolunteers: volunteers,
  createdBy: 'u1',
);

final _past = _event('past', 'Past Meeting', DateTime(2026, 9, 18, 19), DateTime(2026, 9, 18, 21), volunteers: true);
final _live = _event('live', 'Live Meeting', DateTime(2026, 9, 20, 11), DateTime(2026, 9, 20, 13));
final _soon = _event('soon', 'Upcoming Dinner', DateTime(2026, 9, 22, 18), DateTime(2026, 9, 22, 20), volunteers: true);

final _user = AppUser(
  uid: 'u1',
  name: 'Pat',
  email: 'pat@example.com',
  phone: '+15045550001',
  kids: const [],
  role: UserRole.member,
  status: UserStatus.approved,
  createdAt: DateTime(2019, 3, 10),
);

Widget _app({List<MyCommitment> mine = const []}) {
  return ProviderScope(
    overrides: [
      currentAppUserProvider.overrideWith((ref) => Stream.value(_user)),
      eventsProvider.overrideWith((ref) => Stream.value([_past, _live, _soon])),
      myCommitmentsProvider.overrideWithValue(AsyncValue.data(mine)),
      eventVolunteerProgressProvider.overrideWith((ref, id) => const EventVolunteerProgress(filled: 1, capacity: 4)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: EventsScreen(clock: () => _now),
    ),
  );
}

Finder _day(int day) => find.byKey(ValueKey('day-2026-9-$day'));

Color _numberColor(WidgetTester tester, int day) {
  final text = tester.widget<Text>(find.descendant(of: _day(day), matching: find.byType(Text)));
  return text.style!.color!;
}

Future<void> _open(WidgetTester tester, {List<MyCommitment> mine = const []}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _now = DateTime(2026, 9, 20, 12);
  await tester.pumpWidget(_app(mine: mine));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('opens on today: heading says Today, today has a ring, live event is flagged', (tester) async {
    await _open(tester);

    expect(find.text('Today · Sun, Sep 20'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-ring')), findsOneWidget);
    expect(find.text('Happening now'), findsOneWidget);
    expect(find.text('Live Meeting'), findsOneWidget);
    // Nothing on the calendar tab is called "Past" today except the legend.
    expect(find.text('Past'), findsOneWidget);
  });

  testWidgets('today stays marked after picking another day', (tester) async {
    await _open(tester);

    await tester.tap(_day(22));
    await tester.pump();

    expect(find.text('Tue, Sep 22 · in 2 days'), findsOneWidget);
    // The ring moved off the selected day but is still on today.
    expect(find.descendant(of: _day(20), matching: find.byKey(const ValueKey('today-ring'))), findsOneWidget);
    expect(find.text('Upcoming Dinner'), findsOneWidget);
  });

  testWidgets('past days are muted and future days are not', (tester) async {
    await _open(tester);
    final colors = Theme.of(tester.element(find.byType(EventsScreen))).colorScheme;

    expect(_numberColor(tester, 18), mutedTextColor(colors));
    expect(_numberColor(tester, 24), colors.onSurface);

    // Today is selected on open (white on the accent); once another day is
    // picked, today's number turns accent-colored inside its ring.
    await tester.tap(_day(22));
    await tester.pump();
    expect(_numberColor(tester, 20), colors.primary);
    expect(_numberColor(tester, 22), colors.onPrimary);
  });

  testWidgets('a past day shows its event greyed out with a Past label and no capacity bar', (tester) async {
    await _open(tester);

    await tester.tap(_day(18));
    await tester.pump();

    expect(find.text('Fri, Sep 18 · 2 days ago'), findsOneWidget);
    expect(find.text('Past Meeting'), findsOneWidget);
    // Legend entry plus the card's chip.
    expect(find.text('Past'), findsNWidgets(2));
    expect(find.byType(CapacityBar), findsNothing);
    expect(find.text('Happening now'), findsNothing);
  });

  testWidgets('an upcoming volunteer event still shows its capacity bar', (tester) async {
    await _open(tester);

    await tester.tap(_day(22));
    await tester.pump();

    expect(find.byType(CapacityBar), findsOneWidget);
    expect(find.text('Past'), findsOneWidget); // legend only
  });

  testWidgets('a past event you signed up for says "You volunteered", not "signed up"', (tester) async {
    await _open(
      tester,
      mine: [
        MyCommitment(
          event: _past,
          slot: const VolunteerSlot(id: 's', label: 'Setup', capacity: 4, signedUpUserIds: ['u1']),
        ),
      ],
    );

    await tester.tap(_day(18));
    await tester.pump();

    expect(find.text('You volunteered'), findsOneWidget);
    expect(find.text("You're signed up"), findsNothing);
  });

  testWidgets('a future event you signed up for still says "signed up"', (tester) async {
    await _open(
      tester,
      mine: [
        MyCommitment(
          event: _soon,
          slot: const VolunteerSlot(id: 's', label: 'Setup', capacity: 4, signedUpUserIds: ['u1']),
        ),
      ],
    );

    await tester.tap(_day(22));
    await tester.pump();

    expect(find.text("You're signed up"), findsOneWidget);
    expect(find.text('You volunteered'), findsNothing);
  });

  testWidgets('the Today button appears off today and brings you back', (tester) async {
    await _open(tester);
    expect(find.widgetWithText(FilledButton, 'Today'), findsNothing);

    await tester.tap(_day(22));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Today'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Today'));
    await tester.pump();
    expect(find.text('Today · Sun, Sep 20'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Today'), findsNothing);
  });

  testWidgets('coming back the next day moves today forward if you were on today', (tester) async {
    await _open(tester);
    expect(find.text('Today · Sun, Sep 20'), findsOneWidget);

    _now = DateTime(2026, 9, 21, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Today · Mon, Sep 21'), findsOneWidget);
    expect(find.descendant(of: _day(21), matching: find.byKey(const ValueKey('today-ring'))), findsOneWidget);
  });

  testWidgets('coming back the next day does not yank away a day you picked', (tester) async {
    await _open(tester);
    await tester.tap(_day(22));
    await tester.pump();

    _now = DateTime(2026, 9, 21, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Tomorrow · Tue, Sep 22'), findsOneWidget);
    expect(find.descendant(of: _day(21), matching: find.byKey(const ValueKey('today-ring'))), findsOneWidget);
  });

  test('muted text keeps at least 3:1 contrast in light and dark themes', () {
    double contrast(Color a, Color b) {
      final l1 = a.computeLuminance(), l2 = b.computeLuminance();
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final colors = theme.colorScheme;
      final muted = Color.alphaBlend(mutedTextColor(colors), colors.surfaceContainerLow);
      expect(contrast(muted, colors.surfaceContainerLow), greaterThanOrEqualTo(3.0));
      // ...but is clearly quieter than normal text.
      expect(
        contrast(colors.onSurface, colors.surfaceContainerLow),
        greaterThan(contrast(muted, colors.surfaceContainerLow)),
      );
    }
  });
}
