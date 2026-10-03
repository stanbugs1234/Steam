import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/club_event.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/event_repository.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(firestoreProvider));
});

final eventsProvider = StreamProvider<List<ClubEvent>>((ref) {
  if (ref.watch(currentUidProvider) == null) return const Stream.empty();
  return ref.watch(eventRepositoryProvider).watchEvents();
});

/// A fire-once signal other screens bump to tell an already-mounted
/// [EventsScreen] (it stays alive inside the bottom-nav `IndexedStack`) to
/// switch to its "Upcoming" tab. The counter's value is meaningless — only
/// the fact that it changed matters.
final eventsJumpToUpcomingProvider = StateProvider<int>((ref) => 0);
