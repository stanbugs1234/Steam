import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// What kind of post this is. Stored in Firestore by [name]; posts written
/// before categories existed have no value and read back as [announcement].
enum NewsCategory {
  announcement('Announcement', Icons.campaign_outlined),
  speaker('Guest Speaker', Icons.mic_none_outlined),
  event('Event', Icons.event_outlined),
  community('Community', Icons.volunteer_activism_outlined);

  const NewsCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static NewsCategory fromName(String? name) {
    return NewsCategory.values.firstWhere((c) => c.name == name, orElse: () => NewsCategory.announcement);
  }
}

class NewsPost {
  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final String? imageUrl;
  final DateTime? createdAt;
  final NewsCategory category;
  final bool pinned;

  /// Optional link to a `ClubEvent` this post is promoting.
  final String? eventId;

  const NewsPost({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    this.imageUrl,
    this.createdAt,
    this.category = NewsCategory.announcement,
    this.pinned = false,
    this.eventId,
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
      category: NewsCategory.fromName(data['category'] as String?),
      pinned: data['pinned'] as bool? ?? false,
      eventId: data['eventId'] as String?,
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
      'category': category.name,
      'pinned': pinned,
      'eventId': eventId,
    };
  }
}
