import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/club_event.dart';
import '../../../models/volunteer_slot.dart';

class EventRepository {
  EventRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _eventsRef => _firestore.collection('events');

  String newEventId() => _eventsRef.doc().id;

  Stream<List<ClubEvent>> watchEvents() {
    return _eventsRef
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs.map((d) => ClubEvent.fromFirestore(d.id, d.data())).toList());
  }

  CollectionReference<Map<String, dynamic>> _slotsRef(String eventId) =>
      _eventsRef.doc(eventId).collection('volunteerSlots');

  Future<void> createEvent(ClubEvent event) {
    return _eventsRef.doc(event.id).set(event.toFirestore());
  }

  /// Creates an event and its single volunteer slot as one atomic write, so a
  /// failure can't leave an event marked "needs volunteers" with no slot.
  Future<void> createEventWithSlot(ClubEvent event, VolunteerSlot slot) {
    final batch = _firestore.batch();
    batch.set(_eventsRef.doc(event.id), event.toFirestore());
    batch.set(_slotsRef(event.id).doc(slot.id), slot.toFirestore());
    return batch.commit();
  }

  Future<void> updateEvent(String id, Map<String, dynamic> fields) {
    return _eventsRef.doc(id).update(fields);
  }

  /// Updates an event together with its single volunteer slot — creating
  /// [newSlot], or changing [existingSlotId]'s capacity — as one atomic write.
  Future<void> updateEventAndSlot(
    String id,
    Map<String, dynamic> fields, {
    VolunteerSlot? newSlot,
    String? existingSlotId,
    String? existingSlotLabel,
    int? newCapacity,
  }) {
    final batch = _firestore.batch();
    batch.update(_eventsRef.doc(id), fields);
    if (newSlot != null) {
      batch.set(_slotsRef(id).doc(newSlot.id), newSlot.toFirestore());
    } else if (existingSlotId != null && newCapacity != null) {
      batch.update(_slotsRef(id).doc(existingSlotId), {
        'label': ?existingSlotLabel,
        'capacity': newCapacity,
      });
    }
    return batch.commit();
  }

  /// Deletes an event along with its volunteer slots and its check-in secret.
  /// (Firestore doesn't delete subcollections with their parent, so without
  /// this they'd be orphaned and keep counting in volunteer hours queries.)
  Future<void> deleteEvent(String id) async {
    final slots = await _slotsRef(id).get();
    final batch = _firestore.batch();
    for (final slot in slots.docs) {
      batch.delete(slot.reference);
    }
    batch.delete(_eventsRef.doc(id).collection('private').doc('checkin'));
    batch.delete(_eventsRef.doc(id));
    await batch.commit();
  }
}
