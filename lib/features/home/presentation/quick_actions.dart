import 'package:flutter/material.dart';

class QuickActionItem {
  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
}

/// The row of shortcut tiles on Home. It adapts to the screen instead of
/// assuming one phone size:
///
/// * On most phones all tiles sit in one row, with labels that shrink to fit
///   their tile rather than breaking mid-word ("Voluntee / r").
/// * If the tiles would be too narrow to read (a small phone) or the member has
///   enlarged their text size, it flows into rows of three, giving each tile
///   far more room.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.actions});

  final List<QuickActionItem> actions;

  /// Narrowest a tile can be, in a single row, before its label gets cramped.
  static const _minSingleRowTileWidth = 56.0;

  /// Past this text-size multiplier a label no longer fits a five-across tile.
  static const _maxSingleRowTextScale = 1.3;

  static const _columnsWhenWrapped = 3;

  /// How many tiles go in each row for a given available width and text scale.
  /// Exposed so the rule can be tested directly.
  static int columnsFor({
    required double width,
    required double textScale,
    required int count,
  }) {
    final gap = _gapFor(width);
    final singleRowTile = (width - gap * (count - 1)) / count;
    final fitsOneRow =
        singleRowTile >= _minSingleRowTileWidth &&
        textScale <= _maxSingleRowTextScale;
    return fitsOneRow ? count : _columnsWhenWrapped;
  }

  static double _gapFor(double width) => width >= 420 ? 12 : 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final columns = columnsFor(
          width: width,
          textScale: textScale,
          count: actions.length,
        );
        final gap = _gapFor(width);
        final tileWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: tileWidth,
                child: _QuickActionTile(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final QuickActionItem action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Column(
            children: [
              Badge.count(
                count: action.badgeCount,
                isLabelVisible: action.badgeCount > 0,
                child: Icon(action.icon, color: colorScheme.primary),
              ),
              const SizedBox(height: 6),
              // One line that scales down to fit — never wraps mid-word.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  action.label,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
