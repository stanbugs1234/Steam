import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { member, admin }

enum UserStatus { pending, approved, denied }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String kidName;
  final String kidGrade;
  final String? photoUrl;
  final UserRole role;
  final UserStatus status;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.kidName,
    required this.kidGrade,
    this.photoUrl,
    required this.role,
    required this.status,
    this.createdAt,
  });

  bool get isApproved => status == UserStatus.approved;
  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      kidName: data['kidName'] as String? ?? '',
      kidGrade: data['kidGrade'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      role: (data['role'] as String?) == 'admin' ? UserRole.admin : UserRole.member,
      status: _statusFromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
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
      'kidName': kidName,
      'kidGrade': kidGrade,
      'photoUrl': photoUrl,
      'role': role.name,
      'status': status.name,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? kidName,
    String? kidGrade,
    String? photoUrl,
    UserRole? role,
    UserStatus? status,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      kidName: kidName ?? this.kidName,
      kidGrade: kidGrade ?? this.kidGrade,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
