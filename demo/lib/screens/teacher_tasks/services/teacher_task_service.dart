import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'task_estimator.dart';

class TeacherTaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Resolve the current teacher's ID from Firebase Auth.
  /// Throws if teacher is not logged in (correct behavior).
  String getTeacherId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Teacher not logged in');
    }
    return user.uid;
  }

  /// Create lesson planning task when teacher adds a concept
  Future<void> createLessonPlanTask({
    required String classId,
    required String conceptId,
    required String conceptTitle,
    required int studentCount,
  }) async {
    final teacherId = getTeacherId();

    final task = {
      'teacherId': teacherId,
      'classId': classId,

      'taskType': 'lesson_plan',
      'sourceType': 'concept',
      'sourceId': conceptId,

      'title': 'Plan lesson: $conceptTitle',
      'description': 'Prepare objectives, examples and activities',

      'estimatedMinutes': estimateTaskMinutes('lesson_plan', studentCount),
      'actualMinutes': 0,

      'status': 'pending',
      'priority': 'medium',

      'dueDate': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 2)),
      ),

      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    };

    debugPrint(
      'TeacherTaskService: creating task for teacherId=$teacherId '
      'classId=$classId title=Plan lesson: $conceptTitle',
    );

    final ref = await _db.collection('teacher_tasks').add(task);
    debugPrint('TeacherTaskService: created task docId=${ref.id}');
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    final Map<String, dynamic> update = {'status': status};

    if (status == 'completed') {
      update['completedAt'] = FieldValue.serverTimestamp();
    }

    await _db.collection('teacher_tasks').doc(taskId).update(update);
    debugPrint('TeacherTaskService: updated taskId=$taskId status=$status');
  }

  Future<void> createManualPlannedTask({
    required String plannedForDate, // YYYY-MM-DD
    required String taskType,
    required String title,
    required int estimatedMinutes,
    required String priority,
    DateTime? dueDate,
  }) async {
    final teacherId = getTeacherId();

    final task = {
      'teacherId': teacherId,
      'classId': null,

      'taskType': taskType,
      'sourceType': null,
      'sourceId': null,

      // 🔑 PLANNING FIELDS
      'planningType': 'manual',
      'plannedForDate': plannedForDate,

      'title': title,
      'description': '',

      'estimatedMinutes': estimatedMinutes,
      'actualMinutes': 0,

      'status': 'pending',
      'priority': priority,

      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
    };

    final ref = await _db.collection('teacher_tasks').add(task);
    debugPrint('Manual planned task created: ${ref.id}');
  }

  Future<void> createWeeklyPlannedTasks({
    required List<String> plannedDates, // list of YYYY-MM-DD
    required String taskType,
    required String title,
    required int estimatedMinutes,
    required String priority,
    DateTime? dueDate,
  }) async {
    final teacherId = getTeacherId();
    final batch = _db.batch();

    for (final date in plannedDates) {
      final ref = _db.collection('teacher_tasks').doc();
      batch.set(ref, {
        'teacherId': teacherId,
        'classId': null,

        'taskType': taskType,
        'sourceType': null,
        'sourceId': null,

        // 🔑 PLANNING
        'planningType': 'manual',
        'plannedForDate': date,

        'title': title,
        'description': '',

        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': 0,

        'status': 'pending',
        'priority': priority,

        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      });
    }

    await batch.commit();
    debugPrint('Weekly planned tasks created: ${plannedDates.length}');
  }
}
