import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_providers.dart';
import '../domain/event_providers.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          if (isAdmin)
            eventsAsync.maybeWhen(
              data: (events) {
                final event = events.firstWhereOrNull((e) => e.id == eventId);
                if (event == null) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push('/events/${event.id}/edit'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete event?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(eventRepositoryProvider).deleteEvent(event.id);
                          if (context.mounted) context.pop();
                        }
                      },
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          final event = events.firstWhereOrNull((e) => e.id == eventId);
          if (event == null) {
            return const Center(child: Text('Event not found.'));
          }
          final sameDay = DateFormat.yMd().format(event.startTime) == DateFormat.yMd().format(event.endTime);
          final timeRange = sameDay
              ? '${DateFormat.yMMMEd().format(event.startTime)} · '
                  '${DateFormat.jm().format(event.startTime)} – ${DateFormat.jm().format(event.endTime)}'
              : '${DateFormat.yMMMEd().add_jm().format(event.startTime)} – '
                  '${DateFormat.yMMMEd().add_jm().format(event.endTime)}';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.schedule_outlined, text: timeRange),
              if (event.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.place_outlined, text: event.location),
              ],
              if (event.needsVolunteers) ...[
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.volunteer_activism_outlined, text: 'Volunteers needed for this event'),
              ],
              const SizedBox(height: 20),
              if (event.description.isNotEmpty) Text(event.description, style: Theme.of(context).textTheme.bodyLarge),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading event: $err')),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
