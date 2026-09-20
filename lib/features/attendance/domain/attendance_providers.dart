import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/attendance_record.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(firestoreProvider));
});

/// An event's check-in code — admin only (members can't read it).
final checkInCodeProvider = FutureProvider.autoDispose.family<String, String>((ref, eventId) {
  return ref.watch(attendanceRepositoryProvider).getOrCreateCode(eventId);
});

/// How many members have checked in to an event — admin only.
final checkInCountProvider = FutureProvider.autoDispose.family<int, String>((ref, eventId) {
  return ref.watch(attendanceRepositoryProvider).checkInCount(eventId);
});

/// The signed-in member's check-in history, newest first.
final myCheckInsProvider = StreamProvider<List<AttendanceRecord>>((ref) {
  final myUid = ref.watch(currentAppUserProvider).value?.uid;
  if (myUid == null) return const Stream.empty();
  return ref.watch(attendanceRepositoryProvider).watchMyCheckIns(myUid);
});

/// The signed-in member's points: whatever the club roster recorded for them
/// plus one entry per meeting they checked into in the app. Everything that
/// shows a points total (Home, Profile, the points history) reads this so
/// they can't disagree.
class PointsSummary {
  final int rosterPoints;
  final List<AttendanceRecord> checkIns;

  const PointsSummary({required this.rosterPoints, required this.checkIns});

  int get checkInPoints => checkIns.fold(0, (sum, r) => sum + r.points);
  int get total => rosterPoints + checkInPoints;
}

final myPointsSummaryProvider = Provider<PointsSummary>((ref) {
  final me = ref.watch(currentAppUserProvider).value;
  final checkIns = ref.watch(myCheckInsProvider).value ?? const <AttendanceRecord>[];
  return PointsSummary(rosterPoints: me?.yearlyPoints ?? 0, checkIns: checkIns);
});
