import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_badge.dart';
import '../../../core/widgets/children_form_field.dart' show kGradeOptions;
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/top_volunteer_badge.dart';
import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';

final _directorySearchProvider = StateProvider<String>((ref) => '');
final _directoryGradeFilterProvider = StateProvider<String?>((ref) => null);

String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

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
    final gradeFilter = ref.watch(_directoryGradeFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Member Directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                hintText: 'Search by name, phone, or child\'s name',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => ref.read(_directorySearchProvider.notifier).state = value,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DropdownButtonFormField<String?>(
              initialValue: gradeFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by grade',
                prefixIcon: Icon(Icons.filter_alt_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Grades')),
                for (final grade in kGradeOptions) DropdownMenuItem(value: grade, child: Text(grade)),
              ],
              onChanged: (value) => ref.read(_directoryGradeFilterProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final queryDigits = _digitsOnly(query);
                final filtered = members.where((m) {
                  final matchesQuery = query.isEmpty ||
                      m.name.toLowerCase().contains(query) ||
                      m.kids.any((k) => k.name.toLowerCase().contains(query)) ||
                      (queryDigits.isNotEmpty && _digitsOnly(m.phone).contains(queryDigits));
                  final matchesGrade = gradeFilter == null || m.kids.any((k) => k.grade == gradeFilter);
                  return matchesQuery && matchesGrade;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    message: gradeFilter == null
                        ? 'No members found.'
                        : 'No members found with a kid in $gradeFilter.',
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${filtered.length} member${filtered.length == 1 ? '' : 's'}'
                          '${gradeFilter == null ? '' : ' · $gradeFilter'}',
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
              error: (err, _) => ErrorState(message: "Couldn't load the directory right now.", error: err),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final AppUser member;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTopVolunteer = ref.watch(topVolunteerUidsProvider).contains(member.uid);
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
              const AdminBadge(),
            ],
            if (isTopVolunteer) ...[
              const SizedBox(width: 8),
              const TopVolunteerBadge(),
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
