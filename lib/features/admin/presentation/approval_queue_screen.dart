import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';

class ApprovalQueueScreen extends ConsumerWidget {
  const ApprovalQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: pendingAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return _PendingUserTile(user: user);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading requests: $err')),
      ),
    );
  }
}

class _PendingUserTile extends ConsumerStatefulWidget {
  const _PendingUserTile({required this.user});

  final AppUser user;

  @override
  ConsumerState<_PendingUserTile> createState() => _PendingUserTileState();
}

class _PendingUserTileState extends ConsumerState<_PendingUserTile> {
  bool _working = false;

  Future<void> _respond(UserStatus status) async {
    setState(() => _working = true);
    try {
      await ref.read(userRepositoryProvider).setStatus(widget.user.uid, status);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ListTile(
      title: Text(user.name),
      subtitle: Text([
        if (user.email.isNotEmpty) user.email,
        if (user.phone.isNotEmpty) user.phone,
        if (user.kidName.isNotEmpty) '${user.kidName}${user.kidGrade.isNotEmpty ? ' (${user.kidGrade})' : ''}',
      ].join(' · ')),
      trailing: _working
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
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
    );
  }
}
