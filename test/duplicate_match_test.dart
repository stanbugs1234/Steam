import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/auth/data/user_repository.dart';
import 'package:steam_app/models/app_user.dart';

AppUser _u(String uid, {String email = '', String phone = ''}) => AppUser(
      uid: uid,
      name: uid,
      email: email,
      phone: phone,
      kids: const [],
      role: UserRole.member,
      status: UserStatus.approved,
    );

void main() {
  final pending = _u('new1', email: 'Pat@Example.com', phone: '+15045550001');

  test('matches a roster placeholder by phone regardless of formatting', () {
    final match = UserRepository.findPossibleDuplicate(
      pending,
      [_u('other'), _u('imported_1_Pat', phone: '(504) 555-0001')],
    );
    expect(match?.uid, 'imported_1_Pat');
  });

  test('matches by email ignoring case and spaces', () {
    final match = UserRepository.findPossibleDuplicate(
      pending,
      [_u('imported_2_Pat', email: ' pat@example.com ')],
    );
    expect(match?.uid, 'imported_2_Pat');
  });

  test('does not match the signup against itself or unrelated members', () {
    expect(UserRepository.findPossibleDuplicate(pending, [pending, _u('x', email: 'x@y.com', phone: '5045559999')]), isNull);
  });

  test('a signup with no phone or email matches nothing', () {
    expect(UserRepository.findPossibleDuplicate(_u('blank'), [_u('imported_3', phone: '')]), isNull);
  });
}
