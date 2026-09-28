import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/reminder_service.dart' show stableNotificationId;
import 'fcm_providers.dart';
import 'notification_providers.dart';

const topicAnnouncements = 'announcements';
const topicVolunteerOpenings = 'volunteer-openings';
const topicAdminAlerts = 'admin-alerts';
const _allTopics = [topicAnnouncements, topicVolunteerOpenings, topicAdminAlerts];

/// Fires whenever the OS rotates this device's FCM token, so [fcmSyncProvider]
/// re-publishes it.
final fcmTokenRefreshProvider = StreamProvider<String>((ref) {
  return ref.watch(fcmRepositoryProvider).onTokenRefresh;
});

/// Keeps this device registered for push notifications: requests permission,
/// keeps its FCM token published to Firestore, and keeps its topic
/// subscriptions in step with the member's approval status and role (an
/// admin also gets `admin-alerts`; anyone no longer approved is unsubscribed
/// from everything). Watched once by the signed-in shell, alongside
/// `reminderSyncProvider`.
final fcmSyncProvider = Provider<void>((ref) {
  final me = ref.watch(currentAppUserProvider).valueOrNull;
  final repo = ref.watch(fcmRepositoryProvider);
  // Re-run whenever the token rotates, so the new one gets published too.
  ref.watch(fcmTokenRefreshProvider);

  final approved = me != null && me.isApproved;
  final desired = approved
      ? [topicAnnouncements, topicVolunteerOpenings, if (me.isAdmin) topicAdminAlerts]
      : const <String>[];

  unawaited(
    () async {
      for (final topic in _allTopics) {
        if (desired.contains(topic)) {
          await repo.subscribeToTopic(topic);
        } else {
          await repo.unsubscribeFromTopic(topic);
        }
      }
      if (!approved) return;

      final granted = await repo.requestPermission();
      if (!granted) return;
      final token = await repo.getToken();
      if (token != null) await repo.upsertToken(me.uid, token);
    }().catchError((Object _) {
      // Best-effort, same as reminderSyncProvider — the next change retries.
    }),
  );
});

/// Where a push notification's payload should send the member when they tap
/// it. Kept free of Riverpod/Firebase Messaging types so the mapping itself
/// is unit-testable.
@visibleForTesting
String? routeForPushData(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'event':
    case 'volunteer-opening':
      final eventId = data['eventId'];
      return eventId is String ? '/events/$eventId' : null;
    case 'news':
      final postId = data['postId'];
      return postId is String ? '/news/$postId' : null;
    case 'pending':
      return '/admin/approvals';
    case 'approved':
      return '/home';
    default:
      return null;
  }
}

/// Shows a foreground push alert as a local notification (most platforms
/// don't surface a system banner for a remote message while the app is
/// open), and sends a tapped notification — whether the app was foregrounded,
/// backgrounded, or launched fresh from it — to the right screen. Watched
/// once by the signed-in shell.
final fcmMessageHandlingProvider = Provider<void>((ref) {
  final repo = ref.watch(fcmRepositoryProvider);
  final reminders = ref.watch(reminderServiceProvider);

  void openFor(RemoteMessage message) {
    final route = routeForPushData(message.data);
    if (route != null) ref.read(routerProvider).go(route);
  }

  final subs = [
    repo.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      unawaited(
        reminders.showNow(
          id: stableNotificationId(message.messageId ?? notification.hashCode.toString()),
          title: notification.title ?? 'STEAM Club',
          body: notification.body ?? '',
        ),
      );
    }),
    repo.onMessageOpenedApp.listen(openFor),
  ];

  repo.getInitialMessage().then((message) {
    if (message != null) openFor(message);
  });

  ref.onDispose(() {
    for (final sub in subs) {
      sub.cancel();
    }
  });
});
