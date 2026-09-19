import 'package:flutter/material.dart';

/// A small "Dues Paid" pill shown next to a member's name once an admin has
/// marked their dues as paid (`AppUser.duesPaid`). Uses a literal green
/// success color since none of this app's theme color slots read as
/// unambiguously "paid/good" the way the other badges' slots do.
class DuesPaidBadge extends StatelessWidget {
  const DuesPaidBadge({super.key, this.iconOnly = false});

  /// Render just a money symbol (for dense lists) instead of the labelled pill.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFC8E6C9);
    const foreground = Color(0xFF1B5E20);
    if (iconOnly) {
      return Tooltip(
        message: 'Dues paid',
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: background, shape: BoxShape.circle),
          child: const Icon(Icons.attach_money, size: 16, color: foreground, semanticLabel: 'Dues paid'),
        ),
      );
    }
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
