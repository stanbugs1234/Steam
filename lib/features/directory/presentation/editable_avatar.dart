import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/avatar_image.dart';
import '../../../models/app_user.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/directory_providers.dart';

bool get _canUseCamera => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

enum _PhotoAction { camera, library, remove }

/// The member's own avatar with a clear "change photo" affordance. Tapping
/// anywhere on it opens a sheet to take a photo, choose one, or remove the
/// current one; uploading state and errors are handled here so both the
/// Profile header and the Edit screen behave identically.
class EditableAvatar extends ConsumerStatefulWidget {
  const EditableAvatar({super.key, required this.user, this.radius = 48});

  final AppUser user;
  final double radius;

  @override
  ConsumerState<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends ConsumerState<EditableAvatar> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSheet() async {
    final hasPhoto = widget.user.photoUrl != null;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canUseCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, _PhotoAction.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, _PhotoAction.library),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('Remove photo', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    switch (action) {
      case _PhotoAction.camera:
        await _pick(ImageSource.camera);
      case _PhotoAction.library:
        await _pick(ImageSource.gallery);
      case _PhotoAction.remove:
        await _remove();
      case null:
        break;
    }
  }

  Future<void> _pick(ImageSource source) async {
    final uid = widget.user.uid;
    final photos = ref.read(profilePhotoRepositoryProvider);
    final users = ref.read(userRepositoryProvider);

    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 85);
    } catch (_) {
      _snack(source == ImageSource.camera
          ? "Couldn't open the camera. Check that camera access is allowed in Settings."
          : "Couldn't open your photo library. Check that photo access is allowed in Settings.");
      return;
    }
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final url = await photos.uploadProfilePhoto(uid, file);
      await users.updateProfile(uid, {'photoUrl': url});
    } catch (_) {
      _snack("Couldn't upload your photo. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final uid = widget.user.uid;
    final photos = ref.read(profilePhotoRepositoryProvider);
    final users = ref.read(userRepositoryProvider);

    setState(() => _busy = true);
    try {
      await users.updateProfile(uid, {'photoUrl': null});
      // Best-effort: the profile no longer points at the file either way.
      try {
        await photos.deleteProfilePhoto(uid);
      } catch (_) {}
    } catch (_) {
      _snack("Couldn't remove your photo. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = widget.user;
    final radius = widget.radius;

    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: _busy ? null : _openSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: colors.shadow.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: CircleAvatar(
                radius: radius,
                backgroundColor: colors.surface,
                backgroundImage: user.photoUrl != null ? avatarImage(user.photoUrl!, radius) : null,
                child: user.photoUrl == null
                    ? Text(
                        user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(color: colors.onSurface),
                      )
                    : null,
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4)),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: Icon(Icons.photo_camera, size: 18, color: colors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
