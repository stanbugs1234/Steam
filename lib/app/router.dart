import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/approval_queue_screen.dart';
import '../features/attendance/presentation/checkin_qr_screen.dart';
import '../features/attendance/presentation/checkin_scanner_screen.dart';
import '../features/attendance/presentation/my_points_screen.dart';
import '../features/auth/domain/auth_providers.dart';
import '../features/auth/presentation/account_error_screen.dart';
import '../features/auth/presentation/denied_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/pending_approval_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/directory/presentation/edit_profile_screen.dart';
import '../features/directory/presentation/member_detail_screen.dart';
import '../features/events/presentation/event_detail_screen.dart';
import '../features/events/presentation/event_editor_screen.dart';
import '../features/news/presentation/news_detail_screen.dart';
import '../features/news/presentation/news_editor_screen.dart';
import '../features/volunteering/presentation/volunteer_leaderboard_screen.dart';
import '../features/volunteering/presentation/volunteer_slots_admin_screen.dart';
import '../models/app_user.dart';
import 'home_shell.dart';

const _authRoutes = {'/login', '/signup', '/forgot-password'};
const _accountErrorRoute = '/account-error';

/// Where to send someone who is at [location], given their sign-in state and
/// the load state of their profile. Null means "stay". Kept free of Riverpod
/// and Firebase so the whole decision table can be unit-tested.
@visibleForTesting
String? resolveRedirect({
  required String location,
  required bool signedIn,
  required AsyncValue<AppUser?> appUser,
}) {
  if (!signedIn) {
    return _authRoutes.contains(location) ? null : '/login';
  }

  final user = appUser.valueOrNull;

  if (appUser.isLoading && user == null) {
    return null;
  }

  // The profile failed to load (offline first launch, transient error). That
  // says nothing about approval, so don't show the pending screen.
  if (user == null && appUser.hasError) {
    return location == _accountErrorRoute ? null : _accountErrorRoute;
  }

  // Signed in but no profile document yet: a brand-new signup (phone-verified,
  // or an email account created a moment ago) that hasn't finished the
  // "tell us your name" step — or someone whose profile was removed. Keep them
  // on / send them to the sign-up screen, which resumes at that step. Sending
  // them to "waiting for approval" would tear the sign-up screen down before
  // the profile was ever created, leaving an account no admin can see.
  if (user == null) {
    return location == '/signup' ? null : '/signup';
  }

  if (user.status == UserStatus.pending) {
    return location == '/pending-approval' ? null : '/pending-approval';
  }

  if (user.status == UserStatus.denied) {
    return location == '/denied' ? null : '/denied';
  }

  // Approved from here on.
  if (_authRoutes.contains(location) ||
      location == '/pending-approval' ||
      location == '/denied' ||
      location == _accountErrorRoute) {
    return '/home';
  }

  final adminOnly = location.startsWith('/admin') ||
      location == '/news/new' ||
      location == '/events/new' ||
      location.endsWith('/edit') ||
      location.endsWith('/slots') ||
      location.endsWith('/qr');
  if (adminOnly && !user.isAdmin) {
    return '/home';
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (previous, next) => refreshNotifier.value++);
  ref.listen(currentAppUserProvider, (previous, next) => refreshNotifier.value++);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => resolveRedirect(
      location: state.matchedLocation,
      signedIn: ref.read(authStateProvider).valueOrNull != null,
      appUser: ref.read(currentAppUserProvider),
    ),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/pending-approval', builder: (context, state) => const PendingApprovalScreen()),
      GoRoute(path: '/denied', builder: (context, state) => const DeniedScreen()),
      GoRoute(path: _accountErrorRoute, builder: (context, state) => const AccountErrorScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/directory/:uid',
        builder: (context, state) => MemberDetailScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(path: '/news/new', builder: (context, state) => const NewsEditorScreen()),
      GoRoute(
        path: '/news/:id',
        builder: (context, state) => NewsDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/news/:id/edit',
        builder: (context, state) => NewsEditorScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/events/new', builder: (context, state) => const EventEditorScreen()),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/events/:id/edit',
        builder: (context, state) => EventEditorScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/events/:id/slots',
        builder: (context, state) => VolunteerSlotsAdminScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/events/:id/qr',
        builder: (context, state) => CheckInQrScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/checkin', builder: (context, state) => const CheckInScannerScreen()),
      GoRoute(path: '/my-points', builder: (context, state) => const MyPointsScreen()),
      // Not '/profile/edit': the admin-only guard above rejects any path ending in '/edit'.
      GoRoute(path: '/edit-profile', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/admin/approvals', builder: (context, state) => const ApprovalQueueScreen()),
      GoRoute(path: '/leaderboard', builder: (context, state) => const VolunteerLeaderboardScreen()),
    ],
  );
});
