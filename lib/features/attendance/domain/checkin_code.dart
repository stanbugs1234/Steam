/// What a check-in QR code says: which event, and that event's secret code
/// (which only an admin can read from Firestore).
class CheckInCode {
  const CheckInCode({required this.eventId, required this.secret});

  final String eventId;
  final String secret;

  static const _prefix = 'steamclub:checkin:';

  String get payload => '$_prefix$eventId:$secret';

  /// Null when [raw] isn't a STEAM Club code, or is from an older version of
  /// the app that had no secret (those can no longer be used to check in).
  static CheckInCode? tryParse(String raw) {
    if (!raw.startsWith(_prefix)) return null;
    final parts = raw.substring(_prefix.length).split(':');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    return CheckInCode(eventId: parts[0], secret: parts[1]);
  }

  /// True for a code that is ours but in the old, secret-less format.
  static bool isLegacy(String raw) {
    if (!raw.startsWith(_prefix)) return false;
    return !raw.substring(_prefix.length).contains(':');
  }
}
