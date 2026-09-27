import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../data/club_config_repository.dart';

final clubConfigRepositoryProvider = Provider<ClubConfigRepository>((ref) {
  return ClubConfigRepository(ref.watch(firestoreProvider));
});

/// The sign-up join code, or null once loaded if the club hasn't set one.
/// Readable while signed out, so the sign-up screen can gate on it before any
/// account exists.
final joinCodeProvider = StreamProvider<String?>((ref) {
  return ref.watch(clubConfigRepositoryProvider).watchJoinCode();
});
