import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/approval_queue_screen.dart';
import '../features/auth/domain/auth_providers.dart';
import '../features/auth/presentation/denied_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/home_placeholder_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/pending_approval_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../models/app_user.dart';

const _authRoutes = {'/login', '/signup', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (previous, next) => refreshNotifier.value++);
  ref.listen(currentAppUserProvider, (previous, next) => refreshNotifier.value++);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final authState = ref.read(authStateProvider);
      final firebaseUser = authState.valueOrNull;

      if (firebaseUser == null) {
        return _authRoutes.contains(loc) ? null : '/login';
      }

      final appUserAsync = ref.read(currentAppUserProvider);
      final appUser = appUserAsync.valueOrNull;

      if (appUserAsync.isLoading && appUser == null) {
        return null;
      }

      if (appUser == null || appUser.status == UserStatus.pending) {
        return loc == '/pending-approval' ? null : '/pending-approval';
      }

      if (appUser.status == UserStatus.denied) {
        return loc == '/denied' ? null : '/denied';
      }

      // Approved from here on.
      if (_authRoutes.contains(loc) || loc == '/pending-approval' || loc == '/denied') {
        return '/home';
      }

      if (loc.startsWith('/admin') && !appUser.isAdmin) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/pending-approval', builder: (context, state) => const PendingApprovalScreen()),
      GoRoute(path: '/denied', builder: (context, state) => const DeniedScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomePlaceholderScreen()),
      GoRoute(path: '/admin/approvals', builder: (context, state) => const ApprovalQueueScreen()),
    ],
  );
});
