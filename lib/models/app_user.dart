import 'package:cloud_firestore/cloud_firestore.dart';

import 'child_info.dart';

enum UserRole { member, admin }

enum UserStatus { pending, approved, denied }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final List<ChildInfo> kids;
  final String? photoUrl;
  final UserRole role;
  final UserStatus status;
  final DateTime? createdAt;
  final String? mergedFromId;
  final bool remindersEnabled;
  final bool duesPaid;
  final bool isNewMember;
  final String? memberNumber;
  final int? clubPoints;
  final int? yearlyPoints;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.kids,
    this.photoUrl,
    required this.role,
    required this.status,
    this.createdAt,
    this.mergedFromId,
    this.remindersEnabled = true,
    this.duesPaid = false,
    this.isNewMember = false,
    this.memberNumber,
    this.clubPoints,
    this.yearlyPoints,
  });

  bool get isApproved => status == UserStatus.approved;
  bool get isAdmin => role == UserRole.admin;
  int get kidCount => kids.length;

  /// Tolerant of wrongly-typed or missing fields: a member controls parts of
  /// their own document, and one malformed value must not make the directory,
  /// leaderboard or approval queue throw for everybody.
  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: _string(data['name']) ?? '',
      email: _string(data['email']) ?? '',
      phone: _string(data['phone']) ?? '',
      kids: _kidsFromFirestore(data),
      photoUrl: _string(data['photoUrl']),
      role: (data['role'] as Object?) == 'admin' ? UserRole.admin : UserRole.member,
      status: _statusFromString(_string(data['status'])),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
      mergedFromId: _string(data['mergedFromId']),
      remindersEnabled: data['remindersEnabled'] is bool ? data['remindersEnabled'] as bool : true,
      duesPaid: data['duesPaid'] is bool ? data['duesPaid'] as bool : false,
      isNewMember: data['isNewMember'] is bool ? data['isNewMember'] as bool : false,
      memberNumber: data['memberNumber']?.toString(),
      clubPoints: _int(data['clubPoints']),
      yearlyPoints: _int(data['yearlyPoints']),
    );
  }

  static String? _string(Object? v) => v is String ? v : null;

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static List<ChildInfo> _kidsFromFirestore(Map<String, dynamic> data) {
    final kidsRaw = data['kids'];
    if (kidsRaw is List) {
      return kidsRaw
          .whereType<Map>()
          .map((e) => ChildInfo.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    // Legacy docs stored a single child as separate kidName/kidGrade fields.
    final legacyName = _string(data['kidName']) ?? '';
    if (legacyName.isEmpty) return const [];
    return [ChildInfo(name: legacyName, grade: _string(data['kidGrade']) ?? '')];
  }

  static UserStatus _statusFromString(String? value) {
    switch (value) {
      case 'approved':
        return UserStatus.approved;
      case 'denied':
        return UserStatus.denied;
      case 'pending':
      default:
        return UserStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'kids': kids.map((k) => k.toMap()).toList(),
      'photoUrl': photoUrl,
      'role': role.name,
      'status': status.name,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'mergedFromId': mergedFromId,
      'remindersEnabled': remindersEnabled,
      'duesPaid': duesPaid,
      'isNewMember': isNewMember,
      'memberNumber': memberNumber,
      'clubPoints': clubPoints,
      'yearlyPoints': yearlyPoints,
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    List<ChildInfo>? kids,
    String? photoUrl,
    UserRole? role,
    UserStatus? status,
    bool? remindersEnabled,
    bool? duesPaid,
    bool? isNewMember,
    String? memberNumber,
    int? clubPoints,
    int? yearlyPoints,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      kids: kids ?? this.kids,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      mergedFromId: mergedFromId,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      duesPaid: duesPaid ?? this.duesPaid,
      isNewMember: isNewMember ?? this.isNewMember,
      memberNumber: memberNumber ?? this.memberNumber,
      clubPoints: clubPoints ?? this.clubPoints,
      yearlyPoints: yearlyPoints ?? this.yearlyPoints,
    );
  }
}
