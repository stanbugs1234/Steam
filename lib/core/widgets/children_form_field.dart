import 'package:flutter/material.dart';

import '../../models/child_info.dart';

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

class _ChildRowControllers {
  _ChildRowControllers({String name = '', String grade = ''})
      : nameCtrl = TextEditingController(text: name),
        gradeCtrl = TextEditingController(text: grade);

  final TextEditingController nameCtrl;
  final TextEditingController gradeCtrl;

  ChildInfo toChildInfo() => ChildInfo(name: nameCtrl.text.trim(), grade: gradeCtrl.text.trim());

  void dispose() {
    nameCtrl.dispose();
    gradeCtrl.dispose();
  }
}

class _ChildrenFormFieldState extends State<ChildrenFormField> {
  final List<_ChildRowControllers> _rows = [];

  @override
  void initState() {
    super.initState();
    for (final child in widget.initialChildren) {
      _rows.add(_ChildRowControllers(name: child.name, grade: child.grade));
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
    setState(() => _rows.add(_ChildRowControllers()));
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
                child: TextFormField(
                  controller: _rows[i].gradeCtrl,
                  decoration: const InputDecoration(labelText: 'Grade'),
                  onChanged: (_) => _notify(),
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
