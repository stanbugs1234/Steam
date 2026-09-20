class ChildInfo {
  final String name;
  final String grade;

  const ChildInfo({required this.name, required this.grade});

  factory ChildInfo.fromMap(Map<String, dynamic> map) {
    return ChildInfo(
      // Tolerant of a wrongly-typed value: one bad field in someone's profile
      // must not take down every screen that lists members.
      name: map['name'] is String ? map['name'] as String : '',
      grade: map['grade'] is String ? map['grade'] as String : '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'grade': grade};
}
