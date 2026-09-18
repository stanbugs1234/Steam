import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/attendance_record.dart';
import '../../../models/club_event.dart';

class AlreadyCheckedInException implements Exception {
  const AlreadyCheckedInException();
}

class CheckInNotAvailableException implements Exception {
  const CheckInNotAvailableException();
}

class AttendanceRepository {
  AttendanceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _attendanceRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('attendance');
  }

  /// Flips an event's checkInEnabled flag on, letting any approved member
  /// start check-in on the spot rather than requiring an admin to have
  /// pre-enabled it in the editor. The Firestore rule (not this call) is what
  /// actually restricts this to a window around the event's own time.
  Future<void> startCheckIn(String eventId) {
    return _firestore.collection('events').doc(eventId).update({'checkInEnabled': true});
  }

  Stream<List<AttendanceRecord>> watchMyCheckIns(String uid) {
    return _attendanceRef(uid).orderBy('checkedInAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => AttendanceRecord.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Future<void> checkIn({required String uid, required ClubEvent event}) async {
    if (!event.checkInEnabled) {
      throw const CheckInNotAvailableException();
    }
    final attendanceDoc = _attendanceRef(uid).doc(event.id);
    final eventDoc = _firestore.collection('events').doc(event.id);
    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(attendanceDoc);
      if (existing.exists) {
        throw const AlreadyCheckedInException();
      }
      tx.set(
        attendanceDoc,
        AttendanceRecord(
          eventId: event.id,
          eventTitle: event.title,
          eventStartTime: event.startTime,
          points: 1,
        ).toFirestore(),
      );
      tx.update(eventDoc, {
        'checkedInUserIds': FieldValue.arrayUnion([uid]),
      });
    });
  }
}
