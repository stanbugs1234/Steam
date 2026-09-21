import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/avatar_image.dart';
import '../../../core/widgets/capacity_bar.dart';
import '../../../core/widgets/member_badges.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../models/app_user.dart';
import '../../admin/presentation/pending_user_tile.dart';
import '../../attendance/domain/attendance_providers.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../news/domain/news_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../../volunteering/domain/volunteer_seen.dart';
import 'quick_actions.dart';

/// Landing tab: a greeting plus at-a-glance, personalized summaries, so
/// opening the app feels like arriving at the club rather than straight into
/// a raw feed.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key, required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).value;
    final isAdmin = appUser?.isAdmin ?? false;
    final isTopVolunteer = appUser != null && ref.watch(topVolunteerUidsProvider).contains(appUser.uid);
    final eventsAsync = ref.watch(eventsProvider);
    final newsAsync = ref.watch(newsFeedProvider);
    final commitmentsAsync = ref.watch(myCommitmentsProvider);
    final totalPoints = ref.watch(myPointsSummaryProvider).total;
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

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
    final newVolunteerCount = ref.watch(newVolunteerOpportunitiesProvider);
    final nextEventProgress =
        nextEvent != null && nextEvent.needsVolunteers ? ref.watch(eventVolunteerProgressProvider(nextEvent.id)) : null;

    final upcomingCommitments = (commitmentsAsync.value ?? const [])
        .where((c) => c.event.endTime.isAfter(now))
        .sortedBy((c) => c.event.startTime);

    // Only admins are allowed to query pending users — security rules deny
    // this query outright for everyone else, so only watch it when it can
    // actually succeed.
    final pendingUsers = isAdmin ? (ref.watch(pendingUsersProvider).value ?? const <AppUser>[]) : const <AppUser>[];

    final recentPosts = (newsAsync.value ?? const []).take(3).toList();
    final topVolunteers = ref.watch(volunteerLeaderboardProvider).take(3).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (appUser != null)
            _HomeHeader(
              appUser: appUser,
              isTopVolunteer: isTopVolunteer,
              firstName: firstName,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (appUser != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          icon: Icons.star_outline,
                          value: '$totalPoints',
                          label: totalPoints == 1 ? 'Point' : 'Points',
                          showChevron: true,
                          onTap: () => context.push('/my-points'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          icon: appUser.duesPaid ? Icons.check_circle_outline : Icons.cancel_outlined,
                          value: appUser.duesPaid ? 'Paid' : 'Not Paid',
                          label: 'Dues',
                          valueColor: appUser.duesPaid ? Colors.green.shade700 : colorScheme.error,
                          onTap: () => onNavigateToTab(5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          icon: Icons.calendar_today_outlined,
                          value: appUser.createdAt != null ? DateFormat('y').format(appUser.createdAt!) : '—',
                          label: 'Member since',
                          onTap: () => onNavigateToTab(5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                QuickActionGrid(
                  actions: [
                    QuickActionItem(icon: Icons.article_outlined, label: 'News', onTap: () => onNavigateToTab(1)),
                    QuickActionItem(icon: Icons.calendar_today_outlined, label: 'Events', onTap: () => onNavigateToTab(2)),
                    QuickActionItem(
                      icon: Icons.volunteer_activism_outlined,
                      label: 'Volunteer',
                      onTap: () => onNavigateToTab(3),
                      badgeCount: newVolunteerCount,
                    ),
                    QuickActionItem(icon: Icons.people_outline, label: 'Directory', onTap: () => onNavigateToTab(4)),
                    QuickActionItem(icon: Icons.qr_code_scanner, label: 'Check In', onTap: () => context.push('/checkin')),
                  ],
                ),
                if (isAdmin && pendingUsers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SectionCard(
                    title: pendingUsers.length == 1
                        ? 'Pending Approvals · 1 request'
                        : 'Pending Approvals · ${pendingUsers.length} requests',
                    icon: Icons.fact_check_outlined,
                    padding: EdgeInsets.zero,
                    trailing: TextButton(
                      onPressed: () => context.push('/admin/approvals'),
                      child: const Text('See all'),
                    ),
                    children: [
                      for (var i = 0; i < pendingUsers.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        PendingUserTile(key: ValueKey(pendingUsers[i].uid), user: pendingUsers[i]),
                      ],
                    ],
                  ),
                ],
                if (isInitialLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateFormat.MMMEd().add_jm().format(nextEvent.startTime)}'
                                '${nextEvent.location.isNotEmpty ? ' · ${nextEvent.location}' : ''}',
                              ),
                              if (nextEventProgress != null) ...[
                                const SizedBox(height: 6),
                                CapacityBar(filled: nextEventProgress.filled, capacity: nextEventProgress.capacity),
                              ],
                            ],
                          ),
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
                  if (topVolunteers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Top Volunteers',
                      icon: Icons.emoji_events_outlined,
                      padding: EdgeInsets.zero,
                      trailing: TextButton(
                        onPressed: () => context.push('/leaderboard'),
                        child: const Text('See all'),
                      ),
                      children: [
                        for (var i = 0; i < topVolunteers.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.primaryContainer,
                              backgroundImage: topVolunteers[i].member.photoUrl != null
                                  ? avatarImage(topVolunteers[i].member.photoUrl!, 18)
                                  : null,
                              child: topVolunteers[i].member.photoUrl == null
                                  ? Text(
                                      _initials(topVolunteers[i].member.name),
                                      style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12),
                                    )
                                  : null,
                            ),
                            title: Text(topVolunteers[i].member.name, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${topVolunteers[i].hours.toStringAsFixed(1)} hrs'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/directory/${topVolunteers[i].member.uid}'),
                          ),
                        ],
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
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: recentPosts[i].imageUrl != null
                                  ? Image(
                                      image: avatarImage(recentPosts[i].imageUrl!, 20),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: colorScheme.secondaryContainer,
                                      child: Icon(
                                        Icons.article_outlined,
                                        size: 20,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                            ),
                            title: Text(recentPosts[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${recentPosts[i].category.label} · ${recentPosts[i].body}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.appUser, required this.isTopVolunteer, required this.firstName});

  final AppUser appUser;
  final bool isTopVolunteer;
  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.surface,
              backgroundImage: appUser.photoUrl != null ? avatarImage(appUser.photoUrl!, 32) : null,
              child: appUser.photoUrl == null
                  ? Text(
                      HomeDashboardScreen._initials(appUser.name),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName != null ? 'Welcome back, $firstName' : 'Welcome back',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                ),
                if (MemberBadges.hasAny(appUser, isTopVolunteer)) ...[
                  const SizedBox(height: 8),
                  MemberBadges(user: appUser, isTopVolunteer: isTopVolunteer),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
