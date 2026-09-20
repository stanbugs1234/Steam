import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../models/app_user.dart';
import '../../../models/club_event.dart';
import '../../events/domain/event_providers.dart';
import '../data/account_deletion_service.dart';
import '../domain/account_providers.dart';
import '../domain/auth_providers.dart';

/// The whole "Delete account" interaction, shared by the Profile screen and
/// the waiting/denied screens (App Store rules require deletion to be
/// available to every account, including ones never approved).
///
/// Checks the two things that would make deleting unsafe or fail late (the
/// only admin, a stale sign-in), asks for confirmation, then deletes.
/// [onBusy] lets the caller show a progress overlay while it runs. On success
/// the member is signed out and the router takes over, so the caller may
/// already be gone when this returns.
Future<void> confirmAndDeleteAccount({
  required BuildContext context,
  required WidgetRef ref,
  required AppUser me,
  required ValueChanged<bool> onBusy,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(accountDeletionServiceProvider);
  final auth = ref.read(authRepositoryProvider);
  // Only approved members can read these lists (and only they can be admins or
  // hold volunteer slots), so don't ask the database on behalf of anyone else.
  final admins = me.isAdmin
      ? (ref.read(approvedMembersProvider).value ?? const <AppUser>[]).where((m) => m.isAdmin).length
      : 0;
  final now = DateTime.now();
  final upcoming = me.isApproved
      ? (ref.read(eventsProvider).value ?? const []).where((e) => e.endTime.isAfter(now)).toList()
      : const <ClubEvent>[];

  if (me.isAdmin && admins <= 1) {
    await _notice(
      context,
      "You're the only admin",
      'Before deleting your account, make another member an admin '
          '(Directory → their profile → Admin access) so the club is never left without one.',
    );
    return;
  }
  if (!service.signedInRecently) {
    await _notice(
      context,
      'Sign in again first',
      'For your security, please sign out and sign back in, then delete your account right away.',
      actionLabel: 'Sign Out',
      onAction: auth.signOut,
    );
    return;
  }
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently deletes your STEAM Club account: your profile, points and volunteer history, '
        "and your spot in upcoming volunteer shifts. This can't be undone.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Delete Account'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  onBusy(true);
  try {
    await service.deleteMyAccount(me: me, upcomingEvents: upcoming, isOnlyAdmin: admins <= 1);
    // Success signs the member out, which moves the app to the login screen.
  } on RecentLoginRequiredException {
    if (context.mounted) {
      await _notice(context, 'Sign in again first', 'Please sign out and sign back in, then try again.');
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(friendlyError(e, fallback: "Couldn't delete your account. Please try again."))),
    );
  } finally {
    onBusy(false);
  }
}

Future<void> _notice(
  BuildContext context,
  String title,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (!context.mounted) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(actionLabel == null ? 'OK' : 'Cancel')),
        if (actionLabel != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onAction?.call();
            },
            child: Text(actionLabel),
          ),
      ],
    ),
  );
}
