import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../data/reminder_service.dart';
import 'notification_providers.dart';

/// Keeps this device's volunteer-shift reminders in step with what the member
/// is actually signed up for and their reminders preference. Watched once by
/// the signed-in shell; it recomputes whenever a sign-up, an event's time, or
/// the preference changes.
final reminderSyncProvider = Provider<void>((ref) {
  final me = ref.watch(currentAppUserProvider).valueOrNull;
  if (me == null || !me.isApproved) return;

  // Wait for the commitments to actually load: acting on "loading" or an
  // error as if it meant "no shifts" would wipe the member's reminders.
  final commitments = ref.watch(myCommitmentsProvider).valueOrNull;
  if (commitments == null) return;

  final targets = me.remindersEnabled
      ? [
          for (final c in commitments)
            ReminderTarget(
              eventId: c.event.id,
              slotId: c.slot.id,
              eventTitle: c.event.title,
              slotLabel: c.slot.label,
              eventStart: c.event.startTime,
            ),
        ]
      : const <ReminderTarget>[];

  unawaited(
    ref.read(reminderServiceProvider).syncVolunteerReminders(targets).catchError((Object _) {
      // Best-effort: a scheduling failure (no permission, platform hiccup)
      // shouldn't surface anywhere; the next change retries.
    }),
  );
});
