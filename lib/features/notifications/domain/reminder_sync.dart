import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../data/reminder_service.dart';
import 'notification_providers.dart';

/// Keeps this device's reminders in step with the member's volunteer
/// sign-ups, the club's upcoming events, and their reminders preference.
/// Watched once by the signed-in shell; it recomputes whenever a sign-up, an
/// event's time, or the preference changes.
final reminderSyncProvider = Provider<void>((ref) {
  final me = ref.watch(currentAppUserProvider).valueOrNull;
  if (me == null || !me.isApproved) return;

  // Wait for both reads to actually load: acting on "loading" or an error as
  // if it meant "nothing" would wipe the member's reminders.
  final commitments = ref.watch(myCommitmentsProvider).valueOrNull;
  final events = ref.watch(eventsProvider).valueOrNull;
  if (commitments == null || events == null) return;

  final targets = <ReminderTarget>[];
  if (me.remindersEnabled) {
    for (final c in commitments) {
      targets.add(
        ReminderTarget(
          eventId: c.event.id,
          slotId: c.slot.id,
          eventTitle: c.event.title,
          slotLabel: c.slot.label,
          eventStart: c.event.startTime,
        ),
      );
    }
    // A shift reminder already covers the event that day — a second, generic
    // "event tomorrow" notification for the same event would be redundant.
    final shiftEventIds = commitments.map((c) => c.event.id).toSet();
    final now = DateTime.now();
    for (final event in events) {
      if (shiftEventIds.contains(event.id)) continue;
      if (!event.startTime.isAfter(now)) continue;
      targets.add(
        ReminderTarget(eventId: event.id, eventTitle: event.title, eventStart: event.startTime),
      );
    }
  }

  unawaited(
    ref.read(reminderServiceProvider).syncReminders(targets).catchError((Object _) {
      // Best-effort: a scheduling failure (no permission, platform hiccup)
      // shouldn't surface anywhere; the next change retries.
    }),
  );
});
