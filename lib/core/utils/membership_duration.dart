/// "New member", "3 months", "2 years", "2 years 3 months" — how long ago
/// [since] was, in whole months.
String formatMembershipDuration(DateTime since, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var months = (today.year - since.year) * 12 + (today.month - since.month);
  if (today.day < since.day) months -= 1;
  if (months < 1) return 'New member';

  final years = months ~/ 12;
  final remainingMonths = months % 12;
  if (years == 0) return '$remainingMonths month${remainingMonths == 1 ? '' : 's'}';
  if (remainingMonths == 0) return '$years year${years == 1 ? '' : 's'}';
  return '$years year${years == 1 ? '' : 's'} $remainingMonths month${remainingMonths == 1 ? '' : 's'}';
}
