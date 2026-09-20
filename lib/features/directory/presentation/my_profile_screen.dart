import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/utils/membership_duration.dart';
import '../../../core/utils/phone_format.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/member_badges.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../models/app_user.dart';
import '../../attendance/domain/attendance_providers.dart';
import '../../auth/data/account_deletion_service.dart';
import '../../auth/domain/account_providers.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../notifications/domain/notification_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import 'editable_avatar.dart';

bool get _supportsReminders => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// "v1.0.0 (3)" — helps when a member reports a problem. Null until loaded
/// (and wherever the platform can't say, e.g. in tests).
final _appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
});

/// The member's own profile: how they appear to the club, their standing
/// (points, hours, dues), and their settings. Editing happens on a separate
/// screen (`/edit-profile`) so this page can be a clean, live view.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _deleting = false;

  Future<void> _setRemindersEnabled(String uid, bool value) async {
    try {
      await ref.read(userRepositoryProvider).updateProfile(uid, {'remindersEnabled': value});
      if (value) {
        await ref.read(reminderServiceProvider).requestPermission();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update notification settings. Please try again.")),
        );
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: destructive ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _signOut() async {
    final auth = ref.read(authRepositoryProvider);
    final ok = await _confirm(
      title: 'Sign out?',
      message: "You'll need to sign in again to use the app.",
      action: 'Sign Out',
    );
    if (ok) await auth.signOut();
  }

  Future<void> _info(String title, String message, {String? actionLabel, VoidCallback? onAction}) {
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

  Future<void> _deleteAccount(AppUser me) async {
    final service = ref.read(accountDeletionServiceProvider);
    final auth = ref.read(authRepositoryProvider);
    final admins = (ref.read(approvedMembersProvider).value ?? const []).where((m) => m.isAdmin).length;
    final now = DateTime.now();
    final upcoming = (ref.read(eventsProvider).value ?? const []).where((e) => e.endTime.isAfter(now)).toList();

    if (me.isAdmin && admins <= 1) {
      await _info(
        "You're the only admin",
        'Before deleting your account, make another member an admin '
            '(Directory → their profile → Admin access) so the club is never left without one.',
      );
      return;
    }
    if (!service.signedInRecently) {
      await _info(
        'Sign in again first',
        'For your security, please sign out and sign back in, then delete your account right away.',
        actionLabel: 'Sign Out',
        onAction: auth.signOut,
      );
      return;
    }
    if (!await _confirm(
      title: 'Delete your account?',
      message: 'This permanently deletes your Steam Club account: your profile, points and volunteer history, '
          'and your spot in upcoming volunteer shifts. This can\'t be undone.',
      action: 'Delete Account',
      destructive: true,
    )) {
      return;
    }

    setState(() => _deleting = true);
    try {
      await service.deleteMyAccount(me: me, upcomingEvents: upcoming, isOnlyAdmin: admins <= 1);
      // Success signs the member out, which moves the app to the login screen.
    } on RecentLoginRequiredException {
      if (mounted) await _info('Sign in again first', 'Please sign out and sign back in, then try again.');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete your account. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(onPressed: () => context.push('/edit-profile'), child: const Text('Edit')),
          ),
        ],
      ),
      body: appUserAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return Stack(
            children: [
              _ProfileBody(
                user: user,
                onSetReminders: (value) => _setRemindersEnabled(user.uid, value),
                onSignOut: _signOut,
                onDeleteAccount: () => _deleteAccount(user),
              ),
              if (_deleting)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            'Deleting your account…',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load your profile.", error: err),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.user,
    required this.onSetReminders,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final AppUser user;
  final ValueChanged<bool> onSetReminders;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  static String _hours(double h) => h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final points = ref.watch(myPointsSummaryProvider);
    final hours = ref.watch(volunteerHoursProvider).value?[user.uid] ?? 0;
    final isTopVolunteer = ref.watch(topVolunteerUidsProvider).contains(user.uid);
    final pendingCount = user.isAdmin ? (ref.watch(pendingUsersProvider).value?.length ?? 0) : 0;
    final version = ref.watch(_appVersionProvider).value;
    final since = user.createdAt;

    final headline = [
      if (since != null) 'Member since ${DateFormat.yMMM().format(since)}',
      if (user.memberNumber != null && user.memberNumber!.isNotEmpty) '#${user.memberNumber}',
    ].join(' · ');

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              color: colors.primaryContainer,
              child: Column(
                children: [
                  EditableAvatar(user: user, radius: 52),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  if (headline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      headline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (MemberBadges.hasAny(user, isTopVolunteer)) ...[
                    const SizedBox(height: 12),
                    MemberBadges(user: user, isTopVolunteer: isTopVolunteer, alignment: WrapAlignment.center),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.star_outline,
                      value: '${points.total}',
                      label: points.total == 1 ? 'Point' : 'Points',
                      showChevron: true,
                      onTap: () => context.push('/my-points'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.volunteer_activism_outlined,
                      value: _hours(hours),
                      label: 'Volunteer hrs',
                      onTap: () => context.push('/my-points'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.how_to_reg_outlined,
                      value: '${points.checkIns.length}',
                      label: points.checkIns.length == 1 ? 'Meeting' : 'Meetings',
                      onTap: () => context.push('/my-points'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'Contact',
              icon: Icons.contacts_outlined,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (user.email.isNotEmpty)
                  _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
                if (user.email.isNotEmpty) const Divider(height: 1),
                if (user.phone.isNotEmpty)
                  _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: formatPhoneNumber(user.phone))
                else
                  ListTile(
                    leading: Icon(Icons.phone_outlined, color: colors.primary),
                    title: Text('Add your phone number', style: TextStyle(color: colors.primary)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/edit-profile'),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              child: Text(
                'Other club members can see this in the directory.',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: user.kids.length == 1 ? 'Family · 1 child' : 'Family',
              icon: Icons.child_care_outlined,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (user.kids.isEmpty)
                  ListTile(
                    leading: Icon(Icons.add_circle_outline, color: colors.primary),
                    title: Text('Add your children', style: TextStyle(color: colors.primary)),
                    subtitle: const Text('Names and grades at the school'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/edit-profile'),
                  )
                else
                  for (var i = 0; i < user.kids.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.child_care_outlined,
                      label: user.kids[i].grade.isNotEmpty ? user.kids[i].grade : 'Child',
                      value: user.kids[i].name,
                    ),
                  ],
              ],
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'Membership',
              icon: Icons.badge_outlined,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (since != null) ...[
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member since',
                    value: DateFormat.yMMMM().format(since),
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.hourglass_bottom_outlined,
                    label: 'Membership length',
                    value: formatMembershipDuration(since),
                  ),
                  const Divider(height: 1),
                ],
                if (user.memberNumber != null && user.memberNumber!.isNotEmpty) ...[
                  _InfoRow(icon: Icons.tag, label: 'Member #', value: user.memberNumber!),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: Icon(
                    user.duesPaid ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: user.duesPaid ? Colors.green.shade700 : colors.error,
                  ),
                  title: Text(
                    user.duesPaid ? 'Paid' : 'Not paid',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: user.duesPaid ? Colors.green.shade700 : colors.error,
                    ),
                  ),
                  subtitle: const Text('Dues'),
                ),
              ],
            ),
            if (_supportsReminders) ...[
              const SizedBox(height: 20),
              SectionCard(
                title: 'Notifications',
                icon: Icons.notifications_outlined,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  SwitchListTile(
                    title: const Text('Event & volunteer reminders'),
                    subtitle: const Text(
                      "Get a reminder on this device the day before a volunteer shift you've signed up for.",
                    ),
                    value: user.remindersEnabled,
                    onChanged: onSetReminders,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SectionCard(
              title: 'More',
              icon: Icons.more_horiz,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                ListTile(
                  leading: Icon(Icons.leaderboard_outlined, color: colors.primary),
                  title: const Text('Volunteer leaderboard'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/leaderboard'),
                ),
                if (user.isAdmin) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.fact_check_outlined, color: colors.primary),
                    title: const Text('Review pending approvals'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pendingCount > 0) Badge(label: Text('$pendingCount')),
                        if (pendingCount > 0) const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/admin/approvals'),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextButton(
                onPressed: onDeleteAccount,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                child: const Text('Delete Account'),
              ),
            ),
            if (version != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Steam Club · $version',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(label),
    );
  }
}
