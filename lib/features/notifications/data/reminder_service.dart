import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const _channelId = 'volunteer_reminders';
const _channelName = 'Volunteer reminders';
const _channelDescription = 'Reminders for volunteer shifts you signed up for.';
const _reminderLead = Duration(hours: 24);

/// Schedules and cancels on-device reminders for volunteer shifts a member
/// has personally signed up for. Mobile-only — matches the
/// `!kIsWeb && (Platform.isIOS || Platform.isAndroid)` guard already used for
/// "Add to Contacts" in member_detail_screen.dart, since neither local
/// notifications nor a meaningful permission model exist on web/desktop here.
class ReminderService {
  ReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> _ensureInitialized() async {
    if (_initialized || !_supported) return;

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Fall back to whatever the timezone package defaults to (UTC) rather
      // than failing to schedule a reminder entirely over a timezone lookup.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Prompts for notification permission. Safe to call more than once —
  /// the OS only shows the real prompt the first time either platform asks.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await _ensureInitialized();

    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }

    final granted = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  Future<void> scheduleVolunteerReminder({
    required String eventId,
    required String slotId,
    required String eventTitle,
    required String slotLabel,
    required DateTime eventStart,
  }) async {
    if (!_supported) return;

    final fireTime = reminderFireTime(eventStart);
    if (fireTime == null) return;

    await _ensureInitialized();
    if (!_initialized) return;

    await _plugin.zonedSchedule(
      id: stableNotificationId(eventId, slotId),
      title: 'Volunteer shift tomorrow',
      body: '$eventTitle · $slotLabel',
      scheduledDate: tz.TZDateTime.from(fireTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Makes the device's scheduled reminders match [targets] exactly: schedules
  /// (or re-schedules, so a moved event keeps the right time and title) every
  /// target, and cancels any scheduled reminder that no longer corresponds to
  /// one — a shift the member left, an event or slot an admin deleted, or all
  /// of them when reminders are switched off. Reminders are local to a device,
  /// so this is also what restores them after a reinstall or on a new phone.
  Future<void> syncVolunteerReminders(List<ReminderTarget> targets) async {
    if (!_supported) return;
    await _ensureInitialized();
    if (!_initialized) return;

    final wanted = {
      for (final t in targets)
        if (reminderFireTime(t.eventStart) != null) t.id,
    };
    final pending = await _plugin.pendingNotificationRequests();
    for (final id in staleReminderIds(pending: pending.map((p) => p.id), desired: wanted)) {
      await _plugin.cancel(id: id);
    }
    for (final t in targets) {
      await scheduleVolunteerReminder(
        eventId: t.eventId,
        slotId: t.slotId,
        eventTitle: t.eventTitle,
        slotLabel: t.slotLabel,
        eventStart: t.eventStart,
      );
    }
  }

  Future<void> cancelVolunteerReminder(String eventId, String slotId) async {
    if (!_supported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: stableNotificationId(eventId, slotId));
  }
}

/// Pure function so the 24h-before math is unit-testable without a platform
/// channel. Returns null when there's nothing useful left to remind about
/// (the lead time has already passed by the time of signup).
DateTime? reminderFireTime(DateTime eventStart, {Duration lead = _reminderLead}) {
  final fireTime = eventStart.subtract(lead);
  return fireTime.isAfter(DateTime.now()) ? fireTime : null;
}

/// Deterministic 32-bit id derived from (eventId, slotId) so the same
/// signup always maps to the same notification id and can be cancelled
/// later purely from those two strings, without keeping any extra state.
/// Uses FNV-1a rather than String.hashCode, which Dart does not guarantee
/// to be stable across SDK versions or platforms.
int stableNotificationId(String eventId, String slotId) {
  const fnvPrime = 0x01000193;
  var hash = 0x811c9dc5;
  for (final code in '$eventId|$slotId'.codeUnits) {
    hash ^= code;
    hash = (hash * fnvPrime) & 0x7fffffff;
  }
  return hash;
}

/// One volunteer shift a member should be reminded about.
class ReminderTarget {
  const ReminderTarget({
    required this.eventId,
    required this.slotId,
    required this.eventTitle,
    required this.slotLabel,
    required this.eventStart,
  });

  final String eventId;
  final String slotId;
  final String eventTitle;
  final String slotLabel;
  final DateTime eventStart;

  int get id => stableNotificationId(eventId, slotId);
}

/// The scheduled reminder ids that should be cancelled because nothing wants
/// them any more. Pure so the reconciliation rule is unit-testable.
Set<int> staleReminderIds({required Iterable<int> pending, required Iterable<int> desired}) {
  return pending.toSet().difference(desired.toSet());
}
