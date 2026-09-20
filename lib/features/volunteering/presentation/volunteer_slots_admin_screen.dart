import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/capacity_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../models/volunteer_slot.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/volunteer_providers.dart';
import '../../../core/widgets/confirm_dialog.dart';

class VolunteerSlotsAdminScreen extends ConsumerWidget {
  const VolunteerSlotsAdminScreen({super.key, required this.eventId});

  final String eventId;

  void _showError(BuildContext context, Object e, String fallback) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: fallback))));
  }

  Future<void> _showSlotDialog(BuildContext context, WidgetRef ref, {VolunteerSlot? existing}) async {
    final result = await showDialog<_SlotForm>(
      context: context,
      builder: (context) => _SlotDialog(existing: existing),
    );
    if (result == null) return;

    final repo = ref.read(volunteerRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createSlot(
          eventId,
          VolunteerSlot(
            id: repo.newSlotId(eventId),
            label: result.label,
            capacity: result.capacity,
            signedUpUserIds: const [],
          ),
        );
      } else {
        await repo.updateSlotDetails(eventId, existing.id, label: result.label, capacity: result.capacity);
      }
    } catch (e) {
      if (context.mounted) _showError(context, e, "Couldn't save this slot. Please try again.");
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, VolunteerSlot slot) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this slot?',
      message: slot.signedUpUserIds.isEmpty
          ? 'This cannot be undone.'
          : '${slot.signedUpUserIds.length} member(s) are signed up. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(volunteerRepositoryProvider).deleteSlot(eventId, slot.id);
    } catch (e) {
      if (context.mounted) _showError(context, e, "Couldn't delete this slot. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(eventSlotsProvider(eventId));
    final membersAsync = ref.watch(approvedMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Volunteer Slots')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'volunteer_slots_fab',
        onPressed: () => _showSlotDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: slotsAsync.when(
        data: (slots) {
          if (slots.isEmpty) {
            return const EmptyState(icon: Icons.volunteer_activism_outlined, message: 'No slots yet. Tap + to add one.');
          }
          final members = membersAsync.value ?? const [];
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final slot = slots[index];
              final names = slot.signedUpUserIds
                  .map((uid) => members.firstWhereOrNull((m) => m.uid == uid)?.name ?? 'Unknown member')
                  .toList();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(slot.label, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit slot',
                            onPressed: () => _showSlotDialog(context, ref, existing: slot),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete slot',
                            onPressed: () => _confirmDelete(context, ref, slot),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      CapacityBar(filled: slot.signedUpUserIds.length, capacity: slot.capacity),
                      if (names.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: names.map((n) => Chip(label: Text(n))).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load volunteer slots.", error: err),
      ),
    );
  }
}

class _SlotForm {
  const _SlotForm({required this.label, required this.capacity});

  final String label;
  final int capacity;
}

/// The add/edit slot dialog. Its own State owns the text controllers so they're
/// disposed with the dialog (after its exit animation), not while it's still
/// on screen.
class _SlotDialog extends StatefulWidget {
  const _SlotDialog({this.existing});

  final VolunteerSlot? existing;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _capacityCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.existing?.label ?? '');
    _capacityCtrl = TextEditingController(text: widget.existing?.capacity.toString() ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  String? _validateCapacity(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 1) return 'Enter a number of at least 1';
    // Lowering capacity below the people already signed up would leave the slot
    // "over full" with nobody able to cancel their way back under it.
    final signedUp = widget.existing?.signedUpUserIds.length ?? 0;
    if (n < signedUp) return '$signedUp people are already signed up';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? 'New Volunteer Slot' : 'Edit Slot'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(labelText: 'Label (e.g. Setup Crew)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityCtrl,
              decoration: const InputDecoration(labelText: 'Capacity'),
              keyboardType: TextInputType.number,
              validator: _validateCapacity,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _SlotForm(label: _labelCtrl.text.trim(), capacity: int.parse(_capacityCtrl.text.trim())),
              );
            }
          },
          child: Text(existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
