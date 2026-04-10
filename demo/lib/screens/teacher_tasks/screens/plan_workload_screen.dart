import 'package:flutter/material.dart';

import '../services/teacher_task_service.dart';

class PlanWorkloadScreen extends StatefulWidget {
  const PlanWorkloadScreen({super.key});

  @override
  State<PlanWorkloadScreen> createState() => _PlanWorkloadScreenState();
}

class _PlanWorkloadScreenState extends State<PlanWorkloadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TeacherTaskService();

  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  bool _planWeekly = false;

  String _title = '';
  String _taskType = 'lesson_plan';
  String _priority = 'medium';
  int _estimatedMinutes = 30;

  final List<String> _priorities = ['low', 'medium', 'high'];

  final List<String> _taskTypes = [
    'lesson_plan',
    'quiz_review',
    'pbl_review',
    'student_support',
    'admin',
    'custom',
  ];

  final Map<int, bool> _weekDays = {
    1: true,
    2: true,
    3: true,
    4: true,
    5: true,
    6: false,
    7: false,
  };

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<String> _generateWeekDates(DateTime start, Map<int, bool> selectedDays) {
    final dates = <String>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      if (selectedDays[d.weekday] == true) {
        dates.add(_formatDate(d));
      }
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F8FF),
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 72,
        titleSpacing: 16,
        title: const Text(
          'Plan your workload',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _heroBanner(),
              const SizedBox(height: 20),
              _sectionCard(
                title: 'Schedule',
                subtitle: 'Pick when this effort happens',
                children: [
                  _pickerTile(
                    icon: Icons.calendar_month,
                    title: 'Planned day',
                    value: _formatDate(_selectedDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 7),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 45)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.cyanAccent,
                                onPrimary: Colors.black87,
                                surface: Color(0xFF1E1E1E),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _toggleCard(),
                  if (_planWeekly) ...[
                    const SizedBox(height: 12),
                    _weekdayChips(),
                  ],
                  const SizedBox(height: 12),
                  _pickerTile(
                    icon: Icons.flag,
                    title: 'Due date',
                    value: _dueDate == null
                        ? 'No due date'
                        : _formatDate(_dueDate!),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? _selectedDate,
                        firstDate: _selectedDate,
                        lastDate: _selectedDate.add(const Duration(days: 60)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.cyanAccent,
                                onPrimary: Colors.black87,
                                surface: Color(0xFF1E1E1E),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _dueDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _priorityChips(),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Task details',
                subtitle: 'Give this block a name and type',
                children: [
                  TextFormField(
                    decoration: _fieldDecoration('Task title'),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                    onSaved: (v) => _title = v!,
                  ),
                  const SizedBox(height: 12),
                  _taskTypeChips(),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: _fieldDecoration('Estimated minutes'),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    initialValue: '$_estimatedMinutes',
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a positive value';
                      return null;
                    },
                    onSaved: (v) => _estimatedMinutes = int.parse(v!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Review',
                subtitle: 'Double-check before scheduling',
                children: [
                  _reviewRow(
                    'Plan mode',
                    _planWeekly ? 'Weekly rollout' : 'Single day',
                  ),
                  _reviewRow(
                    'Due date',
                    _dueDate == null ? 'Not set' : _formatDate(_dueDate!),
                  ),
                  _reviewRow('Effort', '$_estimatedMinutes minutes'),
                  _reviewRow(
                    'Priority',
                    '${_priority[0].toUpperCase()}${_priority.substring(1)}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _saveTask,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Add to plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroBanner() {
    final modeLabel = _planWeekly ? 'Weekly rollout' : 'Single focus day';
    final dueLabel = _dueDate == null
        ? 'No due date'
        : 'Due ${_formatDate(_dueDate!)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shape your focus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Block time for deep work or support tasks. We’ll keep it synced.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                backgroundColor: Colors.cyanAccent,
                label: Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              Chip(
                backgroundColor: Colors.cyanAccent,
                label: Text(
                  modeLabel,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              Chip(
                backgroundColor: Colors.cyanAccent,
                label: Text(
                  dueLabel,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFF3A3A3A)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyanAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(value, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  Widget _toggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF3A3A3A)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Plan for entire week',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Duplicate across selected days',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
          const Spacer(),
          Switch.adaptive(
            value: _planWeekly,
            activeColor: Colors.cyanAccent,
            onChanged: (value) => setState(() => _planWeekly = value),
          ),
        ],
      ),
    );
  }

  Widget _weekdayChips() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _weekDays.keys.map((day) {
        final selected = _weekDays[day] ?? false;
        return ChoiceChip(
          label: Text(labels[day - 1]),
          selected: selected,
          selectedColor: Colors.cyanAccent,
          backgroundColor: Color(0xFF1E1E1E),
          side: BorderSide(
            color: selected ? Colors.cyanAccent : Color(0xFF3A3A3A),
          ),
          labelStyle: TextStyle(
            color: selected ? Colors.black87 : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (value) {
            setState(() => _weekDays[day] = value);
          },
        );
      }).toList(),
    );
  }

  Widget _taskTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _taskTypes.map((type) {
        final selected = _taskType == type;
        return ChoiceChip(
          label: Text(type.replaceAll('_', ' ')),
          selected: selected,
          selectedColor: Colors.cyanAccent,
          backgroundColor: Color(0xFF1E1E1E),
          side: BorderSide(
            color: selected ? Colors.cyanAccent : Color(0xFF3A3A3A),
          ),
          labelStyle: TextStyle(
            color: selected ? Colors.black87 : Colors.white70,
          ),
          onSelected: (_) {
            setState(() => _taskType = type);
          },
        );
      }).toList(),
    );
  }

  Widget _priorityChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _priorities.map((priority) {
            final selected = _priority == priority;
            return ChoiceChip(
              label: Text(
                '${priority[0].toUpperCase()}${priority.substring(1)}',
              ),
              selected: selected,
              selectedColor: Colors.cyanAccent,
              backgroundColor: const Color(0xFF1E1E1E),
              side: BorderSide(
                color: selected ? Colors.cyanAccent : const Color(0xFF3A3A3A),
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.black87 : Colors.white70,
              ),
              onSelected: (_) {
                setState(() => _priority = priority);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _reviewRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white60)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_planWeekly) {
      final dates = _generateWeekDates(_selectedDate, _weekDays);
      await _service.createWeeklyPlannedTasks(
        plannedDates: dates,
        taskType: _taskType,
        title: _title,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        dueDate: _dueDate,
      );
    } else {
      await _service.createManualPlannedTask(
        plannedForDate: _formatDate(_selectedDate),
        taskType: _taskType,
        title: _title,
        estimatedMinutes: _estimatedMinutes,
        priority: _priority,
        dueDate: _dueDate,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}
