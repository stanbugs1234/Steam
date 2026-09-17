import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/capacity_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/club_event.dart';
import '../../../models/volunteer_slot.dart';
import '../../auth/domain/auth_providers.dart';
import '../../notifications/domain/notification_providers.dart';
import '../data/volunteer_repository.dart';
import '../domain/volunteer_providers.dart';

/// Shown on an event's detail screen: lets members sign up/cancel for
/// volunteer slots, and gives admins a shortcut to manage the slots.
class VolunteerSlotSection extends ConsumerWidget {
  const VolunteerSlotSection({super.key, required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = event.id;
    final slotsAsync = ref.watch(eventSlotsProvider(eventId));
    final appUser = ref.watch(currentAppUserProvider).value;
    final isAdmin = appUser?.isAdmin ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'Volunteer Slots',
      icon: Icons.volunteer_activism_outlined,
      padding: EdgeInsets.zero,
      trailing: isAdmin
          ? TextButton.icon(
              onPressed: () => context.push('/events/$eventId/slots'),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Manage'),
            )
          : null,
      children: [
        slotsAsync.when(
          data: (slots) {
            if (slots.isEmpty) {
              return const ListTile(title: Text('No volunteer slots have been set up for this event yet.'));
            }
            return Column(
              children: [
                for (var i = 0; i < slots.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SlotTile(
                    event: event,
                    slot: slots[i],
                    myUid: appUser?.uid,
                    remindersEnabled: appUser?.remindersEnabled ?? true,
                  ),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => ListTile(
            leading: Icon(Icons.error_outline, color: colorScheme.error),
            title: const Text("Couldn't load volunteer slots."),
          ),
        ),
      ],
    );
  }
}

class _SlotTile extends ConsumerStatefulWidget {
  const _SlotTile({
    required this.event,
    required this.slot,
    required this.myUid,
    required this.remindersEnabled,
  });

  final ClubEvent event;
  final VolunteerSlot slot;
  final String? myUid;
  final bool remindersEnabled;

  @override
  ConsumerState<_SlotTile> createState() => _SlotTileState();
}

class _SlotTileState extends ConsumerState<_SlotTile> {
  bool _working = false;
  String? _error;

  Future<void> _toggle(bool signedUp) async {
    final uid = widget.myUid;
    if (uid == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final repo = ref.read(volunteerRepositoryProvider);
      final eventId = widget.event.id;
      final slotId = widget.slot.id;
      if (signedUp) {
        await repo.cancel(eventId, slotId, uid);
      } else {
        await repo.signUp(eventId, slotId, uid);
      }
      // Scheduling/cancelling the local reminder is best-effort: the sign-up
      // itself already succeeded above, so a reminder failure (e.g. no
      // notification permission) shouldn't surface as a sign-up error.
      try {
        final reminders = ref.read(reminderServiceProvider);
        if (signedUp) {
          await reminders.cancelVolunteerReminder(eventId, slotId);
        } else if (widget.remindersEnabled) {
          await reminders.scheduleVolunteerReminder(
            eventId: eventId,
            slotId: slotId,
            eventTitle: widget.event.title,
            slotLabel: widget.slot.label,
            eventStart: widget.event.startTime,
          );
        }
      } catch (_) {
        // Ignore — see comment above.
      }
    } on SlotFullException {
      setState(() => _error = 'This slot just filled up.');
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final signedUp = widget.myUid != null && slot.signedUpUserIds.contains(widget.myUid);

    return ListTile(
      title: Text(slot.label),
      subtitle: _error != null
          ? Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: CapacityBar(filled: slot.signedUpUserIds.length, capacity: slot.capacity),
            ),
      trailing: _working
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : (signedUp
              ? OutlinedButton(onPressed: () => _toggle(true), child: const Text('Cancel'))
              : FilledButton(
                  onPressed: slot.isFull ? null : () => _toggle(false),
                  child: Text(slot.isFull ? 'Full' : 'Sign Up'),
                )),
    );
  }
}
