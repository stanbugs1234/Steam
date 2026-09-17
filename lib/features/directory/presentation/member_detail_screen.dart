import 'dart:io' show Platform;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.uid});

  final String uid;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(approvedMembersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: membersAsync.when(
        data: (members) {
          final member = members.where((m) => m.uid == uid).firstOrNull;
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
                            color: Colors.black.withValues(alpha: 0.15),
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
                                style: TextStyle(fontSize: 40, color: colorScheme.onSurface),
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
                      Chip(
                        label: const Text('Admin'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colorScheme.primary,
                        labelStyle: TextStyle(color: colorScheme.onPrimary),
                      ),
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
                        value: _formatPhoneNumber(member.phone),
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load this member.", error: err),
      ),
    );
  }
}

// US-only for now, matching the fixed +1 prefix used at signup.
String _formatPhoneNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final tenDigits = digits.length == 11 && digits.startsWith('1') ? digits.substring(1) : digits;
  if (tenDigits.length != 10) return raw;
  return '(${tenDigits.substring(0, 3)}) ${tenDigits.substring(3, 6)}-${tenDigits.substring(6)}';
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
      title: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(label),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
