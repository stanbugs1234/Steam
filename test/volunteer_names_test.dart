import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/features/volunteering/presentation/volunteer_slot_section.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/volunteer_slot.dart';

AppUser _member(String uid, String name) => AppUser(
      uid: uid,
      name: name,
      email: '',
      phone: '',
      kids: const [],
      role: UserRole.member,
      status: UserStatus.approved,
    );

final _event = ClubEvent(
  id: 'e1',
  title: 'Book Fair',
  description: '',
  location: '',
  startTime: DateTime.now().add(const Duration(days: 2)),
  endTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
  needsVolunteers: true,
  createdBy: 'admin',
);

Widget _app({
  required List<VolunteerSlot> slots,
  Stream<List<AppUser>>? members,
  String me = 'me',
}) {
  return ProviderScope(
    overrides: [
      eventSlotsProvider.overrideWith((ref, eventId) => Stream.value(slots)),
      approvedMembersProvider.overrideWith(
        (ref) => members ?? Stream.value([_member('me', 'Morgan Lee'), _member('a', 'Avery Cole'), _member('z', 'Zane Bell')]),
      ),
      currentAppUserProvider.overrideWith((ref) => Stream.value(_member(me, 'Morgan Lee'))),
    ],
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: VolunteerSlotSection(event: _event))),
    ),
  );
}

void main() {
  testWidgets('lists each task with the names of the people signed up for it', (tester) async {
    await tester.pumpWidget(_app(slots: const [
      VolunteerSlot(id: 's1', label: 'Setup Crew', capacity: 4, signedUpUserIds: ['z', 'a']),
      VolunteerSlot(id: 's2', label: 'Cash Table', capacity: 2, signedUpUserIds: ['me']),
    ]));
    await tester.pump();

    expect(find.text('Setup Crew'), findsOneWidget);
    expect(find.text('Avery Cole'), findsOneWidget);
    expect(find.text('Zane Bell'), findsOneWidget);
    expect(find.text('Cash Table'), findsOneWidget);
    expect(find.text('Morgan Lee (You)'), findsOneWidget);
  });

  testWidgets('names within a task are alphabetical, with you first', (tester) async {
    await tester.pumpWidget(_app(slots: const [
      VolunteerSlot(id: 's1', label: 'Setup Crew', capacity: 5, signedUpUserIds: ['z', 'a', 'me']),
    ]));
    await tester.pump();

    // Reading order: chips wrap onto new rows, so compare row first, then column.
    double x(String text) {
      final p = tester.getTopLeft(find.text(text));
      return p.dy * 10000 + p.dx;
    }

    expect(x('Morgan Lee (You)'), lessThan(x('Avery Cole')));
    expect(x('Avery Cole'), lessThan(x('Zane Bell')));
  });

  testWidgets('a task nobody has taken says so', (tester) async {
    await tester.pumpWidget(_app(slots: const [
      VolunteerSlot(id: 's1', label: 'Cleanup', capacity: 3, signedUpUserIds: []),
    ]));
    await tester.pump();

    expect(find.text('Cleanup'), findsOneWidget);
    expect(find.text('No one has signed up yet.'), findsOneWidget);
  });

  testWidgets('someone whose account is gone still counts, as "Former member"', (tester) async {
    await tester.pumpWidget(_app(slots: const [
      VolunteerSlot(id: 's1', label: 'Setup Crew', capacity: 3, signedUpUserIds: ['a', 'deleted-uid']),
    ]));
    await tester.pump();

    expect(find.text('Avery Cole'), findsOneWidget);
    expect(find.text('Former member'), findsOneWidget);
    expect(find.text('2 of 3 spots filled'), findsOneWidget);
  });

  testWidgets('falls back to the count while the directory is still loading', (tester) async {
    await tester.pumpWidget(_app(
      slots: const [VolunteerSlot(id: 's1', label: 'Setup Crew', capacity: 4, signedUpUserIds: ['a', 'z'])],
      members: const Stream<List<AppUser>>.empty(),
    ));
    await tester.pump();

    expect(find.text('2 signed up'), findsOneWidget);
    expect(find.text('Avery Cole'), findsNothing);
  });
}
