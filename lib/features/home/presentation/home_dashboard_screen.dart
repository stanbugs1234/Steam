import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/section_card.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../news/domain/news_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';

/// Landing tab: a greeting plus at-a-glance, personalized summaries, so
/// opening the app feels like arriving at the club rather than straight into
/// a raw feed.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key, required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).value;
    final isAdmin = appUser?.isAdmin ?? false;
    final eventsAsync = ref.watch(eventsProvider);
    final newsAsync = ref.watch(newsFeedProvider);
    final commitmentsAsync = ref.watch(myCommitmentsProvider);
    final now = DateTime.now();

    // Only block the data-dependent sections on a true first load — once a
    // stream has ever delivered data, later live updates shouldn't re-flash
    // it. The scaffold, greeting and quick actions never wait on this: a
    // slow first connection (e.g. a fresh install with no offline cache)
    // should still show something, not a blank page with no chrome at all.
    final isInitialLoading =
        (eventsAsync.isLoading && !eventsAsync.hasValue) || (newsAsync.isLoading && !newsAsync.hasValue);

    final firstName = (appUser?.name.trim().isNotEmpty ?? false) ? appUser!.name.trim().split(' ').first : null;

    final upcomingEvents = (eventsAsync.value ?? const [])
        .where((e) => e.endTime.isAfter(now))
        .sortedBy((e) => e.startTime);
    final nextEvent = upcomingEvents.firstOrNull;
    final volunteersNeededCount = upcomingEvents.where((e) => e.needsVolunteers).length;

    final upcomingCommitments = (commitmentsAsync.value ?? const [])
        .where((c) => c.event.endTime.isAfter(now))
        .sortedBy((c) => c.event.startTime);

    // Only admins are allowed to query pending users — security rules deny
    // this query outright for everyone else, so only watch it when it can
    // actually succeed.
    final pendingCount = isAdmin ? (ref.watch(pendingUsersProvider).value?.length ?? 0) : 0;

    final recentPosts = (newsAsync.value ?? const []).take(3).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            firstName != null ? 'Welcome back, $firstName' : 'Welcome back',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s what\'s happening with STEAM Club.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.article_outlined,
                  label: 'News',
                  onTap: () => onNavigateToTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.calendar_today_outlined,
                  label: 'Events',
                  onTap: () => onNavigateToTab(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Volunteer',
                  onTap: () => onNavigateToTab(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.people_outline,
                  label: 'Directory',
                  onTap: () => onNavigateToTab(4),
                ),
              ),
            ],
          ),
          if (isInitialLoading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (isAdmin && pendingCount > 0) ...[
              const SizedBox(height: 24),
              SectionCard(
                title: 'Pending Approvals',
                icon: Icons.fact_check_outlined,
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    title: Text(
                      pendingCount == 1
                          ? '1 request waiting for review'
                          : '$pendingCount requests waiting for review',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/admin/approvals'),
                  ),
                ],
              ),
            ],
            if (upcomingCommitments.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionCard(
                title: 'Your Volunteer Shifts',
                icon: Icons.event_available_outlined,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < upcomingCommitments.length && i < 3; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(upcomingCommitments[i].event.title),
                      subtitle: Text(
                        '${upcomingCommitments[i].slot.label} · '
                        '${DateFormat.MMMEd().add_jm().format(upcomingCommitments[i].event.startTime)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/events/${upcomingCommitments[i].event.id}'),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (nextEvent != null)
              SectionCard(
                title: 'Next Event',
                icon: Icons.calendar_today_outlined,
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    title: Text(nextEvent.title),
                    subtitle: Text(DateFormat.MMMEd().add_jm().format(nextEvent.startTime)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/events/${nextEvent.id}'),
                  ),
                ],
              )
            else
              SectionCard(
                title: 'Next Event',
                icon: Icons.calendar_today_outlined,
                padding: EdgeInsets.zero,
                children: const [
                  ListTile(title: Text('No upcoming events right now.')),
                ],
              ),
            if (volunteersNeededCount > 0) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: 'Volunteers Needed',
                icon: Icons.volunteer_activism_outlined,
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    title: Text(
                      volunteersNeededCount == 1
                          ? '1 upcoming event could use your help'
                          : '$volunteersNeededCount upcoming events could use your help',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onNavigateToTab(2),
                  ),
                ],
              ),
            ],
            if (recentPosts.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: 'Latest News',
                icon: Icons.article_outlined,
                padding: EdgeInsets.zero,
                trailing: TextButton(
                  onPressed: () => onNavigateToTab(1),
                  child: const Text('See all'),
                ),
                children: [
                  for (var i = 0; i < recentPosts.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(recentPosts[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(recentPosts[i].body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/news/${recentPosts[i].id}'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
