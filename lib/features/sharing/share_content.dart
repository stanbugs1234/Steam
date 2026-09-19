import 'package:intl/intl.dart';

import '../../models/club_event.dart';
import '../../models/news_post.dart';

const clubDisplayName = 'St. Edward Association of Men';

/// Everything needed to build a shareable flyer and text message for a post or
/// event. Plain data so the message builder can be tested without Flutter.
class ShareContent {
  const ShareContent({
    required this.kicker,
    required this.title,
    this.dateLine,
    this.locationLine,
    this.blurb = '',
    this.imageUrl,
  });

  /// Short label above the title, e.g. "Guest Speaker" or "Upcoming Event".
  final String kicker;
  final String title;
  final String? dateLine;
  final String? locationLine;
  final String blurb;
  final String? imageUrl;

  factory ShareContent.fromEvent(ClubEvent event) {
    return ShareContent(
      kicker: 'Upcoming Event',
      title: event.title,
      dateLine: formatEventWhen(event.startTime, event.endTime),
      locationLine: event.location.trim().isEmpty ? null : event.location.trim(),
      blurb: event.description,
    );
  }

  /// If the post promotes an [event], the event supplies the date and place.
  factory ShareContent.fromPost(NewsPost post, {ClubEvent? event}) {
    return ShareContent(
      kicker: post.category.label,
      title: post.title,
      dateLine: event == null ? null : formatEventWhen(event.startTime, event.endTime),
      locationLine: (event == null || event.location.trim().isEmpty) ? null : event.location.trim(),
      blurb: post.body,
      imageUrl: post.imageUrl,
    );
  }
}

/// "Thu, Oct 9, 2026 · 6:30 PM – 8:00 PM", or both full dates when the event
/// spans days.
String formatEventWhen(DateTime start, DateTime end) {
  final sameDay = DateFormat.yMd().format(start) == DateFormat.yMd().format(end);
  if (sameDay) {
    return '${DateFormat.yMMMEd().format(start)} · ${DateFormat.jm().format(start)} – ${DateFormat.jm().format(end)}';
  }
  return '${DateFormat.yMMMEd().add_jm().format(start)} – ${DateFormat.yMMMEd().add_jm().format(end)}';
}

/// Collapses whitespace and cuts [text] at a word boundary near [max]
/// characters, adding an ellipsis when something was dropped.
String shortBlurb(String text, {int max = 280}) {
  final flat = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (flat.length <= max) return flat;
  final cut = flat.substring(0, max);
  final lastSpace = cut.lastIndexOf(' ');
  final base = lastSpace > max ~/ 2 ? cut.substring(0, lastSpace) : cut;
  return '${base.trimRight()}…';
}

/// The text message that accompanies (or replaces) the flyer image.
String buildShareMessage(ShareContent content) {
  final lines = <String>[
    content.title,
    '',
    if (content.dateLine != null) '🗓 ${content.dateLine}',
    if (content.locationLine != null) '📍 ${content.locationLine}',
  ];
  if (content.dateLine != null || content.locationLine != null) lines.add('');

  final blurb = shortBlurb(content.blurb);
  if (blurb.isNotEmpty) {
    lines
      ..add(blurb)
      ..add('');
  }
  lines.add('— $clubDisplayName');
  return lines.join('\n');
}
