import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/legal_links.dart';
import '../../../core/utils/phone_format.dart';
import '../../../models/app_user.dart';
import '../domain/auth_providers.dart';
import 'delete_account_flow.dart';

/// The full-screen "where your request stands" page shared by the waiting and
/// denied screens: an icon and message, what was submitted (so the person can
/// spot a typo), a way to reach the club, sign out, and account deletion.
class AccountStatusView extends ConsumerStatefulWidget {
  const AccountStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.showSubmitted = true,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;

  /// Whether to list the name/phone/email the person submitted.
  final bool showSubmitted;

  @override
  ConsumerState<AccountStatusView> createState() => _AccountStatusViewState();
}

class _AccountStatusViewState extends ConsumerState<AccountStatusView> {
  bool _deleting = false;

  Future<void> _contactClub(AppUser? me) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'STEAM Club account${me == null ? '' : ' — ${me.name}'}'},
    );
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open your email app. You can write to us at $supportEmail.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(currentAppUserProvider).value;
    final submitted = [
      if (me != null && me.name.isNotEmpty) me.name,
      if (me != null && me.phone.isNotEmpty) formatPhoneNumber(me.phone),
      if (me != null && me.email.isNotEmpty) me.email,
    ];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 56, color: widget.iconColor),
                      const SizedBox(height: 16),
                      Text(widget.title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(widget.message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                      if (widget.showSubmitted && submitted.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'What you submitted',
                                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                for (final line in submitted) Text(line, style: theme.textTheme.bodyLarge),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (hasSupportEmail) ...[
                        FilledButton.icon(
                          onPressed: () => _contactClub(me),
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Contact the club'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton(
                        onPressed: () => ref.read(authRepositoryProvider).signOut(),
                        child: const Text('Sign out'),
                      ),
                      if (me != null)
                        TextButton(
                          onPressed: () => confirmAndDeleteAccount(
                            context: context,
                            ref: ref,
                            me: me,
                            onBusy: (busy) {
                              if (mounted) setState(() => _deleting = busy);
                            },
                          ),
                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                          child: const Text('Delete my account'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_deleting)
              const Positioned.fill(
                child: ColoredBox(color: Colors.black54, child: Center(child: CircularProgressIndicator())),
              ),
          ],
        ),
      ),
    );
  }
}
