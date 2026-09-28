import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/notifications/domain/fcm_sync.dart';

void main() {
  group('routeForPushData', () {
    test('an event alert opens the event', () {
      expect(routeForPushData({'type': 'event', 'eventId': 'e1'}), '/events/e1');
    });

    test('a volunteer-opening alert opens the same event (its slots live there)', () {
      expect(routeForPushData({'type': 'volunteer-opening', 'eventId': 'e1'}), '/events/e1');
    });

    test('a news alert opens the post', () {
      expect(routeForPushData({'type': 'news', 'postId': 'p1'}), '/news/p1');
    });

    test('a pending-signup alert opens the approval queue', () {
      expect(routeForPushData({'type': 'pending', 'uid': 'u1'}), '/admin/approvals');
    });

    test('an approval alert opens home', () {
      expect(routeForPushData({'type': 'approved'}), '/home');
    });

    test('an unrecognized or missing type does not navigate', () {
      expect(routeForPushData({}), isNull);
      expect(routeForPushData({'type': 'something-new'}), isNull);
    });

    test('a malformed payload (missing id) does not navigate', () {
      expect(routeForPushData({'type': 'event'}), isNull);
      expect(routeForPushData({'type': 'news'}), isNull);
    });
  });
}
