import 'package:flutter/material.dart';

/// A small tappable summary card: icon, big value, and a label underneath
/// (e.g. "12 · Points"). Used for the at-a-glance rows on Home and Profile.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    this.valueColor,
    this.showChevron = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;
  final VoidCallback onTap;

  /// Hints that tapping opens more detail.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant);
    // Read as one control ("5 Points, button") rather than two loose texts.
    return Semantics(
      button: true,
      label: '$value $label',
      excludeSemantics: true,
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: valueColor ?? colorScheme.primary, size: 20),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: valueColor),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (showChevron) Icon(Icons.chevron_right, size: 14, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
