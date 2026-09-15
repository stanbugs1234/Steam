import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/news_post.dart';

class NewsRepository {
  NewsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _newsRef => _firestore.collection('news');

  /// Reserves a document ID before the post is written, so an image can be
  /// uploaded (named after the post ID) prior to creating the post doc.
  String newPostId() => _newsRef.doc().id;

  Stream<List<NewsPost>> watchFeed() {
    return _newsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NewsPost.fromFirestore(d.id, d.data())).toList());
  }

  Future<void> createPost(NewsPost post) {
    return _newsRef.doc(post.id).set(post.toFirestore());
  }

  Future<void> updatePost(String id, Map<String, dynamic> fields) {
    return _newsRef.doc(id).update(fields);
  }

  Future<void> deletePost(String id) {
    return _newsRef.doc(id).delete();
  }
}
