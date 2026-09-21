import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/widgets/capacity_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../models/club_event.dart';
import '../../auth/domain/auth_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../domain/event_providers.dart';
import '../domain/event_timing.dart';

/// Text and dots for things that are over: still readable, clearly quieter
/// than what's coming up.
Color mutedTextColor(ColorScheme colors) => colors.onSurface.withValues(alpha: 0.55);

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key, this.clock = DateTime.now});

  /// The current time. Injectable so tests can pin "today".
  final DateTime Function() clock;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  /// The date the calendar last showed as "today", to notice when the app
  /// comes back to the foreground on a later day.
  late DateTime _lastSeenDay;

  // TableCalendar's eventLoader is called once per visible day cell (~42
  // times per month view) plus again for the selected day's list, so a full
  // linear scan of `events` per call gets expensive as event history grows.
  // Cache the day->events grouping and only rebuild it when the events list
  // itself actually changes.
  List<ClubEvent>? _groupedForEvents;
  Map<DateTime, List<ClubEvent>> _eventsByDay = {};

  Map<DateTime, List<ClubEvent>> _groupByDay(List<ClubEvent> events) {
    if (!identical(_groupedForEvents, events)) {
      final byDay = <DateTime, List<ClubEvent>>{};
      for (final event in events) {
        final day = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
        (byDay[day] ??= []).add(event);
      }
      _eventsByDay = byDay;
      _groupedForEvents = events;
    }
    return _eventsByDay;
  }

  List<ClubEvent> _eventsOnDay(List<ClubEvent> events, DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _groupByDay(events)[key] ?? const [];
  }

  bool _isOnToday(DateTime now) =>
      isSameDay(_selectedDay, now) && _focusedDay.year == now.year && _focusedDay.month == now.month;

  void _goToToday() {
    final now = widget.clock();
    setState(() {
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  @override
  void initState() {
    super.initState();
    final now = widget.clock();
    _focusedDay = now;
    _selectedDay = now;
    _lastSeenDay = now;
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  /// If the app was left open overnight, move today's highlight to the new
  /// date, and bring the selection along only if it was still on the old today
  /// (so a day the member deliberately picked isn't yanked away).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = widget.clock();
    if (isSameDay(now, _lastSeenDay)) return;
    setState(() {
      if (isSameDay(_selectedDay, _lastSeenDay)) {
        _selectedDay = now;
        _focusedDay = now;
      }
      _lastSeenDay = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;
    final myEventIds = <String>{
      for (final c in ref.watch(myCommitmentsProvider).value ?? const <MyCommitment>[]) c.event.id,
    };
    final now = widget.clock();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          if (_tabController.index == 0 && !_isOnToday(now))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _goToToday,
                icon: const Icon(Icons.today, size: 18),
                label: const Text('Today'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Upcoming'),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              heroTag: 'events_fab',
              onPressed: () => context.push('/events/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: eventsAsync.when(
        data: (events) => TabBarView(
          controller: _tabController,
          children: [_buildCalendarTab(events, myEventIds, now), _buildUpcomingTab(events, myEventIds, now)],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: "Couldn't load events right now.",
          error: err,
          onRetry: () => ref.invalidate(eventsProvider),
        ),
      ),
    );
  }

  /// One day cell, with a spoken description ("Sunday, September 20, today,
  /// 2 events, you're volunteering") since the look alone carries the state.
  Widget _dayCell(
    List<ClubEvent> events,
    Set<String> myEventIds,
    DateTime now,
    DateTime day, {
    bool selected = false,
    bool outside = false,
  }) {
    final dayEvents = _eventsOnDay(events, day);
    final timing = dayTiming(day, now);
    final label = StringBuffer(DateFormat('EEEE, MMMM d').format(day));
    if (timing == DayTiming.today) label.write(', today');
    if (timing == DayTiming.past) label.write(', past');
    if (dayEvents.isNotEmpty) label.write(', ${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}');
    if (dayEvents.any((e) => myEventIds.contains(e.id))) label.write(", you're volunteering");

    return _DayCell(day: day, timing: timing, selected: selected, outside: outside, semanticsLabel: label.toString());
  }

  Widget _buildCalendarTab(List<ClubEvent> events, Set<String> myEventIds, DateTime now) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = _selectedDay ?? now;
    final dayEvents = _eventsOnDay(events, selected);
    final pastDots = mutedTextColor(colorScheme);

    // A scroll view rather than a fixed column: on a small phone (or with large
    // text) the calendar, legend and the day's events can't all fit at once.
    return ListView(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: TableCalendar<ClubEvent>(
            firstDay: now.subtract(const Duration(days: 365)),
            lastDay: now.add(const Duration(days: 365 * 2)),
            focusedDay: _focusedDay,
            currentDay: now,
            rowHeight: 48,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _eventsOnDay(events, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 17),
              leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.primary),
              rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.primary),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              weekendStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
            calendarBuilders: CalendarBuilders<ClubEvent>(
              defaultBuilder: (context, day, focusedDay) => _dayCell(events, myEventIds, now, day),
              outsideBuilder: (context, day, focusedDay) => _dayCell(events, myEventIds, now, day, outside: true),
              todayBuilder: (context, day, focusedDay) => _dayCell(events, myEventIds, now, day),
              selectedBuilder: (context, day, focusedDay) => _dayCell(events, myEventIds, now, day, selected: true),
              markerBuilder: (context, day, dayEvents) {
                if (dayEvents.isEmpty) return null;
                // Mine first so the 3-dot cap never hides the volunteering marker.
                final mine = dayEvents.where((e) => myEventIds.contains(e.id)).length;
                final dots = dayEvents.length.clamp(0, 3);
                final isPast = dayTiming(day, now) == DayTiming.past;
                final mineColor = isPast ? _volunteeringRed.withValues(alpha: 0.5) : _volunteeringRed;
                final otherColor = isPast ? pastDots : colorScheme.primary;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < dots; i++) _LegendDot(color: i < mine ? mineColor : otherColor, margin: 1),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayHeading(selected, now),
                style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _LegendItem(color: colorScheme.primary, label: 'Event'),
                  const _LegendItem(color: _volunteeringRed, label: "You're volunteering"),
                  _LegendItem(color: pastDots, label: 'Past'),
                ],
              ),
            ],
          ),
        ),
        if (dayEvents.isEmpty)
          const EmptyState(icon: Icons.event_busy_outlined, message: 'No events on this day.')
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                for (final event in dayEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EventTile(event: event, signedUp: myEventIds.contains(event.id), now: now),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _dateGroupLabel(DateTime date, DateTime now) {
    if (isSameDay(date, now)) return 'Today';
    if (isSameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _buildUpcomingTab(List<ClubEvent> events, Set<String> myEventIds, DateTime now) {
    final upcoming = events.where((e) => e.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (upcoming.isEmpty) {
      return const EmptyState(icon: Icons.event_busy_outlined, message: 'No upcoming events.');
    }

    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600);

    final items = <Widget>[];
    String? lastLabel;
    for (final event in upcoming) {
      final label = _dateGroupLabel(event.startTime, now);
      if (label != lastLabel) {
        items.add(
          Padding(
            padding: EdgeInsets.fromLTRB(8, items.isEmpty ? 0 : 16, 8, 8),
            child: Text(label, style: labelStyle),
          ),
        );
        lastLabel = label;
      }
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _EventTile(event: event, signedUp: myEventIds.contains(event.id), now: now),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

/// A day number in the month grid. Today is a ring in the brand accent (kept
/// even when today is also the selected day, which gets a filled circle inside
/// the ring); past days are muted; days outside the month are fainter still.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.timing,
    required this.selected,
    required this.outside,
    required this.semanticsLabel,
  });

  static const double _size = 36;

  final DateTime day;
  final DayTiming timing;
  final bool selected;
  final bool outside;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isToday = timing == DayTiming.today;

    final Color textColor;
    var weight = FontWeight.w400;
    if (selected) {
      textColor = colors.onPrimary;
      weight = FontWeight.w700;
    } else if (isToday) {
      textColor = colors.primary;
      weight = FontWeight.w800;
    } else if (outside) {
      textColor = colors.onSurface.withValues(alpha: 0.3);
    } else if (timing == DayTiming.past) {
      textColor = mutedTextColor(colors);
    } else {
      textColor = colors.onSurface;
    }

    // Big Dynamic Type sizes would overflow a fixed-size day circle.
    final number = Text(
      '${day.day}',
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      style: TextStyle(fontSize: 16, color: textColor, fontWeight: weight),
    );
    final filled = BoxDecoration(color: colors.primary, shape: BoxShape.circle);
    final ring = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: colors.primary, width: 2),
    );

    final Widget circle;
    if (selected && isToday) {
      circle = Container(
        key: const ValueKey('today-ring'),
        width: _size,
        height: _size,
        padding: const EdgeInsets.all(3),
        decoration: ring,
        child: DecoratedBox(
          decoration: filled,
          child: Center(child: number),
        ),
      );
    } else if (selected) {
      circle = Container(width: _size, height: _size, alignment: Alignment.center, decoration: filled, child: number);
    } else if (isToday) {
      circle = Container(
        key: const ValueKey('today-ring'),
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: ring,
        child: number,
      );
    } else {
      circle = SizedBox(
        width: _size,
        height: _size,
        child: Center(child: number),
      );
    }

    return Semantics(
      key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
      label: semanticsLabel,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: Center(child: circle),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, this.margin = 0});

  final Color color;
  final double margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: EdgeInsets.symmetric(horizontal: margin),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event, required this.signedUp, required this.now});

  final ClubEvent event;
  final bool signedUp;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final timing = eventTiming(event, now);
    final isPast = timing == EventTiming.past;
    // A finished event has nothing left to fill, so don't show its capacity bar.
    final progress = event.needsVolunteers && !isPast ? ref.watch(eventVolunteerProgressProvider(event.id)) : null;
    final muted = mutedTextColor(colors);

    return Card(
      child: ListTile(
        onTap: () => context.push('/events/${event.id}'),
        leading: CircleIcon(needsVolunteers: event.needsVolunteers, muted: isPast),
        title: Text(event.title, style: isPast ? TextStyle(color: muted) : null),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat.MMMd().add_jm().format(event.startTime)}'
              '${event.location.isNotEmpty ? ' · ${event.location}' : ''}',
              style: isPast ? TextStyle(color: muted) : null,
            ),
            if (isPast || timing == EventTiming.live || signedUp) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (isPast) const _StatusChip(label: 'Past', icon: Icons.history, tone: _ChipTone.muted),
                  if (timing == EventTiming.live)
                    const _StatusChip(label: 'Happening now', icon: Icons.circle, tone: _ChipTone.accent),
                  if (signedUp && isPast)
                    const _StatusChip(label: 'You volunteered', icon: Icons.check_circle_outline, tone: _ChipTone.muted)
                  else if (signedUp)
                    const _SignedUpChip(),
                ],
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 6),
              CapacityBar(filled: progress.filled, capacity: progress.capacity),
            ],
          ],
        ),
      ),
    );
  }
}

const _volunteeringRed = Color(0xFFD32F2F);

class _SignedUpChip extends StatelessWidget {
  const _SignedUpChip();

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFCDD2);
    const foreground = Color(0xFFB71C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: foreground),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              "You're signed up",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChipTone { muted, accent }

/// A small pill for an event's state: "Past" / "You volunteered" (muted) or
/// "Happening now" (brand accent).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon, required this.tone});

  final String label;
  final IconData icon;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAccent = tone == _ChipTone.accent;
    final background = isAccent ? colors.primaryContainer : colors.surfaceContainerHighest;
    final foreground = isAccent ? colors.onPrimaryContainer : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isAccent ? 8 : 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({super.key, required this.needsVolunteers, this.muted = false});

  final bool needsVolunteers;

  /// Greyed out, for events that are over.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: muted
          ? colors.surfaceContainerHighest
          : needsVolunteers
          ? colors.tertiaryContainer
          : colors.secondaryContainer,
      foregroundColor: muted ? mutedTextColor(colors) : null,
      child: Icon(needsVolunteers ? Icons.volunteer_activism_outlined : Icons.event_outlined),
    );
  }
}
