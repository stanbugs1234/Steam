import 'package:cloud_firestore/cloud_firestore.dart';

/// A member's check-in at a single event, denormalized at write time so the
/// record stays meaningful even if the underlying event is later edited or
/// deleted.
class AttendanceRecord {
  final String eventId;
  final String eventTitle;
  final DateTime eventStartTime;
  final int points;
  final DateTime? checkedInAt;

  const AttendanceRecord({
    required this.eventId,
    required this.eventTitle,
    required this.eventStartTime,
    required this.points,
    this.checkedInAt,
  });

  factory AttendanceRecord.fromFirestore(String eventId, Map<String, dynamic> data) {
    return AttendanceRecord(
      eventId: eventId,
      eventTitle: data['eventTitle'] is String ? data['eventTitle'] as String : '',
      eventStartTime: data['eventStartTime'] is Timestamp
          ? (data['eventStartTime'] as Timestamp).toDate()
          : DateTime.now(),
      points: data['points'] is num ? (data['points'] as num).toInt() : 0,
      checkedInAt: data['checkedInAt'] is Timestamp ? (data['checkedInAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // Stored redundantly (it's also the doc id) so an admin can count an
      // event's check-ins with one collection-group query.
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventStartTime': Timestamp.fromDate(eventStartTime),
      'points': points,
      'checkedInAt': FieldValue.serverTimestamp(),
    };
  }
}
