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

  Future<void> createSlot(String eventId, VolunteerSlot slot) {
    return _slotsRef(eventId).doc(slot.id).set(slot.toFirestore());
  }

  Future<void> updateSlotDetails(String eventId, String slotId, {required String label, required int capacity}) {
    return _slotsRef(eventId).doc(slotId).update({'label': label, 'capacity': capacity});
  }

  Future<void> deleteSlot(String eventId, String slotId) {
    return _slotsRef(eventId).doc(slotId).delete();
  }

  Future<void> signUp(String eventId, String slotId, String uid) async {
    final ref = _slotsRef(eventId).doc(slotId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final signedUp = List<String>.from(data['signedUpUserIds'] as List? ?? const []);
      final capacity = data['capacity'] as int? ?? 0;
      if (signedUp.contains(uid)) return;
      if (signedUp.length >= capacity) {
        throw const SlotFullException();
      }
      tx.update(ref, {
        'signedUpUserIds': FieldValue.arrayUnion([uid]),
      });
    });
  }

  Future<void> cancel(String eventId, String slotId, String uid) {
    return _slotsRef(eventId).doc(slotId).update({
      'signedUpUserIds': FieldValue.arrayRemove([uid]),
    });
  }
}
