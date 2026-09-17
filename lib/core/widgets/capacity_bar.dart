import 'package:flutter/material.dart';

/// A small "X of Y" caption with a matching progress bar, used anywhere a
/// fill level (e.g. volunteer slot capacity) needs visual weight instead of
/// being plain text.
class CapacityBar extends StatelessWidget {
  const CapacityBar({super.key, required this.filled, required this.capacity});

  final int filled;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final isFull = capacity > 0 && filled >= capacity;
    final ratio = capacity > 0 ? (filled / capacity).clamp(0.0, 1.0) : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isFull ? 'Full' : '$filled of $capacity spots filled',
          style: TextStyle(color: isFull ? colorScheme.error : colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: isFull ? colorScheme.error : colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
