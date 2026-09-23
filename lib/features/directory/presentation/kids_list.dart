import 'package:flutter/material.dart';

import '../../../models/child_info.dart';

/// A member's children as a short list, one per line — the child's name with
/// their grade quietly after it — so a family with several kids doesn't turn
/// into a single run-on sentence in the directory.
class KidsList extends StatelessWidget {
  const KidsList({super.key, required this.kids});

  final List<ChildInfo> kids;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kid in kids)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.child_care_outlined, size: 16, color: muted),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: kid.name.isNotEmpty ? kid.name : 'Child',
                      children: [
                        if (kid.grade.isNotEmpty)
                          TextSpan(text: '  ·  ${kid.grade}', style: TextStyle(color: muted)),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
