import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/linkified_text.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/news_post.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../../sharing/share_content.dart';
import '../domain/news_providers.dart';
import 'news_widgets.dart';
import '../../../core/widgets/confirm_dialog.dart';

class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({super.key, required this.postId});

  final String postId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, NewsPost post) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete post?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(newsRepositoryProvider).deletePost(post.id);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(newsFeedProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;
    final post = feedAsync.value?.firstWhereOrNull((p) => p.id == postId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        actions: [
          if (post != null)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share',
              onPressed: () => shareNewsPost(context, ref, post),
            ),
          if (post != null && isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit post',
              onPressed: () => context.push('/news/${post.id}/edit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete post',
              onPressed: () => _confirmDelete(context, ref, post),
            ),
          ],
        ],
      ),
      body: feedAsync.when(
        data: (posts) {
          final post = posts.firstWhereOrNull((p) => p.id == postId);
          if (post == null) {
            return const Center(child: Text('Post not found.'));
          }
          return _PostBody(post: post);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load this post.", error: err, onRetry: () => ref.invalidate(newsFeedProvider)),
      ),
    );
  }
}

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post});

  final NewsPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final event = post.eventId == null
        ? null
        : ref.watch(eventsProvider).value?.firstWhereOrNull((e) => e.id == post.eventId);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (post.imageUrl != null)
          AspectRatio(aspectRatio: 16 / 9, child: NewsImage(url: post.imageUrl!)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryPill(category: post.category),
                  if (post.pinned) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.push_pin, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text('Pinned', style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(post.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                [
                  if (post.authorName.isNotEmpty) 'Posted by ${post.authorName}',
                  if (post.createdAt != null) DateFormat.yMMMd().format(post.createdAt!),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (event != null) ...[
          SectionCard(
            title: 'Event details',
            icon: Icons.event_outlined,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(formatEventWhen(event.startTime, event.endTime)),
              ),
              if (event.location.trim().isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.place_outlined), title: Text(event.location.trim())),
              ],
              const Divider(height: 1),
              ListTile(
                title: const Text('View event'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/events/${event.id}'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LinkifiedText(post.body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: FilledButton.icon(
            onPressed: () => shareNewsPost(context, ref, post),
            icon: const Icon(Icons.ios_share),
            label: const Text('Share with a friend'),
          ),
        ),
      ],
    );
  }
}
