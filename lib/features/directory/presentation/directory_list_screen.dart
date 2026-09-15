import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/auth_providers.dart';

final _directorySearchProvider = StateProvider<String>((ref) => '');

class DirectoryListScreen extends ConsumerWidget {
  const DirectoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(approvedMembersProvider);
    final query = ref.watch(_directorySearchProvider).trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Member Directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or child\'s name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => ref.read(_directorySearchProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final filtered = query.isEmpty
                    ? members
                    : members.where((m) {
                        return m.name.toLowerCase().contains(query) ||
                            m.kidName.toLowerCase().contains(query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                        child: member.photoUrl == null ? Text(_initials(member.name)) : null,
                      ),
                      title: Text(member.name),
                      subtitle: member.kidName.isNotEmpty
                          ? Text('${member.kidName}${member.kidGrade.isNotEmpty ? ' · ${member.kidGrade}' : ''}')
                          : null,
                      onTap: () => context.push('/directory/${member.uid}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading directory: $err')),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
