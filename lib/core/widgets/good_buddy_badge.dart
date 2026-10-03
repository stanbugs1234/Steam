import 'package:flutter/material.dart';

/// A small "Good Buddy Award" pill shown next to a member's name (see
/// [AppUser.goodBuddyYears]). Styled distinctly from the other award badges
/// so they aren't confused when more than one applies.
class GoodBuddyBadge extends StatelessWidget {
  const GoodBuddyBadge({super.key, this.iconOnly = false});

  /// Render just the icon in a colored circle (for dense lists) instead of the labelled pill.
  final bool iconOnly;

  static const _background = Color(0xFFFFE0B2);
  static const _foreground = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Tooltip(
        message: 'Good Buddy Award',
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: _background, shape: BoxShape.circle),
          child: const Icon(Icons.handshake, size: 16, color: _foreground, semanticLabel: 'Good Buddy Award'),
        ),
      );
    }
    return const Chip(
      avatar: Icon(Icons.handshake, size: 14, color: _foreground),
      label: Text('Good Buddy Award'),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: _foreground, fontSize: 11),
      backgroundColor: _background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
