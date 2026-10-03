import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../directory/domain/directory_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../domain/dashboard_providers.dart';

/// Directory tab index and Events tab index within `HomeShell`'s bottom nav,
/// per its `_tabBuilders`/`NavigationDestination` order.
const _directoryTabIndex = 4;
const _eventsTabIndex = 2;

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// The club as a whole, rather than "what's next for me" (that's Home's
/// job): a few headline totals, the volunteer and points leaderboards in
/// full, and how membership has grown over the last few months.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.onNavigateToTab});

  /// Switches the bottom-nav tab in the enclosing `HomeShell` (a KPI card's
  /// destination is another tab, not a new route).
  final void Function(int index) onNavigateToTab;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _volunteerLeaderboardKey = GlobalKey();

  void _goToDirectory({DuesFilter duesFilter = DuesFilter.any}) {
    ref.read(directorySearchProvider.notifier).state = '';
    ref.read(directoryGradeFilterProvider.notifier).state = null;
    ref.read(directoryNewMemberFilterProvider.notifier).state = false;
    ref.read(directoryDuesFilterProvider.notifier).state = duesFilter;
    widget.onNavigateToTab(_directoryTabIndex);
  }

  void _goToUpcomingEvents() {
    ref.read(eventsJumpToUpcomingProvider.notifier).state++;
    widget.onNavigateToTab(_eventsTabIndex);
  }

  void _scrollToVolunteerLeaderboard() {
    final context = _volunteerLeaderboardKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(clubTotalsProvider);
    final volunteerEntries = ref.watch(volunteerLeaderboardProvider);
    final pointsEntries = ref.watch(pointsLeaderboardProvider);
    final monthly = ref.watch(newMembersByMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.people_outline,
                        value: '${totals.memberCount}',
                        label: 'Members',
                        onTap: () => _goToDirectory(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.check_circle_outline,
                        value: '${totals.duesPaidCount}',
                        label: 'Dues Paid',
                        onTap: () => _goToDirectory(duesFilter: DuesFilter.paidOnly),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.calendar_today_outlined,
                        value: '${totals.upcomingEventCount}',
                        label: totals.upcomingEventCount == 1 ? 'Upcoming Event' : 'Upcoming Events',
                        onTap: _goToUpcomingEvents,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.volunteer_activism_outlined,
                        value: totals.volunteerHours.toStringAsFixed(0),
                        label: 'Volunteer Hours',
                        onTap: _scrollToVolunteerLeaderboard,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Membership Growth',
            icon: Icons.trending_up,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: _MonthlyBarChart(months: monthly),
              ),
            ],
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: _volunteerLeaderboardKey,
            child: _LeaderboardCard(
              title: 'Volunteer Leaderboard',
              icon: Icons.volunteer_activism_outlined,
              emptyMessage: 'No volunteer hours logged yet.',
              entries: [for (final e in volunteerEntries) RankedMember(member: e.member, value: e.hours)],
              suffix: 'hrs',
            ),
          ),
          const SizedBox(height: 20),
          _LeaderboardCard(
            title: 'Points Leaderboard',
            icon: Icons.star_outline,
            emptyMessage: 'No points recorded yet.',
            entries: pointsEntries,
            suffix: 'pts',
          ),
        ],
      ),
    );
  }
}

/// A ranked list of members, styled identically whether it's showing hours or
/// points — the top 3 get the same trophy treatment either way, so the two
/// leaderboards read as one system rather than two different widgets.
class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.entries,
    required this.suffix,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<RankedMember> entries;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      icon: icon,
      padding: EdgeInsets.zero,
      children: [
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(icon: icon, message: emptyMessage),
          )
        else
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _LeaderboardRow(rank: i + 1, entry: entries[i], suffix: suffix),
          ],
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.entry, required this.suffix});

  final int rank;
  final RankedMember entry;
  final String suffix;

  /// Rank 1-3 get a trophy in the same accent hue, just fainter the further
  /// down the podium — a sequential encoding of "how top" rather than three
  /// unrelated colors, and the numeral/name/value never depend on it to be
  /// understood.
  static const _rankOpacity = {1: 1.0, 2: 0.75, 3: 0.55};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final member = entry.member;
    final opacity = _rankOpacity[rank];

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: member.photoUrl != null ? avatarImage(member.photoUrl!, 20) : null,
        child: member.photoUrl == null
            ? Text(
                _initials(member.name),
                style: TextStyle(color: colorScheme.onPrimaryContainer),
              )
            : null,
      ),
      title: Row(
        children: [
          Text('$rank. ', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          Flexible(child: Text(member.name, overflow: TextOverflow.ellipsis)),
          if (opacity != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.emoji_events, size: 18, color: colorScheme.primary.withValues(alpha: opacity)),
          ],
        ],
      ),
      subtitle: Text('${entry.value.toStringAsFixed(entry.value == entry.value.roundToDouble() ? 0 : 1)} $suffix'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/directory/${member.uid}'),
    );
  }
}

/// New members per month, as a row of thin bars — one hue, varying length,
/// with the count labeled directly above each bar (six values is too few to
/// bother with a legend or axis ticks).
class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({required this.months});

  final List<MonthlyCount> months;

  static const _chartHeight = 96.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxCount = months.map((m) => m.count).fold(0, (a, b) => a > b ? a : b);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final m in months)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${m.count}', style: labelStyle?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: _chartHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: maxCount == 0 ? 4 : (m.count / maxCount) * _chartHeight,
                        constraints: const BoxConstraints(minHeight: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(DateFormat.MMM().format(m.month), style: labelStyle),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
