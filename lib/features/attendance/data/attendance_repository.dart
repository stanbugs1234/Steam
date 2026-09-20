import 'dart:math';

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

  DocumentReference<Map<String, dynamic>> _secretRef(String eventId) {
    return _firestore.collection('events').doc(eventId).collection('private').doc('checkin');
  }

  /// Turns check-in on for an event (admins only — the Firestore rules
  /// enforce that) and makes sure it has its secret code. Safe to call
  /// again: an existing code is kept, so a QR that's already on screen stays
  /// valid.
  Future<String> startCheckIn(String eventId) async {
    final code = await _ensureCode(eventId);
    await _firestore.collection('events').doc(eventId).update({'checkInEnabled': true});
    return code;
  }

  /// The event's check-in code, creating one if it doesn't exist yet. Admin
  /// only: members can't read it, which is what proves a member scanned the
  /// admin's QR rather than writing their own check-in.
  Future<String> getOrCreateCode(String eventId) => _ensureCode(eventId);

  Future<String> _ensureCode(String eventId) async {
    final ref = _secretRef(eventId);
    final existing = (await ref.get()).data()?['code'];
    if (existing is String && existing.isNotEmpty) return existing;
    final code = _newCode();
    await ref.set({'code': code});
    return code;
  }

  static String _newCode() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// How many members have checked in to an event. Admin only.
  Future<int> checkInCount(String eventId) async {
    final snap = await _firestore
        .collectionGroup('attendance')
        .where('eventId', isEqualTo: eventId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Stream<List<AttendanceRecord>> watchMyCheckIns(String uid) {
    return _attendanceRef(uid).orderBy('checkedInAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => AttendanceRecord.fromFirestore(d.id, d.data())).toList(),
        );
  }

  /// Removes every check-in record for [uid] (account deletion).
  Future<void> deleteAllFor(String uid) async {
    final snap = await _attendanceRef(uid).get();
    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = _firestore.batch();
      for (final doc in snap.docs.skip(i).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Records the member's check-in. The doc id is the event id, so the
  /// Firestore rules refuse a second one; [code] is the secret from the QR.
  Future<void> checkIn({required String uid, required ClubEvent event, required String code}) async {
    if (!event.checkInEnabled) {
      throw const CheckInNotAvailableException();
    }
    final attendanceDoc = _attendanceRef(uid).doc(event.id);
    if ((await attendanceDoc.get()).exists) {
      throw const AlreadyCheckedInException();
    }
    await attendanceDoc.set({
      ...AttendanceRecord(
        eventId: event.id,
        eventTitle: event.title,
        eventStartTime: event.startTime,
        points: 1,
      ).toFirestore(),
      'code': code,
    });
  }
}
