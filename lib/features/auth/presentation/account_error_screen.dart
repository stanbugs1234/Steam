import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_state.dart';
import '../domain/auth_providers.dart';

/// Shown when the signed-in member's profile couldn't be loaded (offline on a
/// first launch, a transient permission hiccup, …). This is deliberately *not*
/// the "waiting for approval" screen: an approved member who hits a network
/// error must never be told their request is still pending.
class AccountErrorScreen extends ConsumerWidget {
  const AccountErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(currentAppUserProvider).error;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorState(
                message: "Couldn't load your account.",
                error: error,
                onRetry: () => ref.invalidate(currentAppUserProvider),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
