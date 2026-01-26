import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'class_automation_service.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ClassAutomationService _automationService = ClassAutomationService();

  /* ============================================================
     🔐 UTIL
  ============================================================ */

  String _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    return user;
  }

  /* ============================================================
     👨‍🏫 TEACHER
  ============================================================ */

  /// Create a new class (Teacher)
  Future<String> createClass({
    required String className,
    required String subject,
    required String description,
    required int studentSem,
    required String studentDiv,
    required String collegeSchoolName,
    required String studentType,
  }) async {
    final teacher = _requireUser();

    final classCode = _generateClassCode();

    final classDoc = await _firestore.collection('classes').add({
      'class_name': className,
      'subject': subject,
      'description': description,
      'class_code': classCode,
      'teacherId': teacher.uid,
      'student_count': 0,
      'studentSem': studentSem,
      'studentDiv': studentDiv,
      'collegeSchoolName': collegeSchoolName,
      'studentType': studentType,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 🤖 Automatically enroll matching students
    try {
      await _automationService.autoEnrollStudents(
        classId: classDoc.id,
        studentSem: studentSem,
        studentDiv: studentDiv,
        collegeSchoolName: collegeSchoolName,
        studentType: studentType,
      );
    } catch (e) {
      print('Warning: Automatic enrollment failed: $e');
      // Don't throw - class creation should still succeed
    }

    return classCode;
  }

  /// Get classes created by logged-in teacher
  Stream<QuerySnapshot> getTeacherClasses() {
    final teacher = _auth.currentUser;
    if (teacher == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacher.uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /* ============================================================
     🎓 STUDENT
  ============================================================ */

  /// Join class using 6-digit code
  Future<void> joinClassByCode(String classCode) async {
    final student = _requireUser();

    // 1️⃣ Find class
    final query = await _firestore
        .collection('classes')
        .where('class_code', isEqualTo: classCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception("Invalid class code");
    }

    final classDoc = query.docs.first;
    final classId = classDoc.id;

    // 2️⃣ Prevent duplicate join
    final alreadyJoined = await _firestore
        .collection('class_students')
        .where('classId', isEqualTo: classId)
        .where('studentId', isEqualTo: student.uid)
        .limit(1)
        .get();

    if (alreadyJoined.docs.isNotEmpty) {
      throw Exception("You already joined this class");
    }

    // 3️⃣ Add student
    await _firestore.collection('class_students').add({
      'classId': classId,
      'studentId': student.uid,
      'joined_at': FieldValue.serverTimestamp(),
    });

    // 4️⃣ Increment student count
    await _firestore.collection('classes').doc(classId).update({
      'student_count': FieldValue.increment(1),
    });
  }

  /// Get classes joined by logged-in student
  Stream<List<QueryDocumentSnapshot>> getStudentClasses() {
    final student = _auth.currentUser;
    if (student == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('class_students')
        .where('studentId', isEqualTo: student.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          final classIds = snapshot.docs
              .map((d) => d['classId'] as String)
              .toList();

          if (classIds.isEmpty) return [];

          final classes = await _firestore
              .collection('classes')
              .where(FieldPath.documentId, whereIn: classIds)
              .get();

          return classes.docs;
        });
  }
}
