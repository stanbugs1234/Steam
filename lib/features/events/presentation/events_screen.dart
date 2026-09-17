import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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

  List<ClubEvent> _eventsOnDay(List<ClubEvent> events, DateTime day) {
    return events.where((e) => isSameDay(e.startTime, day)).toList();
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
            _buildCalendarTab(events),
            _buildUpcomingTab(events),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(message: "Couldn't load events right now.", error: err),
      ),
    );
  }

  Widget _buildCalendarTab(List<ClubEvent> events) {
    final selected = _selectedDay ?? DateTime.now();
    final dayEvents = _eventsOnDay(events, selected);

    return Column(
      children: [
        TableCalendar<ClubEvent>(
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
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
            todayDecoration:
                BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: dayEvents.isEmpty
              ? const EmptyState(icon: Icons.event_busy_outlined, message: 'No events on this day.')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: dayEvents.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _EventTile(event: dayEvents[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTab(List<ClubEvent> events) {
    final now = DateTime.now();
    final upcoming = events.where((e) => e.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (upcoming.isEmpty) {
      return const EmptyState(icon: Icons.event_busy_outlined, message: 'No upcoming events.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: upcoming.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _EventTile(event: upcoming[index]),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = event.needsVolunteers ? ref.watch(eventVolunteerProgressProvider(event.id)) : null;
    final colorScheme = Theme.of(context).colorScheme;

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
            if (progress != null)
              Text(
                progress.filled >= progress.capacity
                    ? 'Volunteers: Full'
                    : '${progress.filled} of ${progress.capacity} volunteer spots filled',
                style: TextStyle(
                  color: progress.filled >= progress.capacity ? colorScheme.error : colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
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
