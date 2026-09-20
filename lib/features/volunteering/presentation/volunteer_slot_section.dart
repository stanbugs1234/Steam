import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/avatar_image.dart';
import '../../../core/widgets/capacity_bar.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/app_user.dart';
import '../../../models/club_event.dart';
import '../../../models/volunteer_slot.dart';
import '../../auth/domain/auth_providers.dart';
import '../../notifications/domain/notification_providers.dart';
import '../data/volunteer_repository.dart';
import '../domain/volunteer_providers.dart';
import '../../../core/utils/friendly_error.dart';

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
    // uid -> member, so each task can list *who* signed up rather than just how
    // many. Null while the directory is still loading (or couldn't load), in
    // which case a task shows its count only.
    final members = ref.watch(approvedMembersProvider).valueOrNull;
    final membersByUid = members == null ? null : {for (final m in members) m.uid: m};

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
            final progress = ref.watch(eventVolunteerProgressProvider(eventId));
            return Column(
              children: [
                if (slots.length > 1 && progress != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: CapacityBar(filled: progress.filled, capacity: progress.capacity),
                  ),
                  const Divider(height: 1),
                ],
                for (var i = 0; i < slots.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SlotTile(
                    event: event,
                    slot: slots[i],
                    myUid: appUser?.uid,
                    remindersEnabled: appUser?.remindersEnabled ?? true,
                    membersByUid: membersByUid,
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
    required this.membersByUid,
  });

  final ClubEvent event;
  final VolunteerSlot slot;
  final String? myUid;
  final bool remindersEnabled;
  final Map<String, AppUser>? membersByUid;

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
        final joined = await repo.signUp(eventId, slotId, uid);
        // The reminder itself is scheduled by the reminder sync (it watches
        // the member's sign-ups), so all that's needed here is to make sure
        // the OS has been asked for notification permission — otherwise a
        // member who never opens the Profile switch would never get one.
        if (joined && widget.remindersEnabled) {
          try {
            await ref.read(reminderServiceProvider).requestPermission();
          } catch (_) {
            // Best-effort; the sign-up already succeeded.
          }
        }
      }
    } on SlotFullException {
      if (mounted) setState(() => _error = 'This slot just filled up.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final signedUp = widget.myUid != null && slot.signedUpUserIds.contains(widget.myUid);
    // Sign-up closes when the event ends (the Firestore rules enforce it too);
    // leaving a shift is always possible.
    final ended = widget.event.endTime.isBefore(DateTime.now());

    return ListTile(
      title: Text(slot.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: CapacityBar(filled: slot.signedUpUserIds.length, capacity: slot.capacity),
            ),
          if (slot.signedUpUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: VolunteerNames(
                uids: slot.signedUpUserIds,
                membersByUid: widget.membersByUid,
                myUid: widget.myUid,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'No one has signed up yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
      trailing: _working
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : (signedUp
              ? OutlinedButton(onPressed: () => _toggle(true), child: const Text('Cancel'))
              : FilledButton(
                  onPressed: (slot.isFull || ended) ? null : () => _toggle(false),
                  child: Text(ended ? 'Ended' : (slot.isFull ? 'Full' : 'Sign Up')),
                )),
    );
  }
}

/// The people signed up for one task, as tappable name chips (tap opens their
/// profile). Your own chip is marked "You". Someone whose account is gone shows
/// as "Former member" so the names still add up to the count on the capacity
/// bar. While the directory hasn't loaded, falls back to just the count.
class VolunteerNames extends StatelessWidget {
  const VolunteerNames({super.key, required this.uids, required this.membersByUid, required this.myUid});

  final List<String> uids;
  final Map<String, AppUser>? membersByUid;
  final String? myUid;

  static String _initial(String name) => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    final members = membersByUid;
    if (members == null) {
      return Text(
        '${uids.length} signed up',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final colors = Theme.of(context).colorScheme;
    final chips = <Widget>[];
    // Yourself first, then everyone else alphabetically.
    final ordered = [...uids]..sort((a, b) {
        if (a == myUid) return -1;
        if (b == myUid) return 1;
        return (members[a]?.name ?? '~').toLowerCase().compareTo((members[b]?.name ?? '~').toLowerCase());
      });

    for (final uid in ordered) {
      final member = members[uid];
      final isMe = uid == myUid;
      final name = member == null ? 'Former member' : (isMe ? '${member.name} (You)' : member.name);
      chips.add(
        ActionChip(
          visualDensity: VisualDensity.compact,
          avatar: CircleAvatar(
            backgroundColor: isMe ? colors.primary : colors.primaryContainer,
            backgroundImage: member?.photoUrl != null ? avatarImage(member!.photoUrl!, 12) : null,
            child: member?.photoUrl == null
                ? Text(
                    member == null ? '?' : _initial(member.name),
                    style: TextStyle(fontSize: 11, color: isMe ? colors.onPrimary : colors.onPrimaryContainer),
                  )
                : null,
          ),
          label: Text(name),
          tooltip: member == null ? null : 'View ${member.name}',
          onPressed: member == null ? null : () => context.push('/directory/$uid'),
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }
}
