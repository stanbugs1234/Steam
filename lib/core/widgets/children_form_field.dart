import 'package:flutter/material.dart';

import '../../models/child_info.dart';

/// Grade levels offered by the school, youngest to oldest.
const List<String> kGradeOptions = [
  'Pre-K 2',
  'Pre-K 3',
  'Pre-K 4',
  'Kindergarten',
  '1st Grade',
  '2nd Grade',
  '3rd Grade',
  '4th Grade',
  '5th Grade',
  '6th Grade',
  '7th Grade',
];

/// Editable list of children (name + grade rows) with add/remove controls.
/// Reused across the signup and profile-edit forms so a member can register
/// more than one child at the school.
class ChildrenFormField extends StatefulWidget {
  const ChildrenFormField({super.key, required this.initialChildren, required this.onChanged});

  final List<ChildInfo> initialChildren;
  final ValueChanged<List<ChildInfo>> onChanged;

  @override
  State<ChildrenFormField> createState() => _ChildrenFormFieldState();
}

class _ChildRow {
  _ChildRow({String name = '', String grade = ''})
      : nameCtrl = TextEditingController(text: name),
        grade = grade.trim().isEmpty ? null : grade.trim();

  final TextEditingController nameCtrl;
  String? grade;

  /// The dropdown's item list must contain the current value exactly once.
  /// A grade typed in before this became a dropdown (or anything that
  /// otherwise doesn't match one of the standard options) is kept as an
  /// extra selectable entry instead of silently discarded.
  List<String> get gradeOptions =>
      grade != null && !kGradeOptions.contains(grade) ? [grade!, ...kGradeOptions] : kGradeOptions;

  ChildInfo toChildInfo() => ChildInfo(name: nameCtrl.text.trim(), grade: grade ?? '');

  void dispose() {
    nameCtrl.dispose();
  }
}

class _ChildrenFormFieldState extends State<ChildrenFormField> {
  final List<_ChildRow> _rows = [];

  @override
  void initState() {
    super.initState();
    for (final child in widget.initialChildren) {
      _rows.add(_ChildRow(name: child.name, grade: child.grade));
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged(_rows.map((r) => r.toChildInfo()).toList());
  }

  void _addRow() {
    setState(() => _rows.add(_ChildRow()));
    _notify();
  }

  void _removeRow(int index) {
    final removed = _rows.removeAt(index);
    removed.dispose();
    setState(() {});
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _rows[i].nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: "Child's name"),
                  onChanged: (_) => _notify(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _rows[i].grade,
                  decoration: const InputDecoration(labelText: 'Grade'),
                  isExpanded: true,
                  items: [
                    for (final option in _rows[i].gradeOptions)
                      DropdownMenuItem(value: option, child: Text(option, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) {
                    setState(() => _rows[i].grade = value);
                    _notify();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove child',
                onPressed: () => _removeRow(i),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: Text(_rows.isEmpty ? 'Add a child' : 'Add another child'),
          ),
        ),
      ],
    );
  }
}
