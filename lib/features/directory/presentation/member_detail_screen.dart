import 'dart:io' show Platform;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/avatar_image.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/membership_duration.dart';
import '../../../core/utils/phone_format.dart';
import '../../../core/widgets/admin_badge.dart';
import '../../../core/widgets/dues_paid_badge.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/new_member_badge.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/top_volunteer_badge.dart';
import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';

class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  bool _settingRole = false;
  bool _settingJoinDate = false;
  bool _settingDues = false;
  bool _settingNewMember = false;

  bool get _supportsContacts => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> _addToContacts(BuildContext context, AppUser member) async {
    final nameParts = member.name.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : member.name;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null;

    final contact = Contact(
      name: Name(first: firstName, last: lastName),
      phones: member.phone.isNotEmpty ? [Phone(number: member.phone)] : const [],
      emails: member.email.isNotEmpty ? [Email(address: member.email)] : const [],
      organizations: const [Organization(name: 'STEAM Club')],
    );

    try {
      await FlutterContacts.native.showCreator(contact: contact);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, fallback: "Couldn't open Contacts."))),
        );
      }
    }
  }

  Future<void> _setRole(AppUser member, bool makeAdmin) async {
    if (!makeAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove admin access?'),
          content: Text('${member.name} will lose access to admin tools like Pending Approvals.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove Access')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _settingRole = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .setRole(member.uid, makeAdmin ? UserRole.admin : UserRole.member);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, fallback: "Couldn't update admin access."))),
        );
      }
    } finally {
      if (mounted) setState(() => _settingRole = false);
    }
  }

  Future<void> _editJoinDate(AppUser member) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: member.createdAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;

    setState(() => _settingJoinDate = true);
    try {
      await ref.read(userRepositoryProvider).setCreatedAt(member.uid, picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, fallback: "Couldn't update the join date."))),
        );
      }
    } finally {
      if (mounted) setState(() => _settingJoinDate = false);
    }
  }

  Future<void> _setDuesPaid(AppUser member, bool paid) async {
    setState(() => _settingDues = true);
    try {
      await ref.read(userRepositoryProvider).setDuesPaid(member.uid, paid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, fallback: "Couldn't update dues status."))),
        );
      }
    } finally {
      if (mounted) setState(() => _settingDues = false);
    }
  }

  Future<void> _setIsNewMember(AppUser member, bool isNewMember) async {
    setState(() => _settingNewMember = true);
    try {
      await ref.read(userRepositoryProvider).setIsNewMember(member.uid, isNewMember);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, fallback: "Couldn't update new member status."))),
        );
      }
    } finally {
      if (mounted) setState(() => _settingNewMember = false);
    }
  }

  /// Asks an admin for a new value for one of a member's roster records
  /// (member number, points) and saves it. Clearing the box clears the value.
  Future<void> _editRosterField({
    required String title,
    required String? current,
    required bool numeric,
    required Future<void> Function(String? value) save,
  }) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: const InputDecoration(helperText: 'Leave empty to clear'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    try {
      await save(result.isEmpty ? null : result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't update ${title.toLowerCase()}. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(approvedMembersProvider);
    final viewer = ref.watch(currentAppUserProvider).value;
    final topVolunteerUids = ref.watch(topVolunteerUidsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: membersAsync.when(
        data: (members) {
          final member = members.where((m) => m.uid == widget.uid).firstOrNull;
          if (member == null) {
            return const Center(child: Text('Member not found.'));
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                color: colorScheme.primaryContainer,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: colorScheme.surface,
                        backgroundImage: member.photoUrl != null ? avatarImage(member.photoUrl!, 56) : null,
                        child: member.photoUrl == null
                            ? Text(
                                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(color: colorScheme.onSurface),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      member.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                    if (member.isAdmin) ...[
                      const SizedBox(height: 6),
                      const AdminBadge(),
                    ],
                    if (topVolunteerUids.contains(member.uid)) ...[
                      const SizedBox(height: 6),
                      const TopVolunteerBadge(),
                    ],
                    if (member.isNewMember) ...[
                      const SizedBox(height: 6),
                      const NewMemberBadge(),
                    ],
                    if (member.duesPaid) ...[
                      const SizedBox(height: 6),
                      const DuesPaidBadge(),
                    ],
                    if (_supportsContacts) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _addToContacts(context, member),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add to Contacts'),
                      ),
                    ],
                  ],
                ),
              ),
              if (member.createdAt != null) ...[
                const SizedBox(height: 20),
                SectionCard(
                  title: 'Membership',
                  children: [
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Member since',
                      value: DateFormat.yMMMM().format(member.createdAt!),
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.hourglass_bottom_outlined,
                      label: 'Membership length',
                      value: formatMembershipDuration(member.createdAt!),
                    ),
                    if (member.memberNumber != null) ...[
                      const Divider(height: 1),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Member #',
                        value: member.memberNumber!,
                      ),
                    ],
                    if (member.clubPoints != null) ...[
                      const Divider(height: 1),
                      _InfoRow(
                        icon: Icons.star_outline,
                        label: 'Club points',
                        value: '${member.clubPoints}',
                      ),
                    ],
                  ],
                ),
              ],
              if (member.email.isNotEmpty || member.phone.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Contact Info',
                  children: [
                    if (member.email.isNotEmpty)
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: member.email,
                        onTap: () => launchUrl(Uri(scheme: 'mailto', path: member.email)),
                      ),
                    if (member.email.isNotEmpty && member.phone.isNotEmpty) const Divider(height: 1),
                    if (member.phone.isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: formatPhoneNumber(member.phone),
                        onTap: () => launchUrl(Uri(scheme: 'tel', path: member.phone)),
                      ),
                  ],
                ),
              ],
              if (member.kids.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: member.kids.length == 1 ? '1 Child Enrolled' : '${member.kids.length} Children Enrolled',
                  children: [
                    for (var i = 0; i < member.kids.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _InfoRow(
                        icon: Icons.child_care_outlined,
                        label: member.kids[i].grade.isNotEmpty ? member.kids[i].grade : 'Child',
                        value: member.kids[i].name,
                      ),
                    ],
                  ],
                ),
              ],
              if (viewer != null && viewer.isAdmin) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Admin Tools',
                  icon: Icons.admin_panel_settings_outlined,
                  padding: EdgeInsets.zero,
                  children: [
                    SwitchListTile(
                      title: const Text('Admin access'),
                      subtitle: Text(
                        member.uid == viewer.uid
                            ? "You can't change your own admin access here."
                            : 'Grants access to Pending Approvals and this admin toggle.',
                      ),
                      value: member.isAdmin,
                      onChanged: _settingRole || member.uid == viewer.uid
                          ? null
                          : (value) => _setRole(member, value),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Member since'),
                      subtitle: Text(
                        member.createdAt != null ? DateFormat.yMMMd().format(member.createdAt!) : 'Not set',
                      ),
                      trailing: _settingJoinDate
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.edit_outlined),
                      onTap: _settingJoinDate ? null : () => _editJoinDate(member),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Dues paid'),
                      subtitle: const Text('Shows a "Dues Paid" badge on this member\'s profile.'),
                      value: member.duesPaid,
                      onChanged: _settingDues ? null : (value) => _setDuesPaid(member, value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('New member'),
                      subtitle: const Text('Shows a "New Member" badge on this member\'s profile.'),
                      value: member.isNewMember,
                      onChanged: _settingNewMember ? null : (value) => _setIsNewMember(member, value),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Member #'),
                      subtitle: Text(member.memberNumber ?? 'Not set'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editRosterField(
                        title: 'Member #',
                        current: member.memberNumber,
                        numeric: false,
                        save: (v) => ref.read(userRepositoryProvider).setMemberNumber(member.uid, v),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Roster points'),
                      subtitle: Text(
                        '${member.yearlyPoints ?? 0} — counts toward the member\'s point total on Home and Profile',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editRosterField(
                        title: 'Roster points',
                        current: member.yearlyPoints?.toString(),
                        numeric: true,
                        save: (v) => ref.read(userRepositoryProvider).setYearlyPoints(member.uid, v == null ? null : int.parse(v)),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Club points'),
                      subtitle: Text('${member.clubPoints ?? 0} — cumulative, shown under Membership'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editRosterField(
                        title: 'Club points',
                        current: member.clubPoints?.toString(),
                        numeric: true,
                        save: (v) => ref.read(userRepositoryProvider).setClubPoints(member.uid, v == null ? null : int.parse(v)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load this member.", error: err, onRetry: () => ref.invalidate(approvedMembersProvider)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(label),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
