class ChildInfo {
  final String name;
  final String grade;

  const ChildInfo({required this.name, required this.grade});

  factory ChildInfo.fromMap(Map<String, dynamic> map) {
    return ChildInfo(
      name: map['name'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'grade': grade};
}
