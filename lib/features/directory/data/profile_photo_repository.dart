import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoRepository {
  ProfilePhotoRepository(this._storage);

  final FirebaseStorage _storage;

  Reference _photoRef(String uid) => _storage.ref('profile_photos/$uid.jpg');

  Future<String> uploadProfilePhoto(String uid, XFile file) async {
    final ref = _photoRef(uid);
    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(File(file.path), SettableMetadata(contentType: 'image/jpeg'));
    }
    final url = await ref.getDownloadURL();
    // Every upload overwrites the same object, so its download URL doesn't
    // change — without a changing query value the image cache would keep
    // showing the previous photo.
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Removes the stored photo. A photo that's already gone is not an error.
  Future<void> deleteProfilePhoto(String uid) async {
    try {
      await _photoRef(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
