import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_providers.dart';
import '../domain/news_providers.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(newsFeedProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => context.push('/news/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: feedAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(child: Text('No news yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/news/${post.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.imageUrl != null)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(post.imageUrl!, fit: BoxFit.cover),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post.title, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              post.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                post.authorName,
                                if (post.createdAt != null) DateFormat.yMMMd().add_jm().format(post.createdAt!),
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading news: $err')),
      ),
    );
  }
}
