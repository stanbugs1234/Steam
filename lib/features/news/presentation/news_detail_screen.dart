import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_providers.dart';
import '../domain/news_providers.dart';

class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(newsFeedProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        actions: [
          if (isAdmin)
            feedAsync.maybeWhen(
              data: (posts) {
                final post = posts.firstWhereOrNull((p) => p.id == postId);
                if (post == null) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push('/news/${post.id}/edit'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete post?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(newsRepositoryProvider).deletePost(post.id);
                          if (context.mounted) context.pop();
                        }
                      },
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: feedAsync.when(
        data: (posts) {
          final post = posts.firstWhereOrNull((p) => p.id == postId);
          if (post == null) {
            return const Center(child: Text('Post not found.'));
          }
          return ListView(
            children: [
              if (post.imageUrl != null) Image.network(post.imageUrl!, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      [
                        post.authorName,
                        if (post.createdAt != null) DateFormat.yMMMd().add_jm().format(post.createdAt!),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading post: $err')),
      ),
    );
  }
}
