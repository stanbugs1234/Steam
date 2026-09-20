import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/top_volunteer_badge.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/volunteer_providers.dart';

/// Every approved member with logged volunteer hours, ranked highest first.
class VolunteerLeaderboardScreen extends ConsumerWidget {
  const VolunteerLeaderboardScreen({super.key});

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(volunteerLeaderboardProvider);
    final hoursAsync = ref.watch(volunteerHoursProvider);
    final membersAsync = ref.watch(approvedMembersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // "No hours logged yet" must only be said once the data has really loaded.
    final loading =
        (hoursAsync.isLoading && !hoursAsync.hasValue) ||
        (membersAsync.isLoading && !membersAsync.hasValue);
    final failure = (hoursAsync.hasError && !hoursAsync.hasValue)
        ? hoursAsync.error
        : (membersAsync.hasError && !membersAsync.hasValue
              ? membersAsync.error
              : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Volunteer Leaderboard')),
      body: failure != null
          ? ErrorState(
              message: "Couldn't load the leaderboard.",
              error: failure,
              onRetry: () {
                ref.invalidate(pastVolunteerEventsProvider);
                ref.invalidate(approvedMembersProvider);
              },
            )
          : loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? const EmptyState(
              icon: Icons.emoji_events_outlined,
              message: 'No volunteer hours logged yet.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final rank = index + 1;
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: entry.member.photoUrl != null
                          ? avatarImage(entry.member.photoUrl!, 22)
                          : null,
                      child: entry.member.photoUrl == null
                          ? Text(
                              _initials(entry.member.name),
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Text(
                          '$rank. ',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text(
                            entry.member.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rank <= 3) ...[
                          const SizedBox(width: 8),
                          const TopVolunteerBadge(),
                        ],
                      ],
                    ),
                    subtitle: Text('${entry.hours.toStringAsFixed(1)} hrs'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/directory/${entry.member.uid}'),
                  ),
                );
              },
            ),
    );
  }
}
