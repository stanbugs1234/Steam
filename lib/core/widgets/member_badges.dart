import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import 'admin_badge.dart';
import 'dues_paid_badge.dart';
import 'good_buddy_badge.dart';
import 'hall_of_fame_badge.dart';
import 'new_member_badge.dart';
import 'presidents_award_badge.dart';
import 'rookie_of_the_year_badge.dart';
import 'top_volunteer_badge.dart';

/// The status pills for a member (Admin, Top Volunteer, New Member, Dues
/// Paid, plus any awards), laid out in a wrapping row. Renders nothing if
/// none apply.
class MemberBadges extends StatelessWidget {
  const MemberBadges({super.key, required this.user, required this.isTopVolunteer, this.alignment = WrapAlignment.start});

  final AppUser user;
  final bool isTopVolunteer;
  final WrapAlignment alignment;

  static bool hasAny(AppUser user, bool isTopVolunteer) =>
      user.isAdmin || isTopVolunteer || user.isNewMember || user.duesPaid || user.hasAnyAward;

  @override
  Widget build(BuildContext context) {
    if (!hasAny(user, isTopVolunteer)) return const SizedBox.shrink();
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 4,
      children: [
        if (user.isAdmin) const AdminBadge(),
        if (isTopVolunteer) const TopVolunteerBadge(),
        if (user.isNewMember) const NewMemberBadge(),
        if (user.duesPaid) const DuesPaidBadge(),
        if (user.goodBuddyYears.isNotEmpty) const GoodBuddyBadge(),
        if (user.presidentsAwardYears.isNotEmpty) const PresidentsAwardBadge(),
        if (user.hallOfFameYears.isNotEmpty) const HallOfFameBadge(),
        if (user.rookieOfTheYearYears.isNotEmpty) const RookieOfTheYearBadge(),
      ],
    );
  }
}
