import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/club_event.dart';
import '../../attendance/domain/attendance_providers.dart';
import '../../auth/domain/auth_providers.dart';
import '../../volunteering/presentation/volunteer_slot_section.dart';
import '../domain/event_providers.dart';

/// Whether check-in can be started/shown right now — anyone can start
/// check-in for an event, but only within a window around its own time, so
/// this can't be used on a random past or far-future event. Mirrors the
/// Firestore rule (`isStartingCheckIn`) that actually enforces this.
bool _canUseCheckIn(ClubEvent event) {
  final now = DateTime.now();
  return now.isAfter(event.startTime.subtract(const Duration(minutes: 30))) &&
      now.isBefore(event.endTime.add(const Duration(hours: 2)));
}

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  Future<void> _startCheckInAndShowQr(BuildContext context, WidgetRef ref, ClubEvent event) async {
    if (!event.checkInEnabled) {
      try {
        await ref.read(attendanceRepositoryProvider).startCheckIn(event.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start check-in: $e')),
          );
        }
        return;
      }
    }
    if (context.mounted) context.push('/events/${event.id}/qr');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          eventsAsync.maybeWhen(
            data: (events) {
              final event = events.firstWhereOrNull((e) => e.id == eventId);
              if (event == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canUseCheckIn(event))
                    IconButton(
                      icon: const Icon(Icons.qr_code_2),
                      tooltip: 'Check-in QR',
                      onPressed: () => _startCheckInAndShowQr(context, ref, event),
                    ),
                  if (isAdmin) ...[
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
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Details',
                icon: Icons.info_outline,
                padding: EdgeInsets.zero,
                children: [
                  _InfoRow(icon: Icons.schedule_outlined, text: timeRange),
                  if (event.location.isNotEmpty) ...[
                    const Divider(height: 1),
                    _InfoRow(icon: Icons.place_outlined, text: event.location),
                  ],
                  if (event.needsVolunteers) ...[
                    const Divider(height: 1),
                    _InfoRow(icon: Icons.volunteer_activism_outlined, text: 'Volunteers needed for this event'),
                  ],
                ],
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Description',
                  icon: Icons.notes_outlined,
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(event.description, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ],
                ),
              ],
              if (event.needsVolunteers) ...[
                const SizedBox(height: 16),
                VolunteerSlotSection(event: event),
              ],
              if (event.checkInEnabled) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Attendance',
                  icon: Icons.qr_code_scanner,
                  padding: EdgeInsets.zero,
                  children: [
                    _InfoRow(
                      icon: Icons.how_to_reg_outlined,
                      text: '${event.checkedInUserIds.length} checked in',
                    ),
                  ],
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load this event.", error: err),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
