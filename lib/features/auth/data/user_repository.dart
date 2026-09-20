import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/app_user.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef => _firestore.collection('users');

  Future<void> createProfile(AppUser user) {
    return _usersRef.doc(user.uid).set(user.toFirestore());
  }

  /// Creates a phone-verified member's profile that claims an unclaimed
  /// roster placeholder, and deletes that placeholder, as one atomic write —
  /// so a failure can't leave the member approved *and* their roster entry
  /// still sitting in the directory as a duplicate.
  Future<void> createProfileClaiming(AppUser user, String placeholderId) {
    final batch = _firestore.batch();
    batch.set(_usersRef.doc(user.uid), user.toFirestore());
    batch.delete(_usersRef.doc(placeholderId));
    return batch.commit();
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

  Future<void> deletePlaceholder(String docId) => _usersRef.doc(docId).delete();

  /// Deletes a member's own profile document (account deletion). The security
  /// rules only allow this for the signed-in member's own doc, or an admin.
  Future<void> deleteAccountDoc(String uid) => _usersRef.doc(uid).delete();

  /// Looks through [approved] members (real members and unclaimed `imported_*`
  /// roster placeholders alike) for one that shares a phone or email with
  /// [pendingUser], other than themselves. Phone numbers are compared by
  /// their last 10 digits so formatting differences (e.g. a roster import
  /// stored as "(555) 123-4567" vs. a signup's "+15551234567") still match.
  /// Takes the already-loaded member list so a queue of N pending requests
  /// doesn't cost N full-directory reads.
  static AppUser? findPossibleDuplicate(AppUser pendingUser, Iterable<AppUser> approved) {
    final normalizedPhone = _lastTenDigits(pendingUser.phone);
    final normalizedEmail = pendingUser.email.trim().toLowerCase();
    if (normalizedPhone.isEmpty && normalizedEmail.isEmpty) return null;

    for (final candidate in approved) {
      if (candidate.uid == pendingUser.uid) continue;
      final phoneMatches = normalizedPhone.isNotEmpty && normalizedPhone == _lastTenDigits(candidate.phone);
      final emailMatches = normalizedEmail.isNotEmpty && normalizedEmail == candidate.email.trim().toLowerCase();
      if (phoneMatches || emailMatches) return candidate;
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
      // The roster's own records live on the placeholder, which is deleted
      // below — carry them over or they're gone.
      'memberNumber': placeholder.memberNumber,
      'clubPoints': placeholder.clubPoints,
      'yearlyPoints': placeholder.yearlyPoints,
      'duesPaid': placeholder.duesPaid,
      'isNewMember': placeholder.isNewMember,
    };
    // Preserve the placeholder's original join date on merge — otherwise the
    // pending signup's own createdAt would overwrite it and lose their real
    // tenure with the club.
    if (placeholder.createdAt != null) {
      fields['createdAt'] = Timestamp.fromDate(placeholder.createdAt!);
    }

    // One atomic write: a failure between the two would leave the member
    // approved *and* a duplicate placeholder still in the directory (or, worse,
    // the placeholder gone with nothing carried over).
    final batch = _firestore.batch();
    batch.update(_usersRef.doc(pendingUser.uid), fields);
    batch.delete(_usersRef.doc(placeholder.uid));
    await batch.commit();
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

  /// Roster records the club maintains for a member. Passing null clears the
  /// value.
  Future<void> setMemberNumber(String uid, String? memberNumber) {
    return _usersRef.doc(uid).update({'memberNumber': memberNumber});
  }

  Future<void> setYearlyPoints(String uid, int? points) {
    return _usersRef.doc(uid).update({'yearlyPoints': points});
  }

  Future<void> setClubPoints(String uid, int? points) {
    return _usersRef.doc(uid).update({'clubPoints': points});
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) {
    return _usersRef.doc(uid).update(fields);
  }
}
