import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../../models/attendance_record.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(firestoreProvider));
});

/// The signed-in member's check-in history, newest first.
final myCheckInsProvider = StreamProvider<List<AttendanceRecord>>((ref) {
  final myUid = ref.watch(currentAppUserProvider).value?.uid;
  if (myUid == null) return const Stream.empty();
  return ref.watch(attendanceRepositoryProvider).watchMyCheckIns(myUid);
});
