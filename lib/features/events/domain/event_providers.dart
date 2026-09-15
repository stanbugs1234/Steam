import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/club_event.dart';
import '../data/event_repository.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(firestoreProvider));
});

final eventsProvider = StreamProvider<List<ClubEvent>>((ref) {
  return ref.watch(eventRepositoryProvider).watchEvents();
});
