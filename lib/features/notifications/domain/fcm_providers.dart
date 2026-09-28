import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../data/fcm_repository.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

final fcmRepositoryProvider = Provider<FcmRepository>((ref) {
  return FcmRepository(ref.watch(firebaseMessagingProvider), ref.watch(firestoreProvider));
});
