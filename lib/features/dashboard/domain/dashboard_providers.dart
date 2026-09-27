import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';

/// One member's spot on a ranked list (volunteer hours, points, ...). Kept
/// generic so both leaderboards on the Dashboard render through the same row
/// widget and read as one system rather than two different-looking lists.
class RankedMember {
  final AppUser member;
  final double value;
  const RankedMember({required this.member, required this.value});
}

/// Every approved member with at least one yearly point, ranked highest
/// first. Yearly points are what the club roster itself records (see
/// `PointsSummary` / `AppUser.yearlyPoints`) and — unlike a member's
/// check-in history, which only they and an admin can read — are already
/// visible to every approved member via the directory, so this needs no new
/// Firestore rule to show club-wide.
final pointsLeaderboardProvider = Provider<List<RankedMember>>((ref) {
  final members = ref.watch(approvedMembersProvider).valueOrNull ?? const <AppUser>[];
  final entries = members
      .where((m) => (m.yearlyPoints ?? 0) > 0)
      .map((m) => RankedMember(member: m, value: (m.yearlyPoints ?? 0).toDouble()))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
});

/// A handful of club-wide totals for the Dashboard's stat row. Derived
/// entirely from streams the app already watches elsewhere, so this needs no
/// extra Firestore reads or rules.
class ClubTotals {
  final int memberCount;
  final int duesPaidCount;
  final int upcomingEventCount;
  final double volunteerHours;
  const ClubTotals({
    required this.memberCount,
    required this.duesPaidCount,
    required this.upcomingEventCount,
    required this.volunteerHours,
  });
}

final clubTotalsProvider = Provider<ClubTotals>((ref) {
  final members = ref.watch(approvedMembersProvider).valueOrNull ?? const <AppUser>[];
  final events = ref.watch(eventsProvider).valueOrNull ?? const [];
  final hoursByUid = ref.watch(volunteerHoursProvider).valueOrNull ?? const {};
  final now = DateTime.now();

  return ClubTotals(
    memberCount: members.length,
    duesPaidCount: members.where((m) => m.duesPaid).length,
    upcomingEventCount: events.where((e) => e.endTime.isAfter(now)).length,
    volunteerHours: hoursByUid.values.fold(0.0, (sum, h) => sum + h),
  );
});

/// How many members joined in a given month, for the Dashboard's growth row.
class MonthlyCount {
  final DateTime month;
  final int count;
  const MonthlyCount({required this.month, required this.count});
}

/// New approved members per month for the last 6 months (this month
/// included), oldest first. Members with no recorded join date don't count
/// toward any month rather than skewing the current one.
final newMembersByMonthProvider = Provider<List<MonthlyCount>>((ref) {
  final members = ref.watch(approvedMembersProvider).valueOrNull;
  final now = DateTime.now();
  final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
  if (members == null) return [for (final m in months) MonthlyCount(month: m, count: 0)];

  final counts = {for (final m in months) m: 0};
  for (final member in members) {
    final createdAt = member.createdAt;
    if (createdAt == null) continue;
    final key = DateTime(createdAt.year, createdAt.month);
    if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
  }
  return [for (final m in months) MonthlyCount(month: m, count: counts[m]!)];
});
