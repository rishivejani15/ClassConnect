class ProductivityMetrics {
  final int totalTasks;
  final int completedTasks;
  final double completionRate;

  final int onTimeCompleted;
  final double onTimeRate;

  final int estimatedMinutes;
  final int actualMinutes;
  final double efficiency;

  ProductivityMetrics({
    required this.totalTasks,
    required this.completedTasks,
    required this.completionRate,
    required this.onTimeCompleted,
    required this.onTimeRate,
    required this.estimatedMinutes,
    required this.actualMinutes,
    required this.efficiency,
  });
}
