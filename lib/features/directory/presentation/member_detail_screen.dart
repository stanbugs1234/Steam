import 'dart:io' show Platform;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/phone_format.dart';
import '../../../core/widgets/admin_badge.dart';
import '../../../core/widgets/error_state.dart';
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
          SnackBar(content: Text('Could not open Contacts: $e')),
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
          SnackBar(content: Text('Could not update admin access: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _settingRole = false);
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
                        backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
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
                      value: _formatMembershipDuration(member.createdAt!),
                    ),
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
                  ],
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load this member.", error: err),
      ),
    );
  }
}

String _formatMembershipDuration(DateTime since) {
  final now = DateTime.now();
  var months = (now.year - since.year) * 12 + (now.month - since.month);
  if (now.day < since.day) months -= 1;
  if (months < 1) return 'New member';

  final years = months ~/ 12;
  final remainingMonths = months % 12;
  if (years == 0) return '$remainingMonths month${remainingMonths == 1 ? '' : 's'}';
  if (remainingMonths == 0) return '$years year${years == 1 ? '' : 's'}';
  return '$years year${years == 1 ? '' : 's'} $remainingMonths month${remainingMonths == 1 ? '' : 's'}';
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
