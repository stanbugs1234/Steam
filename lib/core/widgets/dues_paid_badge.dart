import 'package:flutter/material.dart';

/// A small "Dues Paid" pill shown next to a member's name once an admin has
/// marked their dues as paid (`AppUser.duesPaid`). Uses a literal green
/// success color since none of this app's theme color slots read as
/// unambiguously "paid/good" the way the other badges' slots do.
class DuesPaidBadge extends StatelessWidget {
  const DuesPaidBadge({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFC8E6C9);
    const foreground = Color(0xFF1B5E20);
    return const Chip(
      avatar: Icon(Icons.check_circle, size: 14, color: foreground),
      label: Text('Dues Paid'),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: foreground, fontSize: 11),
      backgroundColor: background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
