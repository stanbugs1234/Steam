import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../models/club_event.dart';
import '../../../models/volunteer_slot.dart';
import '../../auth/domain/auth_providers.dart';
import '../../volunteering/domain/volunteer_providers.dart';
import '../domain/event_providers.dart';
import '../../../core/utils/friendly_error.dart';

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
  final _volunteersNeededCtrl = TextEditingController(text: '1');

  DateTime _start = _roundToNextHour(DateTime.now());
  DateTime _end = _roundToNextHour(DateTime.now()).add(const Duration(hours: 1));
  bool _needsVolunteers = false;
  bool _checkInEnabled = false;

  ClubEvent? _loadedFor;
  List<VolunteerSlot> _existingSlots = const [];
  bool _slotsSynced = false;
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
    _checkInEnabled = event.checkInEnabled;
  }

  // Slots stream in live (they change as members sign up), so only seed the
  // form from them once — otherwise a signup elsewhere would blow away
  // whatever the admin is mid-typing.
  void _syncSlots(List<VolunteerSlot> slots) {
    if (_slotsSynced) return;
    _slotsSynced = true;
    _existingSlots = slots;
    if (slots.length == 1) {
      _volunteersNeededCtrl.text = slots.first.capacity.toString();
    }
  }

  String? _validateVolunteersNeeded(String? value) {
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null || count < 1) return 'Enter a number of at least 1';
    if (_existingSlots.length == 1 && count < _existingSlots.first.signedUpUserIds.length) {
      return '${_existingSlots.first.signedUpUserIds.length} people are already signed up';
    }
    return null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _volunteersNeededCtrl.dispose();
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
      final volunteerRepo = ref.read(volunteerRepositoryProvider);
      // A single inline number only makes sense when there's zero or one
      // existing slot — an event with multiple named shifts is managed
      // through the dedicated slots screen instead (see the hidden field
      // in _buildForm).
      final writeSingleSlot = _needsVolunteers && _existingSlots.length <= 1;
      final volunteersNeeded = writeSingleSlot ? int.parse(_volunteersNeededCtrl.text.trim()) : null;

      if (_isEditing) {
        final eventId = widget.eventId!;
        await ref.read(eventRepositoryProvider).updateEvent(eventId, {
          'title': _titleCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'startTime': Timestamp.fromDate(_start),
          'endTime': Timestamp.fromDate(_end),
          'needsVolunteers': _needsVolunteers,
          'checkInEnabled': _checkInEnabled,
        });
        if (writeSingleSlot) {
          if (_existingSlots.isEmpty) {
            await volunteerRepo.createSlot(
              eventId,
              VolunteerSlot(
                id: volunteerRepo.newSlotId(eventId),
                label: 'Volunteers',
                capacity: volunteersNeeded!,
                signedUpUserIds: const [],
              ),
            );
          } else if (volunteersNeeded != _existingSlots.first.capacity) {
            await volunteerRepo.updateSlotDetails(
              eventId,
              _existingSlots.first.id,
              label: _existingSlots.first.label,
              capacity: volunteersNeeded!,
            );
          }
        }
      } else {
        final me = ref.read(currentAppUserProvider).value;
        final repo = ref.read(eventRepositoryProvider);
        final eventId = repo.newEventId();
        await repo.createEvent(ClubEvent(
          id: eventId,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          startTime: _start,
          endTime: _end,
          needsVolunteers: _needsVolunteers,
          createdBy: me?.uid ?? '',
          checkInEnabled: _checkInEnabled,
        ));
        if (writeSingleSlot) {
          await volunteerRepo.createSlot(
            eventId,
            VolunteerSlot(
              id: volunteerRepo.newSlotId(eventId),
              label: 'Volunteers',
              capacity: volunteersNeeded!,
              signedUpUserIds: const [],
            ),
          );
        }
      }
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = friendlyError(e, fallback: "Couldn't save the event. Please try again."));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final eventsAsync = ref.watch(eventsProvider);
      final slotsAsync = ref.watch(eventSlotsProvider(widget.eventId!));
      return eventsAsync.when(
        data: (events) {
          final event = events.firstWhereOrNull((e) => e.id == widget.eventId);
          if (event == null) {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('Event not found.')));
          }
          _syncFromExisting(event);
          return slotsAsync.when(
            data: (slots) {
              _syncSlots(slots);
              return _buildForm(context);
            },
            loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
            error: (err, _) =>
                Scaffold(appBar: AppBar(), body: ErrorState(message: 'Something went wrong.', error: err, onRetry: () => ref.invalidate(eventsProvider))),
          );
        },
        loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(appBar: AppBar(), body: ErrorState(message: 'Something went wrong.', error: err, onRetry: () => ref.invalidate(eventsProvider))),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionCard(
                    title: 'Details',
                    icon: Icons.info_outline,
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextFormField(
                          controller: _locationCtrl,
                          decoration: const InputDecoration(labelText: 'Location'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: TextFormField(
                          controller: _descriptionCtrl,
                          decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                          minLines: 4,
                          maxLines: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Schedule',
                    icon: Icons.schedule_outlined,
                    padding: EdgeInsets.zero,
                    children: [
                      _buildDateTimeRow(label: 'Starts', value: _start, isStart: true),
                      const Divider(height: 1),
                      _buildDateTimeRow(label: 'Ends', value: _end, isStart: false),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Options',
                    icon: Icons.tune,
                    padding: EdgeInsets.zero,
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.volunteer_activism_outlined),
                        title: const Text('Needs volunteers'),
                        value: _needsVolunteers,
                        onChanged: (v) => setState(() => _needsVolunteers = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.qr_code_scanner),
                        title: const Text('Enable check-in for this meeting'),
                        subtitle: const Text('Members scan a QR code to check in and earn a point.'),
                        value: _checkInEnabled,
                        onChanged: (v) => setState(() => _checkInEnabled = v),
                      ),
                      if (_needsVolunteers) ...[
                        const Divider(height: 1),
                        if (_existingSlots.length > 1)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Text(
                              'This event already has multiple volunteer slots. '
                              'Manage their headcounts individually from the event page.',
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: TextFormField(
                              controller: _volunteersNeededCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Volunteers needed'),
                              validator: _validateVolunteersNeeded,
                            ),
                          ),
                      ],
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: isStart),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(DateFormat.yMMMd().format(value)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: isStart),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(DateFormat.jm().format(value)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
