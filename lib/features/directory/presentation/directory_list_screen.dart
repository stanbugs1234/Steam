import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';

final _directorySearchProvider = StateProvider<String>((ref) => '');

class DirectoryListScreen extends ConsumerStatefulWidget {
  const DirectoryListScreen({super.key});

  @override
  ConsumerState<DirectoryListScreen> createState() => _DirectoryListScreenState();
}

class _DirectoryListScreenState extends ConsumerState<DirectoryListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(_directorySearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(approvedMembersProvider);
    final query = ref.watch(_directorySearchProvider).trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Member Directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      )
                    : null,
                hintText: 'Search by name or child\'s name',
                border: const OutlineInputBorder(),
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
                            m.kids.any((k) => k.name.toLowerCase().contains(query));
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${filtered.length} member${filtered.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _MemberTile(member: filtered[index]),
                      ),
                    ),
                  ],
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
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final AppUser member;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final kidsLabel = member.kids
        .map((k) => k.grade.isNotEmpty ? '${k.name} (${k.grade})' : k.name)
        .join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
          child: member.photoUrl == null
              ? Text(_initials(member.name), style: TextStyle(color: colorScheme.onPrimaryContainer))
              : null,
        ),
        title: Row(
          children: [
            Flexible(child: Text(member.name, overflow: TextOverflow.ellipsis)),
            if (member.isAdmin) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Admin'),
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(color: colorScheme.onPrimary, fontSize: 11),
                backgroundColor: colorScheme.primary,
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        subtitle: kidsLabel.isNotEmpty ? Text(kidsLabel) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/directory/${member.uid}'),
      ),
    );
  }
}
