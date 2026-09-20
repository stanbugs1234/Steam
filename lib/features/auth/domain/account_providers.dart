import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../directory/domain/directory_providers.dart';
import '../../notifications/domain/notification_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../data/account_deletion_service.dart';
import 'auth_providers.dart';

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(
    auth: ref.watch(firebaseAuthProvider),
    users: ref.watch(userRepositoryProvider),
    photos: ref.watch(profilePhotoRepositoryProvider),
    volunteer: ref.watch(volunteerRepositoryProvider),
    reminders: ref.watch(reminderServiceProvider),
  );
});
