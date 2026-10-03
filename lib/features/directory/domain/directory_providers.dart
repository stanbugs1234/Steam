import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../data/profile_photo_repository.dart';

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>((ref) {
  return ProfilePhotoRepository(ref.watch(firebaseStorageProvider));
});

/// Directory list filter state. Lives here (rather than in the presentation
/// file) so other screens — e.g. the Dashboard's KPI cards — can set it
/// before switching to the Directory tab.
final directorySearchProvider = StateProvider<String>((ref) => '');
final directoryGradeFilterProvider = StateProvider<String?>((ref) => null);
final directoryNewMemberFilterProvider = StateProvider<bool>((ref) => false);

enum DuesFilter { any, paidOnly, unpaidOnly }

final directoryDuesFilterProvider = StateProvider<DuesFilter>((ref) => DuesFilter.any);
