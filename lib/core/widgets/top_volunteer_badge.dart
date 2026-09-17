import 'package:flutter/material.dart';

/// A small "Top Volunteer" pill shown next to a member's name when they hold
/// one of the top 3 spots on the volunteer leaderboard. Styled distinctly
/// from [AdminBadge] (different icon/color) so the two aren't confused when
/// both appear on the same person.
class TopVolunteerBadge extends StatelessWidget {
  const TopVolunteerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(Icons.emoji_events, size: 14, color: colorScheme.onSecondaryContainer),
      label: const Text('Top Volunteer'),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 11),
      backgroundColor: colorScheme.secondaryContainer,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
