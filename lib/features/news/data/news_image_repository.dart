import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class NewsImageRepository {
  NewsImageRepository(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadNewsImage(String postId, XFile file) async {
    final ref = _storage.ref('news_images/$postId.jpg');
    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(File(file.path), SettableMetadata(contentType: 'image/jpeg'));
    }
    return ref.getDownloadURL();
  }
}
