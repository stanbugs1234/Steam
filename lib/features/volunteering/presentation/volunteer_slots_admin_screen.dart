import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _showSlotDialog(BuildContext context, WidgetRef ref, {VolunteerSlot? existing}) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final capacityCtrl = TextEditingController(text: existing?.capacity.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'New Volunteer Slot' : 'Edit Slot'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Label (e.g. Setup Crew)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: capacityCtrl,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Enter a number of at least 1';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final repo = ref.read(volunteerRepositoryProvider);
    final label = labelCtrl.text.trim();
    final capacity = int.parse(capacityCtrl.text.trim());
    if (existing == null) {
      await repo.createSlot(
        eventId,
        VolunteerSlot(id: repo.newSlotId(eventId), label: label, capacity: capacity, signedUpUserIds: const []),
      );
    } else {
      await repo.updateSlotDetails(eventId, existing.id, label: label, capacity: capacity);
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
    if (confirmed) {
      await ref.read(volunteerRepositoryProvider).deleteSlot(eventId, slot.id);
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
