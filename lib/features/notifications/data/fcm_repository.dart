import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Registers this device for push notifications: requests permission, keeps
/// this device's FCM token in Firestore (`users/{uid}/fcmTokens/{token}`) in
/// step, and manages topic subscriptions for broadcast-style alerts (a new
/// event or news post, a volunteer spot opening up, an admin alert). A
/// personal alert (e.g. "you've been approved") is sent straight to a token
/// instead, server-side — this repository just keeps the token published.
class FcmRepository {
  FcmRepository(this._messaging, this._firestore);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Prompts for notification permission. Safe to call more than once — the
  /// OS only shows the real prompt the first time either platform asks, and
  /// this is the same underlying permission `ReminderService` already
  /// requests for local reminders, so a member who already granted it there
  /// won't see a second prompt.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getToken() async {
    if (!_supported) return null;
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Fires whenever the OS rotates this device's token, so it never goes
  /// stale in Firestore.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<void> upsertToken(String uid, String token) {
    return _tokenDoc(uid, token).set({
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _tokenDoc(String uid, String token) {
    return _firestore.collection('users').doc(uid).collection('fcmTokens').doc(token);
  }

  Future<void> subscribeToTopic(String topic) async {
    if (!_supported) return;
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_supported) return;
    await _messaging.unsubscribeFromTopic(topic);
  }
}
