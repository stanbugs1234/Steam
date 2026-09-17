import 'package:flutter/material.dart';

/// A small "Admin" pill shown next to a member's name. Kept as one widget so
/// the directory list, member detail header, and anywhere else this appears
/// stay visually identical.
class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: const Text('Admin'),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: colorScheme.onPrimary, fontSize: 11),
      backgroundColor: colorScheme.primary,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
