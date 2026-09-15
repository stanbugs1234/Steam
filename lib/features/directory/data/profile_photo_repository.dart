import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoRepository {
  ProfilePhotoRepository(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadProfilePhoto(String uid, XFile file) async {
    final ref = _storage.ref('profile_photos/$uid.jpg');
    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(File(file.path), SettableMetadata(contentType: 'image/jpeg'));
    }
    return ref.getDownloadURL();
  }
}
