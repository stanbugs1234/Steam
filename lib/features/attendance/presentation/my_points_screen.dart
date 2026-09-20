import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/section_card.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../domain/attendance_providers.dart';

/// Where a member's points came from: each meeting they checked into, plus
/// any points already on the club roster, and (separately, since volunteering
/// doesn't earn points) their volunteer record.
class MyPointsScreen extends ConsumerWidget {
  const MyPointsScreen({super.key});

  static String _pts(int n) => '$n pt${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final points = ref.watch(myPointsSummaryProvider);
    final checkInsAsync = ref.watch(myCheckInsProvider);
    final volunteerAsync = ref.watch(myVolunteerRecordProvider);
    final dateFormat = DateFormat.yMMMEd();
    final hasAnyPoints = points.checkIns.isNotEmpty || points.rosterPoints > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('My Points')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text('${points.total}', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(points.total == 1 ? 'point' : 'points', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'How you earned your points',
            icon: Icons.emoji_events_outlined,
            padding: EdgeInsets.symmetric(horizontal: 20),
            children: [
              // Only say "No points yet" once the check-ins have really loaded.
              if (checkInsAsync.isLoading && !checkInsAsync.hasValue)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (checkInsAsync.hasError && !checkInsAsync.hasValue)
                const _EmptyRow("Couldn't load your check-ins.\nPlease try again in a moment.")
              else if (!hasAnyPoints)
                const _EmptyRow(
                  "No points yet.\nScan the check-in code at your next meeting to earn 1 point.",
                ),
              for (var i = 0; i < points.checkIns.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.how_to_reg_outlined),
                  title: Text(points.checkIns[i].eventTitle),
                  subtitle: Text('Attended meeting · ${dateFormat.format(points.checkIns[i].eventStartTime)}'),
                  trailing: _Amount('+${_pts(points.checkIns[i].points)}'),
                ),
              ],
              if (points.rosterPoints > 0) ...[
                if (points.checkIns.isNotEmpty) const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Club roster'),
                  subtitle: const Text('Points recorded on the club roster'),
                  trailing: _Amount('+${_pts(points.rosterPoints)}'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Volunteer record',
            icon: Icons.volunteer_activism_outlined,
            trailing: volunteerAsync.maybeWhen(
              data: (records) {
                final total = records.fold<double>(0, (sum, r) => sum + r.hours);
                return total == 0
                    ? null
                    : Text('${total.toStringAsFixed(1)} hrs total', style: theme.textTheme.labelLarge);
              },
              orElse: () => null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              volunteerAsync.when(
                data: (records) {
                  if (records.isEmpty) {
                    return const _EmptyRow("No volunteer shifts yet.\nSign up on an event that needs volunteers.");
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < records.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(records[i].event.title),
                          subtitle: Text(
                            '${dateFormat.format(records[i].event.startTime)} · ${records[i].slotLabels.join(', ')}',
                          ),
                          trailing: _Amount('${records[i].hours.toStringAsFixed(1)} hrs'),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => const _EmptyRow("Couldn't load your volunteer record."),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
            child: Text(
              'Volunteer hours are tracked separately from points.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold));
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
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
