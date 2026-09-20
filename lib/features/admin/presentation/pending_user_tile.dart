import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../models/app_user.dart';
import '../../auth/data/user_repository.dart';
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

  void _showError(Object e, String fallback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: fallback))));
  }

  Future<void> _respond(UserStatus status) async {
    setState(() => _working = true);
    try {
      await ref.read(userRepositoryProvider).setStatus(widget.user.uid, status);
    } catch (e) {
      _showError(e, "Couldn't update this request. Please try again.");
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
    } catch (e) {
      _showError(e, "Couldn't merge this request. Nothing was changed — please try again.");
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
        _DuplicateBanner(user: user, working: _working, onMerge: _mergeAndApprove),
      ],
    );
  }
}

/// The "possible match / duplicate" notice for a pending signup, worked out
/// from the member list the app already has loaded.
class _DuplicateBanner extends ConsumerWidget {
  const _DuplicateBanner({required this.user, required this.working, required this.onMerge});

  final AppUser user;
  final bool working;
  final Future<void> Function(AppUser placeholder) onMerge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer);
    final approved = ref.watch(approvedMembersProvider);

    if (approved.hasError && !approved.hasValue) {
      return _banner(colors, [
        Text(
          "Couldn't check this signup against the roster. Reload before approving, or you may create a duplicate.",
          style: textStyle,
        ),
      ]);
    }
    final duplicate = UserRepository.findPossibleDuplicate(user, approved.valueOrNull ?? const []);
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

    return _banner(colors, [
      Text(message, style: textStyle),
      if (isPlaceholder)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: working ? null : () => onMerge(duplicate),
            child: const Text('Merge & Approve'),
          ),
        ),
    ]);
  }

  Widget _banner(ColorScheme colors, List<Widget> children) {
    return Container(
      width: double.infinity,
      color: colors.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
