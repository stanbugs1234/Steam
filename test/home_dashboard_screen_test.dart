import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:steam_app/features/attendance/domain/attendance_providers.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/home/presentation/home_dashboard_screen.dart';
import 'package:steam_app/features/news/domain/news_providers.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/club_event.dart';

/// Regression coverage for a real Crashlytics report: several of Home's
/// sections read a Firestore-backed provider with `.value`, which — unlike
/// `.valueOrNull` — rethrows the provider's error when it has never held data
/// (e.g. permission-denied on the very first read, right after sign-in
/// before Firestore's listener has settled). Any one of those providers
/// erroring on its first emission must degrade the section, not crash Home.
void main() {
  final admin = AppUser(
    uid: 'admin1',
    name: 'Ada',
    email: 'ada@example.com',
    phone: '',
    kids: const [],
    role: UserRole.admin,
    status: UserStatus.approved,
  );

  final event = ClubEvent(
    id: 'e1',
    title: 'Book Fair',
    description: '',
    location: '',
    startTime: DateTime.now().add(const Duration(days: 2)),
    endTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
    needsVolunteers: true,
    createdBy: 'admin1',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(List<Override> overrides) {
    return ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(admin)),
        currentUidProvider.overrideWithValue(admin.uid),
        myPointsSummaryProvider.overrideWithValue(const PointsSummary(rosterPoints: 0, checkIns: [])),
        ...overrides,
      ],
      child: MaterialApp(home: HomeDashboardScreen(onNavigateToTab: (_) {})),
    );
  }

  testWidgets('renders normally with real data', (tester) async {
    await tester.pumpWidget(wrap([
      eventsProvider.overrideWith((ref) => Stream.value([event])),
      newsFeedProvider.overrideWith((ref) => Stream.value(const [])),
      pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),
      eventSlotsProvider.overrideWith((ref, id) => Stream.value(const [])),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Book Fair'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an events read that errors on its first emission does not crash Home', (tester) async {
    await tester.pumpWidget(wrap([
      eventsProvider.overrideWith((ref) => Stream.error(Exception('permission-denied'))),
      newsFeedProvider.overrideWith((ref) => Stream.value(const [])),
      pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('No upcoming events right now.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a news feed that errors on its first emission does not crash Home', (tester) async {
    await tester.pumpWidget(wrap([
      eventsProvider.overrideWith((ref) => Stream.value(const [])),
      newsFeedProvider.overrideWith((ref) => Stream.error(Exception('permission-denied'))),
      pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Latest News'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an admin whose pending-approvals read errors does not crash Home', (tester) async {
    await tester.pumpWidget(wrap([
      eventsProvider.overrideWith((ref) => Stream.value(const [])),
      newsFeedProvider.overrideWith((ref) => Stream.value(const [])),
      pendingUsersProvider.overrideWith((ref) => Stream.error(Exception('permission-denied'))),
    ]));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a volunteer-slots read that errors does not crash the next event\'s capacity bar', (tester) async {
    await tester.pumpWidget(wrap([
      eventsProvider.overrideWith((ref) => Stream.value([event])),
      newsFeedProvider.overrideWith((ref) => Stream.value(const [])),
      pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),
      eventSlotsProvider.overrideWith((ref, id) => Stream.error(Exception('permission-denied'))),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Book Fair'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('myCommitmentsProvider in an error state does not crash Home', (tester) async {
    await tester.pumpWidget(wrap([
      eventsProvider.overrideWith((ref) => Stream.value([event])),
      newsFeedProvider.overrideWith((ref) => Stream.value(const [])),
      pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),
      eventSlotsProvider.overrideWith((ref, id) => Stream.value(const [])),
      myCommitmentsProvider.overrideWithValue(AsyncValue.error(Exception('permission-denied'), StackTrace.empty)),
    ]));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
