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
  });

  bool get isApproved => status == UserStatus.approved;
  bool get isAdmin => role == UserRole.admin;
  int get kidCount => kids.length;

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      kids: _kidsFromFirestore(data),
      photoUrl: data['photoUrl'] as String?,
      role: (data['role'] as String?) == 'admin' ? UserRole.admin : UserRole.member,
      status: _statusFromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      mergedFromId: data['mergedFromId'] as String?,
      remindersEnabled: data['remindersEnabled'] as bool? ?? true,
    );
  }

  static List<ChildInfo> _kidsFromFirestore(Map<String, dynamic> data) {
    final kidsRaw = data['kids'];
    if (kidsRaw is List) {
      return kidsRaw.map((e) => ChildInfo.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }
    // Legacy docs stored a single child as separate kidName/kidGrade fields.
    final legacyName = data['kidName'] as String? ?? '';
    if (legacyName.isEmpty) return const [];
    return [ChildInfo(name: legacyName, grade: data['kidGrade'] as String? ?? '')];
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
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    List<ChildInfo>? kids,
    String? photoUrl,
    UserRole? role,
    UserStatus? status,
    bool? remindersEnabled,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      kids: kids ?? this.kids,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      mergedFromId: mergedFromId,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    );
  }
}
