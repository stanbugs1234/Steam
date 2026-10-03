import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/dashboard/domain/dashboard_providers.dart';
import 'package:steam_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:steam_app/features/directory/domain/directory_providers.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/club_event.dart';

AppUser _member(
  String uid, {
  String name = 'Member',
  bool duesPaid = false,
  int? yearlyPoints,
  DateTime? createdAt,
}) =>
    AppUser(
      uid: uid,
      name: name,
      email: '',
      phone: '',
      kids: const [],
      role: UserRole.member,
      status: UserStatus.approved,
      duesPaid: duesPaid,
      yearlyPoints: yearlyPoints,
      createdAt: createdAt,
    );

ClubEvent _event(String id, {required DateTime start}) => ClubEvent(
      id: id,
      title: 'Event $id',
      description: '',
      location: '',
      startTime: start,
      endTime: start.add(const Duration(hours: 2)),
      needsVolunteers: false,
      createdBy: 'admin',
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('clubTotalsProvider', () {
    test('counts members, dues paid, upcoming events, and total volunteer hours', () async {
      final now = DateTime.now();
      final container = ProviderContainer(overrides: [
        approvedMembersProvider.overrideWith((ref) => Stream.value([
              _member('a', duesPaid: true),
              _member('b', duesPaid: true),
              _member('c', duesPaid: false),
            ])),
        eventsProvider.overrideWith((ref) => Stream.value([
              _event('past', start: now.subtract(const Duration(days: 1))),
              _event('soon', start: now.add(const Duration(days: 1))),
              _event('later', start: now.add(const Duration(days: 5))),
            ])),
        volunteerHoursProvider.overrideWith((ref) async => {'a': 3.0, 'b': 1.5}),
      ]);
      addTearDown(container.dispose);

      // Let each stream/future deliver its first value before reading the
      // provider derived from them.
      await container.read(approvedMembersProvider.future);
      await container.read(eventsProvider.future);
      await container.read(volunteerHoursProvider.future);

      final totals = container.read(clubTotalsProvider);
      expect(totals.memberCount, 3);
      expect(totals.duesPaidCount, 2);
      expect(totals.upcomingEventCount, 2);
      expect(totals.volunteerHours, 4.5);
    });

    test('is all zero before anything has loaded', () {
      final container = ProviderContainer(overrides: [
        approvedMembersProvider.overrideWith((ref) => const Stream.empty()),
        eventsProvider.overrideWith((ref) => const Stream.empty()),
        volunteerHoursProvider.overrideWith((ref) async => const {}),
      ]);
      addTearDown(container.dispose);

      final totals = container.read(clubTotalsProvider);
      expect(totals.memberCount, 0);
      expect(totals.duesPaidCount, 0);
      expect(totals.upcomingEventCount, 0);
      expect(totals.volunteerHours, 0);
    });
  });

  group('pointsLeaderboardProvider', () {
    test('ranks members with points highest first and drops members with none', () async {
      final container = ProviderContainer(overrides: [
        approvedMembersProvider.overrideWith((ref) => Stream.value([
              _member('a', name: 'Ada', yearlyPoints: 5),
              _member('b', name: 'Bo', yearlyPoints: 12),
              _member('c', name: 'Cy', yearlyPoints: 0),
              _member('d', name: 'Dee'),
            ])),
      ]);
      addTearDown(container.dispose);
      await container.read(approvedMembersProvider.future);

      final entries = container.read(pointsLeaderboardProvider);
      expect(entries.map((e) => e.member.name), ['Bo', 'Ada']);
      expect(entries.map((e) => e.value), [12.0, 5.0]);
    });
  });

  group('newMembersByMonthProvider', () {
    /// A date `monthsAgo` months before now, on the 1st (avoids day-of-month
    /// edge cases when subtracting months near month boundaries).
    DateTime monthsAgo(int monthsAgo) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - monthsAgo, 1);
    }

    test('buckets the last 6 months (this one included), oldest first, and drops no-date members', () async {
      final container = ProviderContainer(overrides: [
        approvedMembersProvider.overrideWith((ref) => Stream.value([
              _member('a', createdAt: monthsAgo(7)), // outside the 6-month window
              _member('b', createdAt: monthsAgo(3)),
              _member('c', createdAt: monthsAgo(0)),
              _member('d', createdAt: monthsAgo(0)),
              _member('e'), // no createdAt: shouldn't count anywhere
            ])),
      ]);
      addTearDown(container.dispose);
      await container.read(approvedMembersProvider.future);

      final months = container.read(newMembersByMonthProvider);
      expect(months.length, 6);
      // Oldest first: index 0 is 5 months ago, index 5 is this month.
      expect(months.map((m) => m.month), [for (var i = 5; i >= 0; i--) monthsAgo(i)]);
      expect(months[2].count, 1, reason: '3 months ago has member b');
      expect(months.last.count, 2, reason: 'this month has members c and d');
      expect(months.fold<int>(0, (sum, m) => sum + m.count), 3, reason: 'the 7-months-ago and no-date members are excluded');
    });

    test('is all zero before members have loaded', () {
      final container = ProviderContainer(overrides: [
        approvedMembersProvider.overrideWith((ref) => const Stream.empty()),
      ]);
      addTearDown(container.dispose);

      final months = container.read(newMembersByMonthProvider);
      expect(months.length, 6);
      expect(months.every((m) => m.count == 0), isTrue);
    });
  });

  group('DashboardScreen', () {
    List<Override> defaultOverrides() => [
          approvedMembersProvider.overrideWith((ref) => Stream.value([
                _member('a', name: 'Ada', duesPaid: true, yearlyPoints: 10, createdAt: DateTime.now()),
                _member('b', name: 'Bo', yearlyPoints: 4),
              ])),
          eventsProvider.overrideWith((ref) => Stream.value(const [])),
          volunteerHoursProvider.overrideWith((ref) async => {'a': 6.0, 'b': 2.0}),
        ];

    Widget wrap({double textScale = 1.0, void Function(int)? onNavigateToTab}) => ProviderScope(
          overrides: defaultOverrides(),
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: DashboardScreen(onNavigateToTab: onNavigateToTab ?? (_) {}),
            ),
          ),
        );

    testWidgets('shows totals, both leaderboards ranked, and the growth row', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(wrap());
      await tester.pump();
      await tester.pump();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // member count
      expect(find.text('Membership Growth'), findsOneWidget);
      expect(find.text('Volunteer Leaderboard'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Points Leaderboard'), 300);
      expect(find.text('Points Leaderboard'), findsOneWidget);
      // Both members rank in the top 3 of both 2-entry leaderboards, so each
      // gets the trophy treatment: 2 members x 2 leaderboards.
      expect(find.byIcon(Icons.emoji_events), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out at 3x text scale without overflowing', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(wrap(textScale: 3.0));
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Points Leaderboard'), 300);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Members resets directory filters and switches to the Directory tab', (tester) async {
      _tallScreen(tester);
      final container = ProviderContainer(overrides: defaultOverrides());
      addTearDown(container.dispose);
      container.read(directoryGradeFilterProvider.notifier).state = 'Kindergarten';
      container.read(directoryDuesFilterProvider.notifier).state = DuesFilter.unpaidOnly;
      int? tappedIndex;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: DashboardScreen(onNavigateToTab: (i) => tappedIndex = i)),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Members'));
      await tester.pump();

      expect(tappedIndex, 4);
      expect(container.read(directoryGradeFilterProvider), isNull);
      expect(container.read(directoryDuesFilterProvider), DuesFilter.any);
    });

    testWidgets('tapping Dues Paid filters the directory to paid members and switches tabs', (tester) async {
      _tallScreen(tester);
      final container = ProviderContainer(overrides: defaultOverrides());
      addTearDown(container.dispose);
      int? tappedIndex;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: DashboardScreen(onNavigateToTab: (i) => tappedIndex = i)),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Dues Paid'));
      await tester.pump();

      expect(tappedIndex, 4);
      expect(container.read(directoryDuesFilterProvider), DuesFilter.paidOnly);
    });

    testWidgets('tapping Upcoming Events bumps the jump trigger and switches to the Events tab', (tester) async {
      _tallScreen(tester);
      final container = ProviderContainer(overrides: defaultOverrides());
      addTearDown(container.dispose);
      int? tappedIndex;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: DashboardScreen(onNavigateToTab: (i) => tappedIndex = i)),
      ));
      await tester.pump();
      await tester.pump();

      final before = container.read(eventsJumpToUpcomingProvider);
      await tester.tap(find.text('Upcoming Events'));
      await tester.pump();

      expect(tappedIndex, 2);
      expect(container.read(eventsJumpToUpcomingProvider), before + 1);
    });

    testWidgets('tapping Volunteer Hours scrolls to the Volunteer Leaderboard without switching tabs',
        (tester) async {
      _tallScreen(tester);
      int? tappedIndex;
      await tester.pumpWidget(wrap(onNavigateToTab: (i) => tappedIndex = i));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Volunteer Hours'));
      await tester.pumpAndSettle();

      expect(tappedIndex, isNull);
      expect(find.text('Volunteer Leaderboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
