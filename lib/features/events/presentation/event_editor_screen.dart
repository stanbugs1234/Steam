import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/club_event.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/event_providers.dart';

/// Create/edit form for an event. Pass [eventId] to edit an existing event,
/// or leave it null to create a new one.
class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  DateTime _start = _roundToNextHour(DateTime.now());
  DateTime _end = _roundToNextHour(DateTime.now()).add(const Duration(hours: 1));
  bool _needsVolunteers = false;

  ClubEvent? _loadedFor;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.eventId != null;

  static DateTime _roundToNextHour(DateTime dt) {
    final rounded = DateTime(dt.year, dt.month, dt.day, dt.hour + 1);
    return rounded;
  }

  void _syncFromExisting(ClubEvent event) {
    if (_loadedFor?.id == event.id) return;
    _loadedFor = event;
    _titleCtrl.text = event.title;
    _descriptionCtrl.text = event.description;
    _locationCtrl.text = event.location;
    _start = event.startTime;
    _end = event.endTime;
    _needsVolunteers = event.needsVolunteers;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _applyChange(bool isStart, DateTime combined) {
    setState(() {
      if (isStart) {
        _start = combined;
        if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = combined;
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    _applyChange(isStart, DateTime(date.year, date.month, date.day, initial.hour, initial.minute));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    _applyChange(isStart, DateTime(initial.year, initial.month, initial.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end.isBefore(_start)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await ref.read(eventRepositoryProvider).updateEvent(widget.eventId!, {
          'title': _titleCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'startTime': Timestamp.fromDate(_start),
          'endTime': Timestamp.fromDate(_end),
          'needsVolunteers': _needsVolunteers,
        });
      } else {
        final me = ref.read(currentAppUserProvider).value;
        final repo = ref.read(eventRepositoryProvider);
        await repo.createEvent(ClubEvent(
          id: repo.newEventId(),
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          startTime: _start,
          endTime: _end,
          needsVolunteers: _needsVolunteers,
          createdBy: me?.uid ?? '',
        ));
      }
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Could not save event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final eventsAsync = ref.watch(eventsProvider);
      return eventsAsync.when(
        data: (events) {
          final event = events.firstWhereOrNull((e) => e.id == widget.eventId);
          if (event == null) {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('Event not found.')));
          }
          _syncFromExisting(event);
          return _buildForm(context);
        },
        loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $err'))),
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Event' : 'New Event')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                    minLines: 4,
                    maxLines: 10,
                  ),
                  const SizedBox(height: 16),
                  _buildDateTimeRow(label: 'Starts', value: _start, isStart: true),
                  const SizedBox(height: 8),
                  _buildDateTimeRow(label: 'Ends', value: _end, isStart: false),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Needs volunteers'),
                    value: _needsVolunteers,
                    onChanged: (v) => setState(() => _needsVolunteers = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Save Changes' : 'Create Event'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeRow({required String label, required DateTime value, required bool isStart}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          OutlinedButton(
            onPressed: () => _pickDate(isStart: isStart),
            child: Text(DateFormat.yMMMd().format(value)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _pickTime(isStart: isStart),
            child: Text(DateFormat.jm().format(value)),
          ),
        ],
      ),
    );
  }
}
