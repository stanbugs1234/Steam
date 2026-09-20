import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/attendance/domain/attendance_providers.dart';
import 'package:steam_app/features/attendance/presentation/my_points_screen.dart';
import 'package:steam_app/features/auth/domain/auth_providers.dart';
import 'package:steam_app/features/auth/presentation/denied_screen.dart';
import 'package:steam_app/features/auth/presentation/login_screen.dart';
import 'package:steam_app/features/auth/presentation/pending_approval_screen.dart';
import 'package:steam_app/features/directory/presentation/edit_profile_screen.dart';
import 'package:steam_app/features/directory/presentation/my_profile_screen.dart';
import 'package:steam_app/features/events/domain/event_providers.dart';
import 'package:steam_app/features/news/domain/news_providers.dart';
import 'package:steam_app/features/news/presentation/news_feed_screen.dart';
import 'package:steam_app/features/volunteering/domain/volunteer_providers.dart';
import 'package:steam_app/features/volunteering/presentation/my_commitments_screen.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/child_info.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/news_post.dart';

/// Members with large system text (Dynamic Type / Android font size) must
/// still be able to use every main screen: a layout overflow shows up here as
/// a Flutter exception.
final _user = AppUser(
  uid: 'u1',
  name: 'Bartholomew Montgomery-Fitzgerald',
  email: 'bartholomew.montgomery.fitzgerald@example.com',
  phone: '+15045551234',
  kids: const [ChildInfo(name: 'Maximilian Montgomery-Fitzgerald', grade: 'Kindergarten')],
  role: UserRole.admin,
  status: UserStatus.approved,
  createdAt: DateTime(2019, 3, 10),
  duesPaid: true,
  isNewMember: true,
  memberNumber: '983 (943)',
  yearlyPoints: 4,
);

final _event = ClubEvent(
  id: 'e1',
  title: 'Annual Guest Speaker Fundraising Dinner and Silent Auction',
  description: '',
  location: 'St. Edward Parish Hall, 1234 Some Very Long Street Name',
  startTime: DateTime.now().add(const Duration(days: 3)),
  endTime: DateTime.now().add(const Duration(days: 3, hours: 3)),
  needsVolunteers: true,
  createdBy: 'u1',
);

final _post = NewsPost(
  id: 'p1',
  title: 'Annual Guest Speaker Fundraising Dinner and Silent Auction Announcement',
  body: 'Join us for an evening of talks and fellowship. ' * 6,
  authorId: 'u1',
  authorName: 'Bartholomew Montgomery-Fitzgerald',
  category: NewsCategory.speaker,
  pinned: true,
  createdAt: DateTime.now().subtract(const Duration(hours: 5)),
);

Widget _app(Widget screen, double scale) {
  return ProviderScope(
    overrides: [
      currentAppUserProvider.overrideWith((ref) => Stream.value(_user)),
      myPointsSummaryProvider.overrideWithValue(const PointsSummary(rosterPoints: 4, checkIns: [])),
      volunteerHoursProvider.overrideWith((ref) async => {'u1': 7.5}),
      eventVolunteerProgressProvider.overrideWith((ref, eventId) => null),
      topVolunteerUidsProvider.overrideWithValue(const {'u1'}),
      pendingUsersProvider.overrideWith((ref) => Stream.value([_user])),
      newsFeedProvider.overrideWith((ref) => Stream.value([_post, _post])),
      eventsProvider.overrideWith((ref) => Stream.value([_event])),
      myCommitmentsProvider.overrideWithValue(const AsyncValue.data(<MyCommitment>[])),
      myVolunteerRecordProvider.overrideWithValue(const AsyncValue.data(<VolunteerRecord>[])),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: screen,
    ),
  );
}

/// Widget tests draw text with a placeholder font whose letters are roughly
/// twice as wide as real ones, which would report overflows that never happen
/// on a phone. Load the real Roboto that ships with the Flutter SDK instead.
Future<bool> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final files = {
    400: 'Roboto-Regular.ttf',
    500: 'Roboto-Medium.ttf',
    700: 'Roboto-Bold.ttf',
    800: 'Roboto-Black.ttf',
  };
  final loader = FontLoader('Roboto');
  for (final name in files.values) {
    final file = File('$dir/$name');
    if (!file.existsSync()) return false;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
  return true;
}

void main() {
  late bool realFont;
  setUpAll(() async => realFont = await _loadRoboto());

  final screens = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'Profile': () => const MyProfileScreen(),
    'Edit profile': () => const EditProfileScreen(),
    'News': () => const NewsFeedScreen(),
    'My points': () => const MyPointsScreen(),
    'Volunteer': () => const MyCommitmentsScreen(),
    'Pending approval': () => const PendingApprovalScreen(),
    'Denied': () => const DeniedScreen(),
  };

  for (final entry in screens.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${entry.key} lays out at ${scale}x text size', (tester) async {
        if (!realFont) markTestSkipped('Roboto not found under FLUTTER_ROOT');
        // A small phone: 320 × 640 logical pixels.
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(entry.value(), scale));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });
    }
  }
}
