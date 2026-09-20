import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/core/utils/membership_duration.dart';
import 'package:steam_app/features/attendance/domain/attendance_providers.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/directory/domain/profile_draft.dart';
import 'package:steam_app/features/directory/presentation/edit_profile_screen.dart';
import 'package:steam_app/features/directory/presentation/my_profile_screen.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/attendance_record.dart';
import 'package:steam_app/models/child_info.dart';

AppUser _user({
  String name = 'Stan Bugusky',
  String phone = '+15045551234',
  List<ChildInfo> kids = const [ChildInfo(name: 'Sam', grade: '3rd Grade')],
  UserRole role = UserRole.member,
  bool duesPaid = true,
}) {
  return AppUser(
    uid: 'u1',
    name: name,
    email: 'stan@example.com',
    phone: phone,
    kids: kids,
    role: role,
    status: UserStatus.approved,
    createdAt: DateTime(2019, 3, 10),
    duesPaid: duesPaid,
    memberNumber: '1078',
    yearlyPoints: 4,
  );
}

Widget _app(AppUser user, Widget home) {
  return ProviderScope(
    overrides: [
      currentAppUserProvider.overrideWith((ref) => Stream.value(user)),
      myPointsSummaryProvider.overrideWithValue(PointsSummary(
        rosterPoints: 4,
        checkIns: [
          AttendanceRecord(eventId: 'm', eventTitle: 'Meeting', eventStartTime: DateTime(2026, 9, 18), points: 1),
        ],
      )),
      volunteerHoursProvider.overrideWith((ref) async => {'u1': 7.5}),
      topVolunteerUidsProvider.overrideWithValue(const {'u1'}),
      pendingUsersProvider.overrideWith((ref) => Stream.value([_user(name: 'Pending Person')])),
    ],
    child: MaterialApp(home: home),
  );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('formatMembershipDuration', () {
    final now = DateTime(2026, 9, 18);
    test('new, months, years', () {
      expect(formatMembershipDuration(DateTime(2026, 9, 1), now: now), 'New member');
      expect(formatMembershipDuration(DateTime(2026, 6, 10), now: now), '3 months');
      expect(formatMembershipDuration(DateTime(2025, 9, 18), now: now), '1 year');
      expect(formatMembershipDuration(DateTime(2024, 6, 1), now: now), '2 years 3 months');
    });
  });

  group('ProfileDraft', () {
    final original = ProfileDraft.fromUser(_user());

    test('formatting differences are not changes', () {
      final same = ProfileDraft.fromForm(
        name: '  Stan Bugusky ',
        phone: '(504) 555-1234',
        kids: const [ChildInfo(name: 'Sam', grade: '3rd Grade'), ChildInfo(name: '  ', grade: '1st Grade')],
      );
      expect(same.sameAs(original), isTrue);
      expect(same.changesFrom(original), isEmpty);
    });

    test('only changed fields are written', () {
      final edited = ProfileDraft.fromForm(name: 'Stan B', phone: '(504) 555-1234', kids: original.kids);
      expect(edited.changesFrom(original), {'name': 'Stan B'});

      final newPhone = ProfileDraft.fromForm(name: original.name, phone: '(504) 555-9999', kids: original.kids);
      expect(newPhone.changesFrom(original), {'phone': '5045559999'});

      final moreKids = ProfileDraft.fromForm(
        name: original.name,
        phone: '5045551234',
        kids: const [ChildInfo(name: 'Sam', grade: '3rd Grade'), ChildInfo(name: 'Ann', grade: '1st Grade')],
      );
      expect(moreKids.changesFrom(original)['kids'], hasLength(2));
    });

    test('validation', () {
      expect(ProfileDraft.validateName('  '), isNotNull);
      expect(ProfileDraft.validateName('Stan'), isNull);
      expect(ProfileDraft.validatePhone(''), isNull);
      expect(ProfileDraft.validatePhone('(504) 555-1234'), isNull);
      expect(ProfileDraft.validatePhone('(504) 7'), isNotNull);
    });
  });

  group('MyProfileScreen', () {
    testWidgets('shows identity, badges, standing, contact, family and membership', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_app(_user(role: UserRole.admin), const MyProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Stan Bugusky'), findsOneWidget);
      expect(find.text('Member since Mar 2019 · #1078'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Top Volunteer'), findsOneWidget);
      expect(find.text('Dues Paid'), findsOneWidget);

      expect(find.text('5'), findsOneWidget); // 4 roster + 1 check-in
      expect(find.text('7.5'), findsOneWidget);
      expect(find.text('Volunteer hrs'), findsOneWidget);

      expect(find.text('stan@example.com'), findsOneWidget);
      expect(find.text('(504) 555-1234'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('3rd Grade'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Sign Out'), 300);
      expect(find.text('Review pending approvals'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // pending badge / meeting count
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('a plain member has no admin row; empty phone and family prompt to add', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_app(_user(phone: '', kids: const [], duesPaid: false), const MyProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Add your phone number'), findsOneWidget);
      expect(find.text('Add your children'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sign Out'), 300);
      expect(find.text('Not paid'), findsOneWidget);
      expect(find.text('Review pending approvals'), findsNothing);
    });
  });

  group('EditProfileScreen', () {
    testWidgets('Save stays disabled until something changes, and a bad phone is rejected', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_app(_user(), const EditProfileScreen()));
      await tester.pumpAndSettle();

      TextButton saveButton() => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));
      expect(saveButton().onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Stan B');
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);

      await tester.enterText(find.widgetWithText(TextFormField, 'Phone'), '5047');
      await tester.pump();
      expect(find.text('Enter a 10-digit phone number'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), '');
      await tester.pump();
      expect(find.text('Please enter your name'), findsOneWidget);
    });

    testWidgets('closing with unsaved changes asks before discarding', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_app(
        _user(),
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Someone Else');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsOneWidget); // still on the edit screen
    });

    testWidgets('closing with no changes leaves without asking', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_app(
        _user(),
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
