import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';

/// One pending signup with Approve / Deny actions and, when the signup
/// matches an existing roster entry, a duplicate banner (with "Merge &
/// Approve" for unclaimed imported placeholders). Callers supply the
/// surrounding container (a Card or a SectionCard).
class PendingUserTile extends ConsumerStatefulWidget {
  const PendingUserTile({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<PendingUserTile> createState() => _PendingUserTileState();
}

class _PendingUserTileState extends ConsumerState<PendingUserTile> {
  bool _working = false;
  late final Future<AppUser?> _duplicateFuture;

  @override
  void initState() {
    super.initState();
    _duplicateFuture = ref.read(userRepositoryProvider).findPossibleDuplicate(widget.user);
  }

  Future<void> _respond(UserStatus status) async {
    setState(() => _working = true);
    try {
      await ref.read(userRepositoryProvider).setStatus(widget.user.uid, status);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _mergeAndApprove(AppUser placeholder) async {
    final kidsSummary = placeholder.kids.isEmpty
        ? 'their roster info'
        : '${placeholder.kidCount} ${placeholder.kidCount == 1 ? 'kid' : 'kids'} '
            '(${placeholder.kids.map((k) => k.name).join(', ')})';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge with imported roster entry?'),
        content: Text(
          'This copies $kidsSummary from the imported roster entry for "${placeholder.name}" into '
          'this account, approves it, and removes the old roster placeholder.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Merge & Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _working = true);
    try {
      await ref.read(userRepositoryProvider).mergeAndApprove(widget.user, placeholder);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(user.name),
          subtitle: Text([
            if (user.email.isNotEmpty) user.email,
            if (user.phone.isNotEmpty) user.phone,
            ...user.kids.map((k) => k.grade.isNotEmpty ? '${k.name} (${k.grade})' : k.name),
          ].join(' · ')),
          trailing: _working
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                      tooltip: 'Approve',
                      onPressed: () => _respond(UserStatus.approved),
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
                      tooltip: 'Deny',
                      onPressed: () => _respond(UserStatus.denied),
                    ),
                  ],
                ),
        ),
        FutureBuilder<AppUser?>(
          future: _duplicateFuture,
          builder: (context, snapshot) {
            final duplicate = snapshot.data;
            if (duplicate == null) return const SizedBox.shrink();

            final isPlaceholder = duplicate.uid.startsWith('imported_');
            final message = isPlaceholder
                ? 'Possible match: an imported roster entry for "${duplicate.name}" shares this '
                    'phone or email${duplicate.kids.isEmpty ? '' : ', with ${duplicate.kidCount} '
                        '${duplicate.kidCount == 1 ? 'kid' : 'kids'} on file: '
                        '${duplicate.kids.map((k) => k.name).join(', ')}'}.'
                : 'Possible duplicate: an existing account for "${duplicate.name}" already uses this '
                    "phone or email. Merging live accounts isn't automated — consider denying this "
                    'request and asking them to sign in with their original account instead.';

            return Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  if (isPlaceholder)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _working ? null : () => _mergeAndApprove(duplicate),
                        child: const Text('Merge & Approve'),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
