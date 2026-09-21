import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/capacity_bar.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/club_event.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../notifications/domain/notification_providers.dart';
import '../domain/volunteer_providers.dart';
import '../domain/volunteer_seen.dart';

/// The Volunteer tab: the shifts you've signed up for, and the upcoming
/// events that still need volunteers, so you can find and join one without
/// hunting through the calendar.
class MyCommitmentsScreen extends ConsumerWidget {
  const MyCommitmentsScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, MyCommitment c, String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this shift?'),
        content: Text('${c.event.title} · ${c.slot.label}\nYour spot will open up for someone else.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Shift')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(volunteerRepositoryProvider).cancel(c.event.id, c.slot.id, uid);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: "Couldn't cancel that shift."))));
      return;
    }
    try {
      await ref.read(reminderServiceProvider).cancelVolunteerReminder(c.event.id, c.slot.id);
    } catch (_) {
      // Best-effort — the cancellation itself already succeeded above.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commitmentsAsync = ref.watch(myCommitmentsProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final myUid = ref.watch(currentAppUserProvider).value?.uid;
    final newEventIds = ref.watch(newVolunteerEventIdsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Volunteer')),
      body: commitmentsAsync.when(
        data: (commitments) {
          final myEventIds = {for (final c in commitments) c.event.id};
          final opportunities = (eventsAsync.value ?? const <ClubEvent>[])
              .where((e) => e.needsVolunteers && e.endTime.isAfter(now) && !myEventIds.contains(e.id))
              .sortedBy((e) => e.startTime);

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              SectionCard(
                title: 'My shifts',
                icon: Icons.event_available_outlined,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (commitments.isEmpty)
                    const _EmptyRow("You haven't signed up for a shift yet. Pick one below."),
                  for (var i = 0; i < commitments.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      onTap: () => context.push('/events/${commitments[i].event.id}'),
                      title: Text(commitments[i].event.title),
                      subtitle: Text(
                        '${commitments[i].slot.label} · '
                        '${DateFormat.MMMd().add_jm().format(commitments[i].event.startTime)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel shift',
                        onPressed: myUid == null ? null : () => _cancel(context, ref, commitments[i], myUid),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Needs volunteers',
                icon: Icons.volunteer_activism_outlined,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (opportunities.isEmpty) const _EmptyRow('Nothing needs volunteers right now. Check back soon!'),
                  for (var i = 0; i < opportunities.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _OpportunityTile(event: opportunities[i], isNew: newEventIds.contains(opportunities[i].id)),
                  ],
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: "Couldn't load volunteer opportunities.",
          error: err,
          onRetry: () => ref.invalidate(eventsProvider),
        ),
      ),
    );
  }
}

class _OpportunityTile extends ConsumerWidget {
  const _OpportunityTile({required this.event, required this.isNew});

  final ClubEvent event;

  /// Not opened yet: tagged "NEW" until the member views it.
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(eventVolunteerProgressProvider(event.id));

    return ListTile(
      onTap: () => context.push('/events/${event.id}'),
      title: Row(
        children: [
          Flexible(child: Text(event.title)),
          if (isNew) ...[const SizedBox(width: 8), const _NewTag()],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat.MMMEd().add_jm().format(event.startTime)),
          if (progress != null) ...[
            const SizedBox(height: 6),
            CapacityBar(filled: progress.filled, capacity: progress.capacity),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _NewTag extends StatelessWidget {
  const _NewTag();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
      child: Text(
        'NEW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
