import 'package:flutter/material.dart';

/// A small "New Member" pill shown next to a member's name for their first
/// 90 days (see [AppUser.isNewMember]). Styled distinctly from [AdminBadge]
/// and [TopVolunteerBadge] so the three aren't confused when they co-occur.
class NewMemberBadge extends StatelessWidget {
  const NewMemberBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(Icons.auto_awesome, size: 14, color: colorScheme.onTertiaryContainer),
      label: const Text('New Member'),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: colorScheme.onTertiaryContainer, fontSize: 11),
      backgroundColor: colorScheme.tertiaryContainer,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
