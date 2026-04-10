import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/teacher_task.dart';
import '../services/notification_service.dart';
import '../services/teacher_task_query_service.dart';
import '../services/teacher_task_service.dart';
import '../services/workload_calculator.dart';
import 'plan_workload_screen.dart';
import 'productivity_screen.dart';
import 'weekly_insights_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:demo/widgets/ui/cc_decorated_background.dart';

enum _TimeFilter { today, tomorrow, next7 }

class TeacherTaskScreen extends StatefulWidget {
  const TeacherTaskScreen({super.key});

  @override
  State<TeacherTaskScreen> createState() => _TeacherTaskScreenState();
}

class _TeacherTaskScreenState extends State<TeacherTaskScreen>
    with SingleTickerProviderStateMixin {
  final _queryService = TeacherTaskQueryService();
  final _notifService = NotificationService();
  final _taskService = TeacherTaskService();
  late final String _teacherId;
  _TimeFilter _filter = _TimeFilter.today;
  final ScrollController _listController = ScrollController();
  final BorderRadius _cardRadius = BorderRadius.circular(20);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Teacher not logged in');
    }
    _teacherId = user.uid;
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4F8FF),
          elevation: 0, // removes shadow
          scrolledUnderElevation:
              0, // 🔑 removes white line on scroll (Flutter 3.7+)
          surfaceTintColor: Colors.transparent,
          // elevation: 0,
          title: const Text(
            'Planned Work',
            style: TextStyle(color: Color(0xFF0D1B3D)),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF2E6BFF),
              ),
              tooltip: 'Plan workload',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanWorkloadScreen()),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF2E6BFF),
              ),
              tooltip: 'Send nudges',
              onSelected: (value) async {
                if (value == 'tomorrow') {
                  await _notifService.sendTomorrowNudge(teacherId: _teacherId);
                } else if (value == 'next7') {
                  await _notifService.sendNext7DaysNudge(teacherId: _teacherId);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'tomorrow',
                  child: Text('Nudge: tomorrow'),
                ),
                PopupMenuItem(
                  value: 'next7',
                  child: Text('Nudge: next 7 days'),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF2E6BFF),
            labelColor: Color(0xFF0D1B3D),
            unselectedLabelColor: Color(0xFF5C6B8C),
            tabs: [
              Tab(
                icon: Icon(
                  Icons.format_list_bulleted,
                  color: Color(0xFF2E6BFF),
                ),
                text: 'List',
              ),
              Tab(
                icon: Icon(Icons.calendar_month, color: Color(0xFF2E6BFF)),
                text: 'Calendar',
              ),
            ],
          ),
        ),
        body: CcDecoratedBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Focus window',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1B3D),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bolt, color: Color(0xFF2E6BFF)),
                      tooltip: 'Jump to top',
                      onPressed: () => _listController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Today', _TimeFilter.today, Icons.sunny),
                      const SizedBox(width: 10),
                      _filterChip(
                        'Tomorrow',
                        _TimeFilter.tomorrow,
                        Icons.upcoming,
                      ),
                      const SizedBox(width: 10),
                      _filterChip(
                        'Next 7 days',
                        _TimeFilter.next7,
                        Icons.calendar_view_week,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [_buildListView(), _buildCalendarView()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, _TimeFilter value, IconData icon) {
    final selected = _filter == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF3FF) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? const Color(0xFF2E6BFF)
              : const Color(0x1A2E6BFF),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF2E6BFF).withOpacity(0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _filter = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2E6BFF)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0D1B3D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<List<TeacherTask>> _streamForFilter() {
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    switch (_filter) {
      case _TimeFilter.today:
        return _queryService.getTodaysPlannedTasks(teacherId: _teacherId);
      case _TimeFilter.tomorrow:
        final t = now.add(const Duration(days: 1));
        return _queryService.getPlannedTasksForDate(
          teacherId: _teacherId,
          plannedForDate: fmt(t),
        );
      case _TimeFilter.next7:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 7));
        return _queryService.getPlannedTasksInRange(
          teacherId: _teacherId,
          startDate: fmt(start),
          endDate: fmt(end),
        );
    }
  }

  Widget _buildListView() {
    return StreamBuilder<List<TeacherTask>>(
      stream: _streamForFilter(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return const Center(
            child: Text(
              'No tasks for selected range',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final pending = tasks.where((t) => t.status != 'completed').toList();
        final completed = tasks.where((t) => t.status == 'completed').toList();
        final workload = calculateDailyWorkload(tasks, DateTime.now());

        final int totalTasks = tasks.length;
        final int completedTasks = completed.length;
        final double completionRate = totalTasks == 0
            ? 0
            : completedTasks / totalTasks;
        final double onTimeRate = _calculateOnTimeRate(tasks);
        final double efficiency = _calculateEfficiency(tasks);

        return ListView(
          controller: _listController,
          children: [
            const SizedBox(height: 8),
            _workloadAndMetrics(
              tasks,
              workload,
              completionRate,
              onTimeRate,
              efficiency,
            ),
            if (_filter == _TimeFilter.next7) _next7BarChart(tasks),
            _section('Pending', pending),
            _section('Completed', completed),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildCalendarView() {
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final start = now.subtract(const Duration(days: 15));
    final end = now.add(const Duration(days: 15));

    return StreamBuilder<List<TeacherTask>>(
      stream: _queryService.getPlannedTasksInRange(
        teacherId: _teacherId,
        startDate: fmt(start),
        endDate: fmt(end),
      ),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final events = <DateTime, List<TeacherTask>>{};
        for (final t in tasks) {
          if (t.plannedForDate == null) continue;
          final d = DateTime.parse(t.plannedForDate!);
          final key = DateTime(d.year, d.month, d.day);
          events.putIfAbsent(key, () => []);
          events[key]!.add(t);
        }

        DateTime focusedDay = DateTime.now();
        DateTime selectedDay = focusedDay;

        return StatefulBuilder(
          builder: (context, setCalState) {
            final selectedKey = DateTime(
              selectedDay.year,
              selectedDay.month,
              selectedDay.day,
            );
            final dayTasks = events[selectedKey] ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  color: Color(0xFF1E2D4F),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar<TeacherTask>(
                      firstDay: start,
                      lastDay: end,
                      focusedDay: focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, selectedDay),
                      eventLoader: (day) =>
                          events[DateTime(day.year, day.month, day.day)] ?? [],
                      calendarStyle: CalendarStyle(
                        todayDecoration: const BoxDecoration(
                          color: Colors.cyanAccent,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: const TextStyle(color: Colors.white),
                        weekendTextStyle: const TextStyle(
                          color: Colors.white70,
                        ),
                        outsideTextStyle: TextStyle(color: Colors.white24),
                      ),
                      headerStyle: const HeaderStyle(
                        titleTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                        formatButtonTextStyle: TextStyle(color: Colors.white),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: Colors.white70),
                        weekendStyle: TextStyle(color: Colors.white70),
                      ),
                      onDaySelected: (sel, foc) {
                        setCalState(() {
                          selectedDay = sel;
                          focusedDay = foc;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Tasks on ${selectedDay.toString().substring(0, 10)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (dayTasks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E2D4F),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No tasks planned for this day.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                else
                  ...dayTasks.map(_taskCard),
              ],
            );
          },
        );
      },
    );
  }

  Widget _workloadAndMetrics(
    List<TeacherTask> tasks,
    DailyWorkload w,
    double completionRate,
    double onTimeRate,
    double efficiency,
  ) {
    final completionPercent = (completionRate * 100)
        .clamp(0, 100)
        .toStringAsFixed(0);
    final onTimePercent = (onTimeRate * 100).clamp(0, 100).toStringAsFixed(0);
    final efficiencyPercent = (efficiency * 100)
        .clamp(0, 200)
        .toStringAsFixed(0);

    Widget statTile(String title, String value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF1E2D4F).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: _cardRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.35),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Daily Pulse',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.auto_graph, color: Colors.white),
                    tooltip: 'Insights',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        backgroundColor: Color(0xFF1E1E1E),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) => _insightsSheet(tasks),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasks ${w.completedTasks}/${w.totalTasks}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: completionRate),
                          duration: const Duration(milliseconds: 600),
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value.clamp(0.0, 1.0),
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Estimated ${w.estimatedMinutes}m • Actual ${w.actualMinutes}m',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 34,
                        sectionsSpace: 3,
                        sections: [
                          PieChartSectionData(
                            value: w.completedTasks.toDouble(),
                            color: Colors.greenAccent,
                            radius: 46,
                            title: '',
                          ),
                          PieChartSectionData(
                            value: w.pendingTasks.toDouble(),
                            color: Colors.orangeAccent,
                            radius: 40,
                            title: '',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  statTile(
                    'Completion',
                    '$completionPercent%',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  statTile(
                    'On time',
                    '$onTimePercent%',
                    Icons.schedule,
                    Colors.cyan,
                  ),
                  statTile(
                    'Efficiency',
                    '$efficiencyPercent%',
                    Icons.speed,
                    Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightsSheet(List<TeacherTask> tasks) {
    final pending = tasks.where((t) => t.status != 'completed').length;
    final focusTypes = <String, int>{};
    for (final task in tasks) {
      focusTypes[task.taskType] = (focusTypes[task.taskType] ?? 0) + 1;
    }
    final sortedTypes = focusTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Focus today: $pending pending task(s)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedTypes.take(6).map((entry) {
              return Chip(
                avatar: const Icon(
                  Icons.local_offer,
                  size: 16,
                  color: Colors.cyanAccent,
                ),
                label: Text(
                  '${entry.key} • ${entry.value}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blueGrey,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductivityScreen(tasks: tasks),
                ),
              );
            },
            icon: const Icon(Icons.speed, color: Colors.black),
            label: const Text(
              'Open productivity dashboard',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WeeklyInsightsScreen(tasks: tasks),
                      ),
                    );
                  },
                  icon: const Icon(Icons.timeline),
                  label: const Text('Weekly insights'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<TeacherTask> tasks) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Color(0xFF1E2D4F),
          borderRadius: _cardRadius,
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
              '$title (${tasks.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty) _emptyState(title) else ...tasks.map(_taskCard),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Color(0xFF0F1C3F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.hourglass_empty,
            color: Colors.deepPurpleAccent,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'No $title tasks right now',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enjoy the calm or plan something new',
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(TeacherTask task) {
    final due = _deadlineForTask(task);
    final statusColor = _statusColor(task.status);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF1E1E1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFF3A4A6F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _priorityChip(task.priority),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  task.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              // IconButton(
              //   icon: const Icon(Icons.info_outline, color: Colors.white),
              //   tooltip: 'Details',
              //   onPressed: () => _showTaskDetails(task),
              // ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            task.description,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _infoChip(Icons.schedule, _timeLabel(task)),
              if (due != null) _infoChip(Icons.event_available, _dueLabel(due)),
              _infoChip(
                Icons.category_outlined,
                task.taskType.replaceAll('_', ' '),
              ),
            ],
          ),
          if (due != null) ...[
            const SizedBox(height: 14),
            _timeline(due, task.status),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: task.status == 'completed'
                        ? Color(0xFF0F1C3F)
                        : Colors.cyanAccent,
                    foregroundColor: task.status == 'completed'
                        ? Colors.white
                        : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final newStatus = task.status == 'completed'
                        ? 'pending'
                        : 'completed';
                    await _taskService.updateTaskStatus(task.id, newStatus);
                  },
                  icon: Icon(
                    task.status == 'completed'
                        ? Icons.undo
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    task.status == 'completed' ? 'Mark pending' : 'Mark done',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () =>
                    _notifService.sendTomorrowNudge(teacherId: _teacherId),
                icon: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
                tooltip: 'Nudge me tomorrow',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFF0F1C3F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.cyanAccent),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(DateTime due, String status) {
    final now = DateTime.now();
    final totalHours = due.difference(now).inHours.toDouble();
    final progress = totalHours <= 0
        ? 1.0
        : (1 - (totalHours / 72)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Timeline', style: TextStyle(color: Colors.white60)),
            Text(
              status == 'completed' ? 'Completed' : _countdownLabel(due),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF4F8FF),
            valueColor: AlwaysStoppedAnimation<Color>(
              status == 'completed'
                  ? Colors.green
                  : (due.isBefore(now) ? Colors.redAccent : Colors.amber),
            ),
          ),
        ),
      ],
    );
  }

  Widget _next7BarChart(List<TeacherTask> tasks) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(7, 0);

    for (final task in tasks) {
      if (task.plannedForDate == null) continue;
      final date = DateTime.parse(task.plannedForDate!);
      final diff = date.difference(start).inDays;
      if (diff >= 0 && diff < 7) {
        counts[diff] += 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1E2D4F),
          borderRadius: _cardRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next 7 days load',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index > 6)
                            return const SizedBox.shrink();
                          final day = start.add(Duration(days: index));
                          final label = '${day.month}/${day.day}';
                          return Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: counts[index].toDouble(),
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF7F7FD5),
                              Color(0xFF86A8E7),
                              Color(0xFF91EAE4),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateOnTimeRate(List<TeacherTask> tasks) {
    final completed = tasks.where((t) => t.status == 'completed');
    int eligible = 0;
    int onTime = 0;

    for (final task in completed) {
      final deadline = _deadlineForTask(task);
      if (deadline == null) continue;
      eligible++;
      final done = task.completedAt?.toDate() ?? DateTime.now();
      if (!done.isAfter(deadline)) {
        onTime++;
      }
    }

    if (eligible == 0) return 0;
    return onTime / eligible;
  }

  double _calculateEfficiency(List<TeacherTask> tasks) {
    final completed = tasks.where((t) => t.status == 'completed');
    if (completed.isEmpty) return 0;

    final estimated = completed.fold<int>(
      0,
      (sum, t) => sum + t.estimatedMinutes,
    );
    if (estimated == 0) return 0;

    final actual = completed.fold<int>(0, (sum, t) {
      final minutes = t.actualMinutes;
      return sum + (minutes <= 0 ? t.estimatedMinutes : minutes);
    });

    return actual / estimated;
  }

  DateTime? _deadlineForTask(TeacherTask task) {
    if (task.dueDate != null) {
      return task.dueDate!.toDate();
    }
    if (task.plannedForDate != null) {
      final planned = DateTime.parse(task.plannedForDate!);
      return DateTime(planned.year, planned.month, planned.day, 23, 59, 59);
    }
    return null;
  }

  String _timeLabel(TeacherTask task) {
    final est = task.estimatedMinutes;
    final act = task.actualMinutes;
    return 'Est ${est}m • Act ${act}m';
  }

  String _dueLabel(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now).inHours;
    if (diff >= 24) {
      final days = (diff / 24).ceil();
      return 'Due in $days d';
    } else if (diff >= 0) {
      return 'Due in ${diff}h';
    }
    return 'Overdue';
  }

  String _countdownLabel(DateTime due) {
    final now = DateTime.now();
    final hours = due.difference(now).inHours;
    if (hours >= 24) {
      return '${(hours / 24).floor()}d left';
    }
    if (hours >= 0) {
      return '${hours}h left';
    }
    return 'Overdue';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.amber;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _priorityChip(String priority) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.whatshot, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'low':
        return Colors.blueGrey;
      default:
        return Colors.amber;
    }
  }

  void _showTaskDetails(TeacherTask task) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                task.description,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              _infoChip(Icons.category, task.taskType),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _infoChip(Icons.timer, _timeLabel(task))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoChip(
                      Icons.event,
                      task.plannedForDate ?? 'No plan date',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
