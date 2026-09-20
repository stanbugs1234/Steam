import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/friendly_error.dart';

/// A friendly failure message, with a plain-language reason (offline, no
/// permission, …) and an optional "Try again" button. The raw exception is
/// only shown in debug builds — members never see error codes or paths.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.error, this.onRetry});

  final String message;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reason = error == null ? null : friendlyError(error, fallback: '');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: colorScheme.error)),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (kDebugMode && error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
