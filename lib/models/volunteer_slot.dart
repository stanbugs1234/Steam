class VolunteerSlot {
  final String id;
  final String label;
  final int capacity;
  final List<String> signedUpUserIds;

  const VolunteerSlot({
    required this.id,
    required this.label,
    required this.capacity,
    required this.signedUpUserIds,
  });

  bool get isFull => signedUpUserIds.length >= capacity;
  int get spotsLeft => (capacity - signedUpUserIds.length).clamp(0, capacity);

  factory VolunteerSlot.fromFirestore(String id, Map<String, dynamic> data) {
    return VolunteerSlot(
      id: id,
      label: data['label'] is String ? data['label'] as String : '',
      capacity: data['capacity'] is num ? (data['capacity'] as num).toInt() : 0,
      signedUpUserIds: data['signedUpUserIds'] is List
          ? (data['signedUpUserIds'] as List).whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'capacity': capacity,
      'signedUpUserIds': signedUpUserIds,
    };
  }
}
