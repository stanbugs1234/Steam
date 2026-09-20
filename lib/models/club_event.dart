import 'package:cloud_firestore/cloud_firestore.dart';

class ClubEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime startTime;
  final DateTime endTime;
  final bool needsVolunteers;
  final String createdBy;
  final DateTime? createdAt;
  final bool checkInEnabled;

  const ClubEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.needsVolunteers,
    required this.createdBy,
    this.createdAt,
    this.checkInEnabled = false,
  });

  factory ClubEvent.fromFirestore(String id, Map<String, dynamic> data) {
    return ClubEvent(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      needsVolunteers: data['needsVolunteers'] as bool? ?? false,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      checkInEnabled: data['checkInEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'needsVolunteers': needsVolunteers,
      'createdBy': createdBy,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'checkInEnabled': checkInEnabled,
    };
  }
}
