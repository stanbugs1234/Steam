import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

/// Firebase auth session state (signed in / signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The signed-in user's app profile document (role, status, contact info),
/// or null if signed out / profile not created yet.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  return _watchUserResilient(ref.watch(userRepositoryProvider), user.uid);
});

/// Firestore's client can briefly lag a beat behind a just-completed sign-in
/// before it picks up the fresh auth token, which spuriously denies the very
/// first read of a new subscription with `permission-denied` even though the
/// user is legitimately signed in. Re-subscribe a couple of times with a
/// short backoff before giving up and surfacing the error for real.
Stream<AppUser?> _watchUserResilient(UserRepository userRepo, String uid) async* {
  const maxAttempts = 3;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      yield* userRepo.watchUser(uid);
      return;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' || attempt == maxAttempts) rethrow;
      await Future.delayed(Duration(milliseconds: 300 * attempt));
    }
  }
}

final pendingUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchPendingUsers();
});

final approvedMembersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchApprovedMembers();
});
