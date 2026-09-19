import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'share_content.dart';

/// Logical size of the flyer. Captured at pixelRatio 3 → 1080×1440 image.
const flyerSize = Size(360, 480);

/// A branded promo card for a post or event. Always light and always the same
/// size, independent of the app's theme and the device's text-size setting,
/// because it is captured as an image and sent to people outside the app.
class ShareFlyer extends StatelessWidget {
  const ShareFlyer({super.key, required this.content});

  final ShareContent content;

  static const _ink = Color(0xFF1C1C1C);
  static const _muted = Color(0xFF5B5B5B);

  @override
  Widget build(BuildContext context) {
    final hasImage = content.imageUrl != null;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: flyerSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FlyerHeader(),
              if (hasImage)
                SizedBox(
                  height: 150,
                  child: Image(
                    image: CachedNetworkImageProvider(content.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const ColoredBox(color: Color(0xFFEEEEEE)),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: brandAccent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          content.kicker.toUpperCase(),
                          style: const TextStyle(
                            color: brandAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        content.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontSize: 25, height: 1.15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      if (content.dateLine != null) _FlyerRow(icon: Icons.schedule_outlined, text: content.dateLine!),
                      if (content.locationLine != null)
                        _FlyerRow(icon: Icons.place_outlined, text: content.locationLine!),
                      // Whatever height is left goes to the description, cut to
                      // whole lines so it never runs into the bottom stripe.
                      Expanded(child: _FlyerBlurb(text: content.blurb)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8, child: ColoredBox(color: brandAccent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlyerHeader extends StatelessWidget {
  const _FlyerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: brandAccent,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/icon/icon.png', width: 34, height: 34, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ST. EDWARD ASSOCIATION OF MEN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlyerRow extends StatelessWidget {
  const _FlyerRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: brandAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ShareFlyer._ink, fontSize: 14, height: 1.3, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlyerBlurb extends StatelessWidget {
  const _FlyerBlurb({required this.text});

  final String text;

  static const _style = TextStyle(color: ShareFlyer._muted, fontSize: 14, height: 1.4);

  @override
  Widget build(BuildContext context) {
    final blurb = shortBlurb(text, max: 400);
    if (blurb.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const lineHeight = 14 * 1.4;
        final lines = ((constraints.maxHeight - 4) / lineHeight).floor();
        if (lines < 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(blurb, maxLines: lines, overflow: TextOverflow.ellipsis, style: _style),
        );
      },
    );
  }
}
