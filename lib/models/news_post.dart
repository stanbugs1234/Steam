import 'package:cloud_firestore/cloud_firestore.dart';

class NewsPost {
  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final String? imageUrl;
  final DateTime? createdAt;

  const NewsPost({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    this.imageUrl,
    this.createdAt,
  });

  factory NewsPost.fromFirestore(String id, Map<String, dynamic> data) {
    return NewsPost(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'authorId': authorId,
      'authorName': authorName,
      'imageUrl': imageUrl,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
    };
  }
}
