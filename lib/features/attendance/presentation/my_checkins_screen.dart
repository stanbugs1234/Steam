import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../domain/attendance_providers.dart';

class MyCheckInsScreen extends ConsumerWidget {
  const MyCheckInsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkInsAsync = ref.watch(myCheckInsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Points')),
      body: checkInsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.emoji_events_outlined,
              message: "You haven't checked in to any meetings yet.\nScan a check-in code at your next meeting to earn points.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: records.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                child: ListTile(
                  title: Text(record.eventTitle),
                  subtitle: Text(DateFormat.MMMd().add_jm().format(record.eventStartTime)),
                  trailing: Text(
                    '+${record.points} pt${record.points == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load your points.", error: err),
      ),
    );
  }
}
