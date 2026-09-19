import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/news/domain/relative_time.dart';
import 'package:steam_app/features/sharing/share_content.dart';
import 'package:steam_app/models/club_event.dart';
import 'package:steam_app/models/news_post.dart';

ClubEvent _event({String location = 'Parish Hall', String description = 'Come join us.'}) {
  return ClubEvent(
    id: 'e1',
    title: 'Speaker Night',
    description: description,
    location: location,
    startTime: DateTime(2026, 10, 9, 18, 30),
    endTime: DateTime(2026, 10, 9, 20),
    needsVolunteers: false,
    createdBy: 'u1',
  );
}

NewsPost _post({String? eventId}) {
  return NewsPost(
    id: 'p1',
    title: 'Fr. Mike Joins Us',
    body: 'A talk on   fatherhood\nand faith.',
    authorId: 'u1',
    authorName: 'Stan',
    category: NewsCategory.speaker,
    eventId: eventId,
  );
}

void main() {
  group('buildShareMessage', () {
    test('event includes title, when, where, description and club sign-off', () {
      // Newer ICU data puts a narrow no-break space before AM/PM.
      final message = buildShareMessage(ShareContent.fromEvent(_event())).replaceAll('\u202f', ' ');
      expect(message, contains('Speaker Night'));
      expect(message, contains('🗓 Fri, Oct 9, 2026 · 6:30 PM – 8:00 PM'));
      expect(message, contains('📍 Parish Hall'));
      expect(message, contains('Come join us.'));
      expect(message.trimRight(), endsWith('— St. Edward Association of Men'));
    });

    test('omits the location line when the event has none', () {
      final message = buildShareMessage(ShareContent.fromEvent(_event(location: '  ')));
      expect(message, isNot(contains('📍')));
      expect(message, contains('🗓'));
    });

    test('post with a linked event takes date and place from the event', () {
      final content = ShareContent.fromPost(_post(eventId: 'e1'), event: _event());
      expect(content.kicker, 'Guest Speaker');
      expect(content.dateLine, isNotNull);
      expect(content.locationLine, 'Parish Hall');
    });

    test('post without an event has no date/place lines and flattens whitespace', () {
      final message = buildShareMessage(ShareContent.fromPost(_post()));
      expect(message, isNot(contains('🗓')));
      expect(message, isNot(contains('📍')));
      expect(message, contains('A talk on fatherhood and faith.'));
    });

    test('multi-day events show both dates', () {
      final when = formatEventWhen(DateTime(2026, 10, 9, 18), DateTime(2026, 10, 10, 12));
      expect(when, contains('Oct 9'));
      expect(when, contains('Oct 10'));
    });
  });

  group('shortBlurb', () {
    test('leaves short text alone', () {
      expect(shortBlurb('Hello there'), 'Hello there');
    });

    test('cuts long text at a word boundary with an ellipsis', () {
      final result = shortBlurb('word ' * 100, max: 50);
      expect(result.endsWith('…'), isTrue);
      expect(result.length, lessThanOrEqualTo(51));
      expect(result, isNot(contains('wor…')));
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 10, 9, 12);

    test('recent, hours, yesterday, days', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3 hr ago');
      expect(relativeTime(now.subtract(const Duration(hours: 30)), now: now), 'Yesterday');
      expect(relativeTime(now.subtract(const Duration(days: 4)), now: now), '4 days ago');
    });

    test('a week or older shows the date; future clamps to just now', () {
      expect(relativeTime(DateTime(2026, 9, 1), now: now), 'Sep 1, 2026');
      expect(relativeTime(now.add(const Duration(hours: 1)), now: now), 'Just now');
    });
  });

  group('NewsCategory', () {
    test('unknown or missing name falls back to announcement', () {
      expect(NewsCategory.fromName(null), NewsCategory.announcement);
      expect(NewsCategory.fromName('bogus'), NewsCategory.announcement);
      expect(NewsCategory.fromName('speaker'), NewsCategory.speaker);
    });
  });
}
