import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/volunteer_slot.dart';

class SlotFullException implements Exception {
  const SlotFullException();
}

class VolunteerRepository {
  VolunteerRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _slotsRef(String eventId) {
    return _firestore.collection('events').doc(eventId).collection('volunteerSlots');
  }

  String newSlotId(String eventId) => _slotsRef(eventId).doc().id;

  Stream<List<VolunteerSlot>> watchSlots(String eventId) {
    return _slotsRef(eventId)
        .orderBy('label')
        .snapshots()
        .map((snap) => snap.docs.map((d) => VolunteerSlot.fromFirestore(d.id, d.data())).toList());
  }

  /// A one-time read, with no live listener — for events that have already
  /// ended, whose sign-up counts can no longer change, so there's nothing to
  /// watch for.
  Future<List<VolunteerSlot>> getSlotsOnce(String eventId) async {
    final snap = await _slotsRef(eventId).orderBy('label').get();
    return snap.docs.map((d) => VolunteerSlot.fromFirestore(d.id, d.data())).toList();
  }

  Future<void> createSlot(String eventId, VolunteerSlot slot) {
    return _slotsRef(eventId).doc(slot.id).set(slot.toFirestore());
  }

  Future<void> updateSlotDetails(String eventId, String slotId, {required String label, required int capacity}) {
    return _slotsRef(eventId).doc(slotId).update({'label': label, 'capacity': capacity});
  }

  Future<void> deleteSlot(String eventId, String slotId) {
    return _slotsRef(eventId).doc(slotId).delete();
  }

  /// Adds [uid] to the slot. Returns true if they were newly added, false if
  /// nothing changed (the slot was deleted, or they were already in it) — so
  /// callers don't act on a sign-up that didn't happen.
  Future<bool> signUp(String eventId, String slotId, String uid) async {
    final ref = _slotsRef(eventId).doc(slotId);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return false;
      final signedUp = data['signedUpUserIds'] is List
          ? (data['signedUpUserIds'] as List).whereType<String>().toList()
          : <String>[];
      final capacity = data['capacity'] is num ? (data['capacity'] as num).toInt() : 0;
      if (signedUp.contains(uid)) return false;
      if (signedUp.length >= capacity) {
        throw const SlotFullException();
      }
      tx.update(ref, {
        'signedUpUserIds': FieldValue.arrayUnion([uid]),
      });
      return true;
    });
  }

  /// Removes [uid] from every volunteer slot of every event, past or upcoming
  /// (account deletion). Returns the (eventId, slotId) pairs they were removed
  /// from so callers can cancel any reminders. Events the caller can't read
  /// slots for are skipped rather than failing the whole cleanup.
  Future<List<({String eventId, String slotId})>> removeUserFromAllSlots(String uid) async {
    final removed = <({String eventId, String slotId})>[];
    final events = await _firestore.collection('events').get();
    for (final event in events.docs) {
      final mine = await _slotsRef(event.id).where('signedUpUserIds', arrayContains: uid).get();
      for (final slot in mine.docs) {
        await cancel(event.id, slot.id, uid);
        removed.add((eventId: event.id, slotId: slot.id));
      }
    }
    return removed;
  }

  Future<void> cancel(String eventId, String slotId, String uid) {
    return _slotsRef(eventId).doc(slotId).update({
      'signedUpUserIds': FieldValue.arrayRemove([uid]),
    });
  }
}
