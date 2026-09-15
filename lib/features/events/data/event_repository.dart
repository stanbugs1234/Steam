import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/club_event.dart';

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

  Future<void> createEvent(ClubEvent event) {
    return _eventsRef.doc(event.id).set(event.toFirestore());
  }

  Future<void> updateEvent(String id, Map<String, dynamic> fields) {
    return _eventsRef.doc(id).update(fields);
  }

  Future<void> deleteEvent(String id) {
    return _eventsRef.doc(id).delete();
  }
}
