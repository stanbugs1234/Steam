import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/app/router.dart';
import 'package:steam_app/models/app_user.dart';

AppUser _user({UserStatus status = UserStatus.approved, UserRole role = UserRole.member}) => AppUser(
      uid: 'u1',
      name: 'Pat',
      email: 'pat@example.com',
      phone: '',
      kids: const [],
      role: role,
      status: status,
    );

AsyncValue<AppUser?> _data(AppUser? u) => AsyncValue.data(u);

String? _go(String location, {bool signedIn = true, required AsyncValue<AppUser?> appUser}) =>
    resolveRedirect(location: location, signedIn: signedIn, appUser: appUser);

void main() {
  group('signed out', () {
    final none = _data(null);
    test('is sent to login from any app screen', () {
      expect(_go('/home', signedIn: false, appUser: none), '/login');
      expect(_go('/events/e1', signedIn: false, appUser: none), '/login');
    });
    test('may stay on the auth screens', () {
      for (final r in ['/login', '/signup', '/forgot-password']) {
        expect(_go(r, signedIn: false, appUser: none), isNull);
      }
    });
  });

  group('profile still loading', () {
    test('stays put rather than flashing the pending screen', () {
      expect(_go('/login', appUser: const AsyncValue.loading()), isNull);
      expect(_go('/home', appUser: const AsyncValue.loading()), isNull);
    });
  });

  group('profile failed to load', () {
    final failed = AsyncValue<AppUser?>.error(Exception('offline'), StackTrace.empty);
    test('goes to the account-error screen, never "pending"', () {
      expect(_go('/home', appUser: failed), '/account-error');
      expect(_go('/login', appUser: failed), '/account-error');
      expect(_go('/pending-approval', appUser: failed), '/account-error');
    });
    test('stays on the account-error screen', () {
      expect(_go('/account-error', appUser: failed), isNull);
    });
    test('an approved member recovers straight to home once it loads', () {
      expect(_go('/account-error', appUser: _data(_user())), '/home');
    });
  });

  group('signed in but no profile document yet', () {
    test('is kept on / sent to the sign-up screen to finish the profile', () {
      expect(_go('/signup', appUser: _data(null)), isNull);
      expect(_go('/home', appUser: _data(null)), '/signup');
      expect(_go('/login', appUser: _data(null)), '/signup');
      expect(_go('/pending-approval', appUser: _data(null)), '/signup');
    });
  });

  group('pending', () {
    test('pending members are held on the pending screen', () {
      final pending = _data(_user(status: UserStatus.pending));
      expect(_go('/home', appUser: pending), '/pending-approval');
      expect(_go('/directory/x', appUser: pending), '/pending-approval');
      expect(_go('/pending-approval', appUser: pending), isNull);
    });
    test('a fresh signup moves on to pending as soon as the profile exists', () {
      expect(_go('/signup', appUser: _data(_user(status: UserStatus.pending))), '/pending-approval');
    });
  });

  group('denied', () {
    test('is held on the denied screen', () {
      final denied = _data(_user(status: UserStatus.denied));
      expect(_go('/home', appUser: denied), '/denied');
      expect(_go('/denied', appUser: denied), isNull);
    });
  });

  group('approved member', () {
    final member = _data(_user());
    test('is moved off the auth / waiting screens to home', () {
      for (final r in ['/login', '/signup', '/forgot-password', '/pending-approval', '/denied']) {
        expect(_go(r, appUser: member), '/home');
      }
    });
    test('can open ordinary screens', () {
      for (final r in ['/home', '/events/e1', '/news/n1', '/directory/u2', '/checkin', '/my-points', '/edit-profile']) {
        expect(_go(r, appUser: member), isNull, reason: r);
      }
    });
    test('cannot open admin-only screens', () {
      for (final r in [
        '/admin/approvals',
        '/news/new',
        '/events/new',
        '/events/e1/edit',
        '/news/n1/edit',
        '/events/e1/slots',
        '/events/e1/qr',
      ]) {
        expect(_go(r, appUser: member), '/home', reason: r);
      }
    });
  });

  group('approved admin', () {
    final admin = _data(_user(role: UserRole.admin));
    test('can open admin-only screens', () {
      for (final r in ['/admin/approvals', '/news/new', '/events/new', '/events/e1/edit', '/events/e1/slots', '/events/e1/qr']) {
        expect(_go(r, appUser: admin), isNull, reason: r);
      }
    });
  });
}
