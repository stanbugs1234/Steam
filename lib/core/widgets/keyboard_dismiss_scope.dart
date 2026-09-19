import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// App-wide keyboard dismissal. iOS number/phone pads have no Return key, and
/// multiline fields use Return for newlines, so without this a user can be
/// stuck with the keyboard up. Provides:
/// - tap on empty space to dismiss,
/// - on iOS, a "Done" bar pinned above the keyboard (screens resize above it).
class KeyboardDismissScope extends StatelessWidget {
  const KeyboardDismissScope({super.key, required this.child});

  final Widget child;

  static const double _barHeight = 44;

  static void _dismiss() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final showBar = defaultTargetPlatform == TargetPlatform.iOS && keyboardHeight > 0;

    final content = showBar
        ? MediaQuery(
            data: mediaQuery.copyWith(
              viewInsets: mediaQuery.viewInsets.copyWith(bottom: keyboardHeight + _barHeight),
            ),
            child: child,
          )
        : child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismiss,
      child: Stack(
        children: [
          Positioned.fill(child: content),
          if (showBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight,
              height: _barHeight,
              child: const _DoneBar(),
            ),
        ],
      ),
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: KeyboardDismissScope._dismiss,
          child: const Text('Done'),
        ),
      ),
    );
  }
}
