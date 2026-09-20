import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../models/news_post.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/news_providers.dart';
import '../domain/relative_time.dart';
import 'news_widgets.dart';

class NewsFeedScreen extends ConsumerStatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  ConsumerState<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends ConsumerState<NewsFeedScreen> {
  NewsCategory? _filter;

  /// Pinned posts first, then the feed's existing newest-first order.
  List<NewsPost> _visible(List<NewsPost> posts) {
    final filtered = _filter == null ? posts : posts.where((p) => p.category == _filter).toList();
    return [...filtered.where((p) => p.pinned), ...filtered.where((p) => !p.pinned)];
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(newsFeedProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              heroTag: 'news_fab',
              onPressed: () => context.push('/news/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: feedAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyState(icon: Icons.article_outlined, message: 'No news yet.');
          }
          final visible = _visible(posts);
          return Column(
            children: [
              _CategoryFilterBar(
                selected: _filter,
                onSelected: (c) => setState(() => _filter = c),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        icon: _filter!.icon,
                        message: 'No ${_filter!.label.toLowerCase()} posts yet.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: visible.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final post = visible[index];
                          return index == 0
                              ? _FeaturedPostCard(post: post)
                              : _PostCard(post: post);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load news right now.", error: err, onRetry: () => ref.invalidate(newsFeedProvider)),
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.selected, required this.onSelected});

  final NewsCategory? selected;
  final ValueChanged<NewsCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final category in NewsCategory.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(category.label),
              selected: selected == category,
              onSelected: (_) => onSelected(selected == category ? null : category),
            ),
          ],
        ],
      ),
    );
  }
}

String _metaLine(NewsPost post) {
  return [
    if (post.authorName.isNotEmpty) post.authorName,
    if (post.createdAt != null) relativeTime(post.createdAt!),
  ].join(' · ');
}

/// The top post: full-width photo with the title over a dark gradient.
class _FeaturedPostCard extends ConsumerWidget {
  const _FeaturedPostCard({required this.post});

  final NewsPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/news/${post.id}'),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              post.imageUrl != null
                  ? NewsImage(url: post.imageUrl!)
                  : NewsImageFallback(category: post.category, iconSize: 64),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CategoryPill(category: post.category, onImage: true),
                    if (post.pinned) const _PinnedBadge(onImage: true),
                  ],
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton(
                  icon: const Icon(Icons.ios_share, color: Colors.white),
                  tooltip: 'Share',
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.35)),
                  onPressed: () => shareNewsPost(context, ref, post),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _metaLine(post),
                      style: textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final NewsPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/news/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CategoryPill(category: post.category),
                        if (post.pinned) const _PinnedBadge(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(_metaLine(post), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: post.imageUrl != null
                          ? NewsImage(url: post.imageUrl!)
                          : NewsImageFallback(category: post.category, iconSize: 32),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share, size: 20),
                    tooltip: 'Share',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => shareNewsPost(context, ref, post),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge({this.onImage = false});

  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Icon(
      Icons.push_pin,
      size: 16,
      color: onImage ? Colors.white : colors.onSurfaceVariant,
    );
  }
}
