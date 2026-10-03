import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/avatar_image.dart';
import '../../../core/widgets/admin_badge.dart';
import '../../../core/widgets/children_form_field.dart' show kGradeOptions;
import '../../../core/widgets/dues_paid_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/good_buddy_badge.dart';
import '../../../core/widgets/hall_of_fame_badge.dart';
import '../../../core/widgets/new_member_badge.dart';
import '../../../core/widgets/presidents_award_badge.dart';
import '../../../core/widgets/rookie_of_the_year_badge.dart';
import '../../../core/widgets/top_volunteer_badge.dart';
import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../domain/directory_providers.dart';
import 'kids_list.dart';

final _nonDigits = RegExp(r'\D');
String _digitsOnly(String s) => s.replaceAll(_nonDigits, '');

class DirectoryListScreen extends ConsumerStatefulWidget {
  const DirectoryListScreen({super.key});

  @override
  ConsumerState<DirectoryListScreen> createState() => _DirectoryListScreenState();
}

class _DirectoryListScreenState extends ConsumerState<DirectoryListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(directorySearchProvider.notifier).state = value;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    ref.read(directorySearchProvider.notifier).state = '';
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _FiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(directorySearchProvider, (prev, next) {
      if (_searchCtrl.text != next) _searchCtrl.text = next;
    });

    final membersAsync = ref.watch(approvedMembersProvider);
    final query = ref.watch(directorySearchProvider).trim().toLowerCase();
    final gradeFilter = ref.watch(directoryGradeFilterProvider);
    final onlyNewMembers = ref.watch(directoryNewMemberFilterProvider);
    final duesFilter = ref.watch(directoryDuesFilterProvider);
    final activeFilters =
        (gradeFilter != null ? 1 : 0) + (onlyNewMembers ? 1 : 0) + (duesFilter != DuesFilter.any ? 1 : 0);

    final resultSlivers = membersAsync.when(
      data: (members) {
        final queryDigits = _digitsOnly(query);
        final filtered = members.where((m) {
          final matchesQuery = query.isEmpty ||
              m.name.toLowerCase().contains(query) ||
              m.kids.any((k) => k.name.toLowerCase().contains(query)) ||
              (queryDigits.isNotEmpty && _digitsOnly(m.phone).contains(queryDigits));
          final matchesGrade = gradeFilter == null || m.kids.any((k) => k.grade == gradeFilter);
          final matchesNewMember = !onlyNewMembers || m.isNewMember;
          final matchesDues = switch (duesFilter) {
            DuesFilter.any => true,
            DuesFilter.paidOnly => m.duesPaid,
            DuesFilter.unpaidOnly => !m.duesPaid,
          };
          return matchesQuery && matchesGrade && matchesNewMember && matchesDues;
        }).toList();

        if (filtered.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.people_outline,
                message: switch (duesFilter) {
                  DuesFilter.paidOnly => 'No members with paid dues found.',
                  DuesFilter.unpaidOnly => 'No members with unpaid dues found.',
                  DuesFilter.any => onlyNewMembers
                      ? 'No new members found.'
                      : gradeFilter == null
                          ? 'No members found.'
                          : 'No members found with a kid in $gradeFilter.',
                },
              ),
            ),
          ];
        }

        return <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} member${filtered.length == 1 ? '' : 's'}'
                  '${gradeFilter == null ? '' : ' · $gradeFilter'}'
                  '${onlyNewMembers ? ' · New' : ''}'
                  '${duesFilter == DuesFilter.paidOnly ? ' · Paid dues' : ''}'
                  '${duesFilter == DuesFilter.unpaidOnly ? ' · Unpaid dues' : ''}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _MemberTile(
                key: ValueKey(filtered[index].uid),
                member: filtered[index],
              ),
            ),
          ),
        ];
      },
      loading: () => const <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
      ],
      error: (err, _) => <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(message: "Couldn't load the directory right now.", error: err, onRetry: () => ref.invalidate(approvedMembersProvider)),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Member Directory')),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Slides away when scrolling down and returns on any upward scroll (YouTube-style).
          SliverFloatingHeader(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
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
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Filters',
                          onPressed: _openFilters,
                          icon: Badge(
                            isLabelVisible: activeFilters > 0,
                            label: Text('$activeFilters'),
                            child: const Icon(Icons.tune),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeFilters > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (gradeFilter != null)
                              InputChip(
                                label: Text(gradeFilter),
                                onDeleted: () => ref.read(directoryGradeFilterProvider.notifier).state = null,
                                deleteButtonTooltipMessage: 'Remove grade filter',
                              ),
                            if (onlyNewMembers)
                              InputChip(
                                avatar: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text('New members'),
                                onDeleted: () => ref.read(directoryNewMemberFilterProvider.notifier).state = false,
                                deleteButtonTooltipMessage: 'Remove new members filter',
                              ),
                            if (duesFilter != DuesFilter.any)
                              InputChip(
                                avatar: const Icon(Icons.money_off, size: 18),
                                label: Text(duesFilter == DuesFilter.paidOnly ? 'Paid dues' : 'Unpaid dues'),
                                onDeleted: () =>
                                    ref.read(directoryDuesFilterProvider.notifier).state = DuesFilter.any,
                                deleteButtonTooltipMessage: 'Remove dues filter',
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ...resultSlivers,
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({super.key, required this.member});

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

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage: member.photoUrl != null ? avatarImage(member.photoUrl!, 22) : null,
          child: member.photoUrl == null
              ? Text(_initials(member.name), style: TextStyle(color: colorScheme.onPrimaryContainer))
              : null,
        ),
        title: Text(member.name, overflow: TextOverflow.ellipsis),
        subtitle: (member.isAdmin ||
                isTopVolunteer ||
                member.isNewMember ||
                member.duesPaid ||
                member.hasAnyAward ||
                member.kids.isNotEmpty)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (member.isAdmin || isTopVolunteer || member.isNewMember || member.duesPaid || member.hasAnyAward)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (member.isAdmin) const AdminBadge(),
                          if (isTopVolunteer) const TopVolunteerBadge(),
                          if (member.isNewMember) const NewMemberBadge(),
                          if (member.duesPaid) const DuesPaidBadge(iconOnly: true),
                          if (member.goodBuddyYears.isNotEmpty) const GoodBuddyBadge(iconOnly: true),
                          if (member.presidentsAwardYears.isNotEmpty) const PresidentsAwardBadge(iconOnly: true),
                          if (member.hallOfFameYears.isNotEmpty) const HallOfFameBadge(iconOnly: true),
                          if (member.rookieOfTheYearYears.isNotEmpty) const RookieOfTheYearBadge(iconOnly: true),
                        ],
                      ),
                    ),
                  if (member.kids.isNotEmpty) KidsList(kids: member.kids),
                ],
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/directory/${member.uid}'),
      ),
    );
  }
}

