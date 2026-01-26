import '../models/teacher_task.dart';
import '../models/productivity.dart';

/// -------------------------------
/// CORE PRODUCTIVITY CALCULATOR
/// -------------------------------
/// Uses ONLY manually planned tasks
/// Uses plannedForDate as intent
ProductivityMetrics calculateProductivity(
  List<TeacherTask> tasks,
  DateTime fromDate,
) {
  final filteredTasks = tasks.where((task) {
    if (task.planningType != 'manual') return false;
    if (task.plannedForDate == null) return false;

    final plannedDate = DateTime.parse(task.plannedForDate!);
    return plannedDate.isAfter(fromDate) ||
        plannedDate.isAtSameMomentAs(fromDate);
  }).toList();

  final totalTasks = filteredTasks.length;

  final completedTasks = filteredTasks
      .where((t) => t.status == 'completed')
      .length;

  final completionRate = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

  // -------------------------------
  // ON-TIME COMPLETION
  // -------------------------------
  int onTimeEligible = 0;
  int onTimeCompleted = 0;
  for (final task in filteredTasks) {
    if (task.status != 'completed') continue;
    final deadline = _resolveDeadline(task);
    if (deadline == null) continue;
    onTimeEligible++;
    final completion = task.completedAt?.toDate() ?? DateTime.now();
    if (!completion.isAfter(deadline)) {
      onTimeCompleted++;
    }
  }

  final onTimeRate = onTimeEligible == 0
      ? 0.0
      : onTimeCompleted / onTimeEligible;

  // -------------------------------
  // TIME EFFICIENCY
  // -------------------------------
  final efficiencyTasks = filteredTasks
      .where((t) => t.status == 'completed')
      .toList();

  final estimatedMinutes = efficiencyTasks.fold(
    0,
    (sum, t) => sum + t.estimatedMinutes,
  );

  final actualMinutes = efficiencyTasks.fold(0, (sum, t) {
    final actual = t.actualMinutes;
    if (actual <= 0) {
      return sum + t.estimatedMinutes;
    }
    return sum + actual;
  });

  final efficiency = estimatedMinutes == 0
      ? 0.0
      : actualMinutes / estimatedMinutes;

  return ProductivityMetrics(
    totalTasks: totalTasks,
    completedTasks: completedTasks,
    completionRate: completionRate,
    onTimeCompleted: onTimeCompleted,
    onTimeRate: onTimeRate,
    estimatedMinutes: estimatedMinutes,
    actualMinutes: actualMinutes,
    efficiency: efficiency,
  );
}

List<String> detectOverplannedDays(
  Map<String, int> minutesPerDay, {
  int thresholdMinutes = 360,
}) {
  return minutesPerDay.entries
      .where((e) => e.value > thresholdMinutes)
      .map((e) => e.key)
      .toList();
}

/// -------------------------------
/// MISSED DEADLINE DETECTOR
/// -------------------------------
/// Counts:
/// - Tasks completed AFTER due date
/// - Tasks NOT completed AND due date passed
int countMissedDeadlines(List<TeacherTask> tasks) {
  return tasksMissedDeadlines(tasks).length;
}

List<TeacherTask> tasksMissedDeadlines(List<TeacherTask> tasks) {
  return tasks.where((t) {
    if (t.planningType != 'manual') return false;
    if (t.dueDate == null) return false;

    final due = t.dueDate!.toDate();

    if (t.completedAt == null) {
      return DateTime.now().isAfter(due);
    }

    return t.completedAt!.toDate().isAfter(due);
  }).toList();
}

DateTime? _resolveDeadline(TeacherTask task) {
  if (task.dueDate != null) return task.dueDate!.toDate();
  if (task.plannedForDate != null) {
    final planned = DateTime.parse(task.plannedForDate!);
    return DateTime(planned.year, planned.month, planned.day, 23, 59, 59);
  }
  return null;
}
