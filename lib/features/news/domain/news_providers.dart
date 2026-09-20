import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/news_post.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/news_image_repository.dart';
import '../data/news_repository.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository(ref.watch(firestoreProvider));
});

final newsImageRepositoryProvider = Provider<NewsImageRepository>((ref) {
  return NewsImageRepository(ref.watch(firebaseStorageProvider));
});

final newsFeedProvider = StreamProvider<List<NewsPost>>((ref) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(newsRepositoryProvider).watchFeed();
});
