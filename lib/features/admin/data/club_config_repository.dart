import 'package:cloud_firestore/cloud_firestore.dart';

/// The club's shared settings document (`config/app`). Right now this only
/// holds the sign-up join code (see `ClubSettingsScreen`); readable by anyone,
/// including signed-out sign-up screens, so it can gate sign-up before an
/// account exists — writable by admins only.
class ClubConfigRepository {
  ClubConfigRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _appDoc => _firestore.collection('config').doc('app');

  /// The current join code, or null if the club hasn't set one (in which case
  /// sign-up skips the join-code step entirely).
  Stream<String?> watchJoinCode() {
    return _appDoc.snapshots().map((snap) {
      final value = snap.data()?['joinCode'];
      return value is String && value.trim().isNotEmpty ? value : null;
    });
  }

  Future<void> setJoinCode(String code) {
    return _appDoc.set({'joinCode': code.trim()}, SetOptions(merge: true));
  }
}
