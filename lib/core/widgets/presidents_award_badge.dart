import 'package:flutter/material.dart';

/// A small "President's Award" pill shown next to a member's name (see
/// [AppUser.presidentsAwardYears]). Styled distinctly from the other award
/// badges so they aren't confused when more than one applies.
class PresidentsAwardBadge extends StatelessWidget {
  const PresidentsAwardBadge({super.key});

  static const _background = Color(0xFFFFF9C4);
  static const _foreground = Color(0xFF8D6E00);

  @override
  Widget build(BuildContext context) {
    return const Chip(
      avatar: Icon(Icons.workspace_premium, size: 14, color: _foreground),
      label: Text("President's Award"),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: _foreground, fontSize: 11),
      backgroundColor: _background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
