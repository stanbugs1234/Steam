import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/children_form_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/app_user.dart';
import '../../../models/child_info.dart';
import '../../auth/domain/auth_providers.dart';
import '../../notifications/domain/notification_providers.dart';
import '../domain/directory_providers.dart';

bool get _supportsReminders => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  List<ChildInfo> _kids = [];

  AppUser? _loadedFor;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  void _syncControllers(AppUser user) {
    if (_loadedFor?.uid == user.uid) return;
    _loadedFor = user;
    _nameCtrl.text = user.name;
    _phoneCtrl.text = user.phone;
    _kids = user.kids;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(userRepositoryProvider).updateProfile(uid, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'kids': _kids.map((k) => k.toMap()).toList(),
      });
      setState(() => _message = 'Profile updated.');
    } catch (e) {
      setState(() => _message = 'Could not save changes: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setRemindersEnabled(String uid, bool value) async {
    try {
      await ref.read(userRepositoryProvider).updateProfile(uid, {'remindersEnabled': value});
      if (value) {
        await ref.read(reminderServiceProvider).requestPermission();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update notification settings: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadPhoto(String uid) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await ref.read(profilePhotoRepositoryProvider).uploadProfilePhoto(uid, file);
      await ref.read(userRepositoryProvider).updateProfile(uid, {'photoUrl': url});
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not upload photo: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: appUserAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          _syncControllers(user);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                              child: user.photoUrl == null
                                  ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: _uploadingPhoto
                                    ? Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.camera_alt, size: 16),
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        onPressed: () => _pickAndUploadPhoto(user.uid),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SectionCard(
                        title: 'Your Info',
                        icon: Icons.person_outline,
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: TextFormField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Full name'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          if (user.email.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: TextFormField(
                                initialValue: user.email,
                                enabled: false,
                                decoration: const InputDecoration(labelText: 'Email'),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Phone'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: 'Family',
                        icon: Icons.child_care_outlined,
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ChildrenFormField(initialChildren: _kids, onChanged: (kids) => _kids = kids),
                          ),
                        ],
                      ),
                      if (_supportsReminders) ...[
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Notifications',
                          icon: Icons.notifications_outlined,
                          padding: EdgeInsets.zero,
                          children: [
                            SwitchListTile(
                              title: const Text('Event & volunteer reminders'),
                              subtitle: const Text(
                                "Get a reminder on this device the day before a volunteer shift you've signed up for.",
                              ),
                              value: user.remindersEnabled,
                              onChanged: (value) => _setRemindersEnabled(user.uid, value),
                            ),
                          ],
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : () => _save(user.uid),
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save Changes'),
                      ),
                      if (user.isAdmin) ...[
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Admin',
                          icon: Icons.admin_panel_settings_outlined,
                          padding: EdgeInsets.zero,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.fact_check_outlined),
                              title: const Text('Review Pending Approvals'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/admin/approvals'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load your profile.", error: err),
      ),
    );
  }
}
