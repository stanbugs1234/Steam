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

  Future<AppUser?> findApprovedPlaceholderByPhone(String e164Phone) async {
    final snap = await _usersRef
        .where('phone', isEqualTo: e164Phone)
        .where('status', isEqualTo: UserStatus.approved.name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    if (!doc.id.startsWith('imported_')) return null;
    return AppUser.fromFirestore(doc.id, doc.data());
  }

  /// Mirrors [findApprovedPlaceholderByPhone] for the email signup path.
  /// Matched by exact string equality (not case-folded) since that's what the
  /// Firestore rule checks against `request.auth.token.email` too — if a
  /// roster entry's email casing doesn't match what the member types at
  /// signup, this just misses and they fall through to a normal pending
  /// signup rather than failing outright.
  Future<AppUser?> findApprovedPlaceholderByEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    final snap = await _usersRef
        .where('email', isEqualTo: trimmed)
        .where('status', isEqualTo: UserStatus.approved.name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    if (!doc.id.startsWith('imported_')) return null;
    return AppUser.fromFirestore(doc.id, doc.data());
  }

  Future<void> deletePlaceholder(String docId) => _usersRef.doc(docId).delete();

  /// Scans approved-status docs (real members and unclaimed `imported_*`
  /// roster placeholders alike) for one that shares a phone or email with
  /// [pendingUser], other than themselves. Phone numbers are compared by
  /// their last 10 digits so formatting differences (e.g. a roster import
  /// stored as "(555) 123-4567" vs. a signup's "+15551234567") still match.
  /// Only admins can call this — the security rules only let an admin read
  /// arbitrary users' docs, which this needs to check everyone, not just the
  /// pending user's own record.
  Future<AppUser?> findPossibleDuplicate(AppUser pendingUser) async {
    final normalizedPhone = _lastTenDigits(pendingUser.phone);
    final normalizedEmail = pendingUser.email.trim().toLowerCase();
    if (normalizedPhone.isEmpty && normalizedEmail.isEmpty) return null;

    final snap = await _usersRef.where('status', isEqualTo: UserStatus.approved.name).get();
    for (final doc in snap.docs) {
      if (doc.id == pendingUser.uid) continue;
      final data = doc.data();
      final candidatePhone = _lastTenDigits(data['phone'] as String? ?? '');
      final candidateEmail = ((data['email'] as String?) ?? '').trim().toLowerCase();
      final phoneMatches = normalizedPhone.isNotEmpty && normalizedPhone == candidatePhone;
      final emailMatches = normalizedEmail.isNotEmpty && normalizedEmail == candidateEmail;
      if (phoneMatches || emailMatches) {
        return AppUser.fromFirestore(doc.id, data);
      }
    }
    return null;
  }

  static String _lastTenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Copies roster data (kids, and email/phone if the new account left them
  /// blank) from an unclaimed `imported_*` placeholder into [pendingUser]'s
  /// own doc, approves them, and removes the now-redundant placeholder.
  ///
  /// Only ever safe for an unclaimed placeholder: unlike a placeholder, an
  /// already-claimed member doc is tied to a live Firebase Auth account that
  /// may still sign in later, so deleting it would silently orphan that
  /// account on its next sign-in instead of actually merging anything.
  Future<void> mergeAndApprove(AppUser pendingUser, AppUser placeholder) async {
    if (!placeholder.uid.startsWith('imported_')) {
      throw ArgumentError(
        'mergeAndApprove only supports merging from an unclaimed imported roster placeholder.',
      );
    }

    final fields = <String, dynamic>{
      'email': pendingUser.email.isNotEmpty ? pendingUser.email : placeholder.email,
      'phone': pendingUser.phone.isNotEmpty ? pendingUser.phone : placeholder.phone,
      'kids': (pendingUser.kids.isNotEmpty ? pendingUser.kids : placeholder.kids)
          .map((k) => k.toMap())
          .toList(),
      'status': UserStatus.approved.name,
      'mergedFromId': placeholder.uid,
    };
    // Preserve the placeholder's original join date on merge — otherwise the
    // pending signup's own createdAt would overwrite it and lose their real
    // tenure with the club.
    if (placeholder.createdAt != null) {
      fields['createdAt'] = Timestamp.fromDate(placeholder.createdAt!);
    }

    await updateProfile(pendingUser.uid, fields);
    await deletePlaceholder(placeholder.uid);
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

  Future<void> setCreatedAt(String uid, DateTime date) {
    return _usersRef.doc(uid).update({'createdAt': Timestamp.fromDate(date)});
  }

  Future<void> setDuesPaid(String uid, bool paid) {
    return _usersRef.doc(uid).update({'duesPaid': paid});
  }

  Future<void> setIsNewMember(String uid, bool isNewMember) {
    return _usersRef.doc(uid).update({'isNewMember': isNewMember});
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) {
    return _usersRef.doc(uid).update(fields);
  }
}
