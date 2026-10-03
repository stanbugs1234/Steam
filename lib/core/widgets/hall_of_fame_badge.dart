import 'package:flutter/material.dart';

/// A small "Hall of Fame" pill shown next to a member's name (see
/// [AppUser.hallOfFameYears]). Styled distinctly from the other award
/// badges so they aren't confused when more than one applies.
class HallOfFameBadge extends StatelessWidget {
  const HallOfFameBadge({super.key});

  static const _background = Color(0xFFE1BEE7);
  static const _foreground = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return const Chip(
      avatar: Icon(Icons.military_tech, size: 14, color: _foreground),
      label: Text('Hall of Fame'),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: _foreground, fontSize: 11),
      backgroundColor: _background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
