import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/app_user.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef => _firestore.collection('users');

  Future<void> createProfile(AppUser user) {
    return _usersRef.doc(user.uid).set(user.toFirestore());
  }

  Stream<AppUser?> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc.id, doc.data()!);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.id, doc.data()!);
  }

  Stream<List<AppUser>> watchPendingUsers() {
    return _usersRef
        .where('status', isEqualTo: UserStatus.pending.name)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<AppUser>> watchApprovedMembers() {
    return _usersRef
        .where('status', isEqualTo: UserStatus.approved.name)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList());
  }

  Future<void> setStatus(String uid, UserStatus status) {
    return _usersRef.doc(uid).update({'status': status.name});
  }

  Future<void> setRole(String uid, UserRole role) {
    return _usersRef.doc(uid).update({'role': role.name});
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) {
    return _usersRef.doc(uid).update(fields);
  }
}
