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
      label: data['label'] as String? ?? '',
      capacity: data['capacity'] as int? ?? 0,
      signedUpUserIds: List<String>.from(data['signedUpUserIds'] as List? ?? const []),
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
