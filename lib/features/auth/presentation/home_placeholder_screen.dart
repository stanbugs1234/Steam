import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/auth_providers.dart';

/// Temporary landing screen for approved members. Will be replaced by the
/// bottom-nav shell (Directory / News / Events / Volunteering) in later
/// milestones.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam Club'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Welcome, ${appUser?.name ?? ''}!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Directory, News, Events, and Volunteering are coming in the next milestones.'),
            if (appUser?.isAdmin ?? false) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/admin/approvals'),
                icon: const Icon(Icons.fact_check),
                label: const Text('Review Pending Approvals'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