/// Grade and "new members" filters, applied live to the directory behind it.
class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradeFilter = ref.watch(directoryGradeFilterProvider);
    final onlyNewMembers = ref.watch(directoryNewMemberFilterProvider);
    final duesFilter = ref.watch(directoryDuesFilterProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter members', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: gradeFilter,
              decoration: const InputDecoration(labelText: 'Has a child in grade', prefixIcon: Icon(Icons.school_outlined)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any grade')),
                for (final grade in kGradeOptions) DropdownMenuItem(value: grade, child: Text(grade)),
              ],
              onChanged: (value) => ref.read(directoryGradeFilterProvider.notifier).state = value,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('New members only'),
              value: onlyNewMembers,
              onChanged: (value) => ref.read(directoryNewMemberFilterProvider.notifier).state = value,
            ),
            DropdownButtonFormField<DuesFilter>(
              initialValue: duesFilter,
              decoration: const InputDecoration(labelText: 'Dues paid', prefixIcon: Icon(Icons.money_off)),
              items: const [
                DropdownMenuItem(value: DuesFilter.any, child: Text('Any')),
                DropdownMenuItem(value: DuesFilter.paidOnly, child: Text('Paid only')),
                DropdownMenuItem(value: DuesFilter.unpaidOnly, child: Text('Unpaid only')),
              ],
              onChanged: (value) => ref.read(directoryDuesFilterProvider.notifier).state = value ?? DuesFilter.any,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: gradeFilter == null && !onlyNewMembers && duesFilter == DuesFilter.any
                        ? null
                        : () {
                            ref.read(directoryGradeFilterProvider.notifier).state = null;
                            ref.read(directoryNewMemberFilterProvider.notifier).state = false;
                            ref.read(directoryDuesFilterProvider.notifier).state = DuesFilter.any;
                          },
                    child: const Text('Clear all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
