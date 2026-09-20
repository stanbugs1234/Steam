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

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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

  bool get _isOnToday => isSameDay(_focusedDay, DateTime.now());

  void _goToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final isAdmin = ref.watch(currentAppUserProvider).value?.isAdmin ?? false;
    final myEventIds = <String>{
      for (final c in ref.watch(myCommitmentsProvider).value ?? const <MyCommitment>[]) c.event.id,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          if (_tabController.index == 0 && !_isOnToday)
            TextButton(
              onPressed: _goToToday,
              child: const Text('Today'),
            ),
        ],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Calendar'), Tab(text: 'Upcoming')]),
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
          children: [
            _buildCalendarTab(events, myEventIds),
            _buildUpcomingTab(events, myEventIds),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load events right now.", error: err, onRetry: () => ref.invalidate(eventsProvider)),
      ),
    );
  }

  Widget _buildCalendarTab(List<ClubEvent> events, Set<String> myEventIds) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedDay ?? DateTime.now();
    final dayEvents = _eventsOnDay(events, selected);

    return Column(
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
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
            focusedDay: _focusedDay,
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
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders<ClubEvent>(
              markerBuilder: (context, day, dayEvents) {
                if (dayEvents.isEmpty) return null;
                // Mine first so the 3-dot cap never hides the volunteering marker.
                final mine = dayEvents.where((e) => myEventIds.contains(e.id)).length;
                final dots = dayEvents.length.clamp(0, 3);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < dots; i++)
                      _LegendDot(color: i < mine ? _volunteeringRed : colorScheme.primary, margin: 1),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Events on ${DateFormat.MMMd().format(selected)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
              _LegendDot(color: colorScheme.primary),
              const SizedBox(width: 4),
              Text('Event', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 12),
              const _LegendDot(color: _volunteeringRed),
              const SizedBox(width: 4),
              Text("You're volunteering", style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? const EmptyState(icon: Icons.event_busy_outlined, message: 'No events on this day.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: dayEvents.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _EventTile(
                    event: dayEvents[index],
                    signedUp: myEventIds.contains(dayEvents[index].id),
                  ),
                ),
        ),
      ],
    );
  }

  String _dateGroupLabel(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return 'Today';
    if (isSameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _buildUpcomingTab(List<ClubEvent> events, Set<String> myEventIds) {
    final now = DateTime.now();
    final upcoming = events.where((e) => e.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (upcoming.isEmpty) {
      return const EmptyState(icon: Icons.event_busy_outlined, message: 'No upcoming events.');
    }

    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600);

    final items = <Widget>[];
    String? lastLabel;
    for (final event in upcoming) {
      final label = _dateGroupLabel(event.startTime);
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
          child: _EventTile(event: event, signedUp: myEventIds.contains(event.id)),
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

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event, required this.signedUp});

  final ClubEvent event;
  final bool signedUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = event.needsVolunteers ? ref.watch(eventVolunteerProgressProvider(event.id)) : null;

    return Card(
      child: ListTile(
        onTap: () => context.push('/events/${event.id}'),
        leading: CircleIcon(needsVolunteers: event.needsVolunteers),
        title: Text(event.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat.MMMd().add_jm().format(event.startTime)}'
              '${event.location.isNotEmpty ? ' · ${event.location}' : ''}',
            ),
            if (signedUp) ...[
              const SizedBox(height: 6),
              _SignedUpChip(),
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
          Text(
            "You're signed up",
            style: TextStyle(fontSize: 11, color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({super.key, required this.needsVolunteers});

  final bool needsVolunteers;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: needsVolunteers
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(needsVolunteers ? Icons.volunteer_activism_outlined : Icons.event_outlined),
    );
  }
}
