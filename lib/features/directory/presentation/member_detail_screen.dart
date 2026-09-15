import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/domain/auth_providers.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(approvedMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: membersAsync.when(
        data: (members) {
          final member = members.where((m) => m.uid == uid).firstOrNull;
          if (member == null) {
            return const Center(child: Text('Member not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                  child: member.photoUrl == null
                      ? Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32))
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(member.name, style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 24),
              if (member.email.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(member.email),
                  onTap: () => launchUrl(Uri(scheme: 'mailto', path: member.email)),
                ),
              if (member.phone.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(member.phone),
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: member.phone)),
                ),
              if (member.kidName.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.child_care_outlined),
                  title: Text(member.kidName),
                  subtitle: member.kidGrade.isNotEmpty ? Text(member.kidGrade) : null,
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading member: $err')),
      ),
    );
  }
}
