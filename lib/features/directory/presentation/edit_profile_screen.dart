import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/phone_format.dart';
import '../../../core/widgets/children_form_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/app_user.dart';
import '../../../models/child_info.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/profile_draft.dart';
import 'editable_avatar.dart';

/// Edit name, phone and family. Save lives in the app bar and only lights up
/// once something has changed; leaving with unsaved edits asks first.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // The form snapshots the profile as it is now; later live updates (say an
    // admin fixing your phone) must not overwrite what you're typing.
    return _EditProfileForm(key: ValueKey(user.uid), initialUser: user);
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({super.key, required this.initialUser});

  final AppUser initialUser;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  /// The profile as it was when this screen opened — what "changed" is
  /// measured against.
  late final AppUser _initialUser = widget.initialUser;
  late final ProfileDraft _initial = ProfileDraft.fromUser(_initialUser);
  List<ChildInfo> _kids = const [];

  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _initialUser.name;
    _phoneCtrl.text = formatPhoneNumber(_initialUser.phone);
    _kids = _initialUser.kids;
    _nameCtrl.addListener(_onChanged);
    _phoneCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  ProfileDraft get _draft => ProfileDraft.fromForm(name: _nameCtrl.text, phone: _phoneCtrl.text, kids: _kids);

  bool get _dirty => !_draft.sameAs(_initial);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _initialUser;
    final changes = _draft.changesFrom(_initial);
    final users = ref.read(userRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      if (changes.isNotEmpty) await users.updateProfile(user.uid, changes);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
      // Let PopScope see that there's nothing left to discard before popping.
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save your changes. Check your connection and try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text("You have unsaved changes that will be lost."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Editing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live copy, for the photo (it can change while this screen is open).
    final user = ref.watch(currentAppUserProvider).value ?? _initialUser;
    final theme = Theme.of(context);
    final dirty = _dirty;

    return PopScope(
      canPop: !dirty || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: dirty && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: EditableAvatar(user: user)),
                    const SizedBox(height: 24),
                    SectionCard(
                      title: 'Your Info',
                      icon: Icons.person_outline,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: const InputDecoration(labelText: 'Full name'),
                            validator: ProfileDraft.validateName,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, user.email.isNotEmpty ? 4 : 16),
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [UsPhoneInputFormatter()],
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: const InputDecoration(labelText: 'Phone'),
                            // Only insist on a valid number if it was edited, so a
                            // roster-imported number in an unusual format doesn't
                            // block saving an unrelated change.
                            validator: (v) => _draft.phoneDigits == _initial.phoneDigits
                                ? null
                                : ProfileDraft.validatePhone(v),
                          ),
                        ),
                        if (user.email.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.email_outlined),
                            title: Text(user.email),
                            subtitle: const Text("Sign-in email — can't be changed here"),
                            trailing: Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                      child: Text(
                        'Other club members can see your phone number and email in the directory.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      title: 'Family',
                      icon: Icons.child_care_outlined,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ChildrenFormField(
                            initialChildren: _kids,
                            onChanged: (kids) => setState(() => _kids = kids),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
