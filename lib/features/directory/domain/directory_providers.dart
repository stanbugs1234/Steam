import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../data/profile_photo_repository.dart';

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>((ref) {
  return ProfilePhotoRepository(ref.watch(firebaseStorageProvider));
});
