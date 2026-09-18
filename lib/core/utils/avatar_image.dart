import 'package:flutter/widgets.dart';

/// A [CircleAvatar.backgroundImage] sized to how large it's actually
/// displayed, so Flutter decodes it at that resolution instead of full
/// source size (member photos are often several megapixels).
ImageProvider avatarImage(String url, double radius) {
  final px = (radius * 2 * 3).round(); // covers up to ~3x device pixel ratio
  return ResizeImage(NetworkImage(url), width: px, height: px);
}
