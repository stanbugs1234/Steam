import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/section_card.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../news/domain/news_providers.dart';

/// Landing tab: a greeting plus at-a-glance summaries, so opening the app
/// feels like arriving at the club rather than straight into a raw feed.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key, required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).value;
    final eventsAsync = ref.watch(eventsProvider);
    final newsAsync = ref.watch(newsFeedProvider);
    final now = DateTime.now();

    final firstName = (appUser?.name.trim().isNotEmpty ?? false) ? appUser!.name.trim().split(' ').first : null;

    final upcomingEvents = (eventsAsync.value ?? const [])
        .where((e) => e.endTime.isAfter(now))
        .sortedBy((e) => e.startTime);
    final nextEvent = upcomingEvents.firstOrNull;
    final volunteersNeededCount = upcomingEvents.where((e) => e.needsVolunteers).length;
    final latestPost = (newsAsync.value ?? const []).firstOrNull;

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
                        ? '1 upcoming event needs volunteers'
                        : '$volunteersNeededCount upcoming events need volunteers',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onNavigateToTab(2),
                ),
              ],
            ),
          ],
          if (latestPost != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Latest News',
              icon: Icons.article_outlined,
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  title: Text(latestPost.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(latestPost.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/news/${latestPost.id}'),
                ),
              ],
            ),
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
