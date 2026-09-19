import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/news_post.dart';
import '../../events/domain/event_providers.dart';
import '../../sharing/share_content.dart';
import '../../sharing/share_sheet.dart';

/// Opens the share sheet for [post], pulling date/place from its linked event
/// (if it has one and that event still exists).
void shareNewsPost(BuildContext context, WidgetRef ref, NewsPost post) {
  final event = post.eventId == null
      ? null
      : ref.read(eventsProvider).value?.firstWhereOrNull((e) => e.id == post.eventId);
  showShareSheet(context, ShareContent.fromPost(post, event: event));
}

/// A network photo that shows a neutral placeholder while loading and a quiet
/// fallback if it can't be loaded, instead of a broken image.
class NewsImage extends StatelessWidget {
  const NewsImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      placeholder: (context, url) => ColoredBox(color: colors.surfaceContainerHigh),
      errorWidget: (context, url, error) => ColoredBox(
        color: colors.surfaceContainerHigh,
        child: Center(child: Icon(Icons.image_not_supported_outlined, color: colors.onSurfaceVariant)),
      ),
    );
  }
}

/// Stand-in artwork for posts without a photo: the brand accent with the
/// category icon.
class NewsImageFallback extends StatelessWidget {
  const NewsImageFallback({super.key, required this.category, this.iconSize = 44});

  final NewsCategory category;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandAccent, Color.lerp(brandAccent, Colors.black, 0.35)!],
        ),
      ),
      child: Center(child: Icon(category.icon, size: iconSize, color: Colors.white.withValues(alpha: 0.85))),
    );
  }
}

/// Small rounded label showing a post's category.
class CategoryPill extends StatelessWidget {
  const CategoryPill({super.key, required this.category, this.onImage = false});

  final NewsCategory category;

  /// True when drawn over a photo, where it needs its own contrasting fill.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = onImage ? Colors.black.withValues(alpha: 0.55) : colors.primaryContainer;
    final foreground = onImage ? Colors.white : colors.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
