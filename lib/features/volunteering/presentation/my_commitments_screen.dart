import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/volunteer_providers.dart';

class MyCommitmentsScreen extends ConsumerWidget {
  const MyCommitmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commitmentsAsync = ref.watch(myCommitmentsProvider);
    final myUid = ref.watch(currentAppUserProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Volunteering')),
      body: commitmentsAsync.when(
        data: (commitments) {
          if (commitments.isEmpty) {
            return const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              message: "You haven't signed up to volunteer for anything yet.\nCheck the Events tab for opportunities.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: commitments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = commitments[index];
              return Card(
                child: ListTile(
                  onTap: () => context.push('/events/${c.event.id}'),
                  title: Text(c.event.title),
                  subtitle: Text('${c.slot.label} · ${DateFormat.MMMd().add_jm().format(c.event.startTime)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                    onPressed: myUid == null
                        ? null
                        : () => ref.read(volunteerRepositoryProvider).cancel(c.event.id, c.slot.id, myUid),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load your commitments.", error: err),
      ),
    );
  }
}
