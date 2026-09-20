import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/models/app_user.dart';
import 'package:steam_app/models/child_info.dart';

void main() {
  final roster = AppUser(
    uid: 'imported_5_Pat',
    name: 'Pat',
    email: 'pat@example.com',
    phone: '+15045550001',
    kids: const [ChildInfo(name: 'Sam', grade: '3rd Grade')],
    role: UserRole.member,
    status: UserStatus.approved,
    createdAt: DateTime(2019, 3, 10),
    duesPaid: true,
    isNewMember: true,
    memberNumber: '983 (943)',
    clubPoints: 30,
    yearlyPoints: 12,
  );

  test('copyWith keeps every roster field, not just the ones it changes', () {
    final renamed = roster.copyWith(name: 'Patrick');

    expect(renamed.name, 'Patrick');
    expect(renamed.duesPaid, isTrue);
    expect(renamed.isNewMember, isTrue);
    expect(renamed.memberNumber, '983 (943)');
    expect(renamed.clubPoints, 30);
    expect(renamed.yearlyPoints, 12);
    expect(renamed.createdAt, DateTime(2019, 3, 10));
  });

  test('roster fields survive a write and read back', () {
    final data = roster.toFirestore();

    expect(data['memberNumber'], '983 (943)');
    expect(data['yearlyPoints'], 12);
    expect(data['clubPoints'], 30);
    expect(data['duesPaid'], true);
    expect(data['isNewMember'], true);

    // Firestore returns createdAt as a Timestamp; drop it to read back plainly.
    final readBack = AppUser.fromFirestore('u1', {...data}..remove('createdAt'));
    expect(readBack.memberNumber, '983 (943)');
    expect(readBack.yearlyPoints, 12);
    expect(readBack.duesPaid, isTrue);
  });

  test('a malformed profile parses instead of throwing (one bad doc must not break every list)', () {
    final user = AppUser.fromFirestore('u1', {
      'name': 5,
      'phone': ['x'],
      'kids': [1, 'two', {'name': 3, 'grade': null}, {'name': 'Ok', 'grade': '2nd Grade'}],
      'photoUrl': 42,
      'remindersEnabled': 'yes',
      'yearlyPoints': 'lots',
      'clubPoints': 7.0,
      'createdAt': 'yesterday',
      'role': 'admin',
      'status': 'approved',
    });
    expect(user.name, '');
    expect(user.phone, '');
    expect(user.photoUrl, isNull);
    expect(user.remindersEnabled, isTrue);
    expect(user.yearlyPoints, isNull);
    expect(user.clubPoints, 7);
    expect(user.createdAt, isNull);
    expect(user.isAdmin, isTrue);
    expect(user.kids.map((k) => k.name), ['', 'Ok']);
  });
}
