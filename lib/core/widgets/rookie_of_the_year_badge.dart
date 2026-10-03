import 'package:flutter/material.dart';

/// A small "Rookie of the Year" pill shown next to a member's name (see
/// [AppUser.rookieOfTheYearYears]). Styled distinctly from the other award
/// badges so they aren't confused when more than one applies.
class RookieOfTheYearBadge extends StatelessWidget {
  const RookieOfTheYearBadge({super.key});

  static const _background = Color(0xFFB3E5FC);
  static const _foreground = Color(0xFF01579B);

  @override
  Widget build(BuildContext context) {
    return const Chip(
      avatar: Icon(Icons.star_outline, size: 14, color: _foreground),
      label: Text('Rookie of the Year'),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: _foreground, fontSize: 11),
      backgroundColor: _background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
