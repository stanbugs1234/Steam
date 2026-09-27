import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/section_card.dart';
import '../domain/club_config_providers.dart';

/// Admin-only: view and change the club's sign-up join code. Anyone who
/// enters this code on the sign-up screen gets past that first step — it's a
/// volume filter to keep unaffiliated people from finding the app and
/// signing up, not a security boundary (admin approval still decides who
/// actually gets in). Change it here any time it's shared more widely than
/// intended.
class ClubSettingsScreen extends ConsumerStatefulWidget {
  const ClubSettingsScreen({super.key});

  @override
  ConsumerState<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends ConsumerState<ClubSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _saving = false;
  bool _editing = false;
  String? _prefilledFrom;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(clubConfigRepositoryProvider).setJoinCode(_codeCtrl.text.trim());
      if (mounted) setState(() => _editing = false);
      messenger.showSnackBar(const SnackBar(content: Text('Join code updated.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: "Couldn't save the join code."))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joinCodeAsync = ref.watch(joinCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Club Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          SectionCard(
            title: 'Sign-up join code',
            icon: Icons.vpn_key_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: joinCodeAsync.when(
                  data: (code) {
                    // Prefill the field with the live value the first time it
                    // arrives, so editing starts from what's actually set —
                    // but never stomp on something the admin is mid-typing.
                    if (!_editing && _prefilledFrom != code) {
                      _prefilledFrom = code;
                      _codeCtrl.text = code ?? '';
                    }
                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            code == null
                                ? "No join code is set — anyone can start signing up."
                                : 'Members enter this on the sign-up screen before choosing phone or email.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Join code'),
                            onChanged: (_) => setState(() => _editing = true),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text(friendlyError(err, fallback: "Couldn't load the join code.")),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
