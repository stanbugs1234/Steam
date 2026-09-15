import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/volunteer_slot.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/volunteer_repository.dart';
import '../domain/volunteer_providers.dart';

/// Shown on an event's detail screen: lets members sign up/cancel for
/// volunteer slots, and gives admins a shortcut to manage the slots.
class VolunteerSlotSection extends ConsumerWidget {
  const VolunteerSlotSection({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(eventSlotsProvider(eventId));
    final appUser = ref.watch(currentAppUserProvider).value;
    final isAdmin = appUser?.isAdmin ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Volunteer Slots', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (isAdmin)
              TextButton.icon(
                onPressed: () => context.push('/events/$eventId/slots'),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Manage'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        slotsAsync.when(
          data: (slots) {
            if (slots.isEmpty) {
              return const Text('No volunteer slots have been set up for this event yet.');
            }
            return Column(
              children: slots.map((slot) => _SlotTile(eventId: eventId, slot: slot, myUid: appUser?.uid)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Error loading slots: $err'),
        ),
      ],
    );
  }
}

class _SlotTile extends ConsumerStatefulWidget {
  const _SlotTile({required this.eventId, required this.slot, required this.myUid});

  final String eventId;
  final VolunteerSlot slot;
  final String? myUid;

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
      if (signedUp) {
        await repo.cancel(widget.eventId, widget.slot.id, uid);
      } else {
        await repo.signUp(widget.eventId, widget.slot.id, uid);
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(slot.label),
        subtitle: Text(
          _error ?? (slot.isFull ? 'Full' : '${slot.spotsLeft} of ${slot.capacity} spots left'),
          style: _error != null ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
        ),
        trailing: _working
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : (signedUp
                ? OutlinedButton(onPressed: () => _toggle(true), child: const Text('Cancel'))
                : FilledButton(
                    onPressed: slot.isFull ? null : () => _toggle(false),
                    child: Text(slot.isFull ? 'Full' : 'Sign Up'),
                  )),
      ),
    );
  }
}
