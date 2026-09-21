import 'package:intl/intl.dart';

import '../../../models/club_event.dart';

enum DayTiming { past, today, future }

enum EventTiming { past, live, upcoming }

/// Calendar days are compared by year/month/day only. TableCalendar hands out
/// UTC-normalized days while the clock is local, so `==` on the raw values
/// would never match.
DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Whether [day] is before, on, or after the calendar date of [now].
DayTiming dayTiming(DateTime day, DateTime now) {
  final diff = _dateOnly(day).difference(_dateOnly(now)).inDays;
  if (diff < 0) return DayTiming.past;
  if (diff > 0) return DayTiming.future;
  return DayTiming.today;
}

/// An event is past once it has ended, live between its start and end, and
/// upcoming before that.
EventTiming eventTiming(ClubEvent event, DateTime now) {
  if (!event.endTime.isAfter(now)) return EventTiming.past;
  if (!event.startTime.isAfter(now)) return EventTiming.live;
  return EventTiming.upcoming;
}

/// "Today", "Yesterday", "Tomorrow", "3 days ago" or "in 5 days".
String dayRelativeLabel(DateTime day, DateTime now) {
  final diff = _dateOnly(day).difference(_dateOnly(now)).inDays;
  return switch (diff) {
    0 => 'Today',
    -1 => 'Yesterday',
    1 => 'Tomorrow',
    < 0 => '${-diff} days ago',
    _ => 'in $diff days',
  };
}

/// The heading above the selected day's events, anchored to today:
/// "Today · Sun, Sep 20" or "Fri, Sep 18 · 2 days ago".
String dayHeading(DateTime day, DateTime now) {
  final date = DateFormat('EEE, MMM d').format(day);
  final relative = dayRelativeLabel(day, now);
  final isNear = _dateOnly(day).difference(_dateOnly(now)).inDays.abs() <= 1;
  return isNear ? '$relative · $date' : '$date · $relative';
}
