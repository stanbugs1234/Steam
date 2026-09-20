import 'package:flutter_test/flutter_test.dart';
import 'package:steam_app/features/attendance/domain/checkin_code.dart';

void main() {
  test('a code round-trips through its QR payload', () {
    const code = CheckInCode(eventId: 'evt123', secret: 'abcdef0123456789');
    final parsed = CheckInCode.tryParse(code.payload);
    expect(parsed?.eventId, 'evt123');
    expect(parsed?.secret, 'abcdef0123456789');
  });

  test('rejects text that is not a STEAM Club code', () {
    expect(CheckInCode.tryParse('https://example.com'), isNull);
    expect(CheckInCode.tryParse(''), isNull);
  });

  test('rejects malformed payloads', () {
    expect(CheckInCode.tryParse('steamclub:checkin:'), isNull);
    expect(CheckInCode.tryParse('steamclub:checkin:evt:'), isNull);
    expect(CheckInCode.tryParse('steamclub:checkin::secret'), isNull);
    expect(CheckInCode.tryParse('steamclub:checkin:a:b:c'), isNull);
  });

  test('an old secret-less code is recognised as legacy, not valid', () {
    const legacy = 'steamclub:checkin:evt123';
    expect(CheckInCode.tryParse(legacy), isNull);
    expect(CheckInCode.isLegacy(legacy), isTrue);
    expect(CheckInCode.isLegacy('steamclub:checkin:evt123:secret'), isFalse);
    expect(CheckInCode.isLegacy('https://example.com'), isFalse);
  });
}
