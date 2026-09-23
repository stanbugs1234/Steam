import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/directory/presentation/directory_list_screen.dart';
import 'package:steam_app/features/directory/presentation/kids_list.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/child_info.dart';

AppUser _member(String uid, String name, List<ChildInfo> kids) => AppUser(
      uid: uid,
      name: name,
      email: '',
      phone: '',
      kids: kids,
      role: UserRole.member,
      status: UserStatus.approved,
    );

Widget _wrap(Widget child, {double textScale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 320, child: child))),
      ),
    );

void main() {
  const kids = [
    ChildInfo(name: 'Sam Rivera', grade: '3rd Grade'),
    ChildInfo(name: 'Ava Rivera', grade: 'Kindergarten'),
    ChildInfo(name: 'Leo Rivera', grade: ''),
  ];

  testWidgets('shows each child on its own line with the grade after the name', (tester) async {
    await tester.pumpWidget(_wrap(const KidsList(kids: kids)));

    expect(find.textContaining('Sam Rivera', findRichText: true), findsOneWidget);
    expect(find.textContaining('3rd Grade', findRichText: true), findsOneWidget);
    expect(find.textContaining('Leo Rivera', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.child_care_outlined), findsNWidgets(3));

    // One row per child: their tops step down the screen in order.
    final ys = [
      for (final n in ['Sam Rivera', 'Ava Rivera', 'Leo Rivera'])
        tester.getTopLeft(find.textContaining(n, findRichText: true)).dy,
    ];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
  });

  testWidgets('a child without a grade shows just the name', (tester) async {
    await tester.pumpWidget(_wrap(const KidsList(kids: [ChildInfo(name: 'Leo', grade: '')])));
    final text = tester.widget<RichText>(find.byType(RichText).last).text.toPlainText();
    expect(text, 'Leo');
  });

  testWidgets('long names and large text wrap instead of overflowing', (tester) async {
    await tester.pumpWidget(_wrap(
      const KidsList(kids: [ChildInfo(name: 'Maximilian Montgomery-Fitzgerald the Third', grade: 'Kindergarten')]),
      textScale: 3.0,
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the directory lists a member\'s children one per line', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('me'),
        currentAppUserProvider.overrideWith((ref) => Stream.value(_member('me', 'Me', const []))),
        approvedMembersProvider.overrideWith((ref) => Stream.value([_member('a', 'Pat Rivera', kids)])),
        volunteerLeaderboardProvider.overrideWithValue(const []),
      ],
      child: const MaterialApp(home: DirectoryListScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Pat Rivera'), findsOneWidget);
    expect(find.byType(KidsList), findsOneWidget);
    expect(find.byIcon(Icons.child_care_outlined), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
