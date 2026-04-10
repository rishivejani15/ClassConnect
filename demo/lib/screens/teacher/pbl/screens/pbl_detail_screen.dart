import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'pair_submissions_screen.dart';

class PblDetailScreen extends StatefulWidget {
  final String classId;
  final String pblId;
  final String title;
  final Map<String, dynamic> pblData;

  const PblDetailScreen({
    super.key,
    required this.classId,
    required this.pblId,
    required this.title,
    required this.pblData,
  });

  @override
  State<PblDetailScreen> createState() => _PblDetailScreenState();
}

class _PblDetailScreenState extends State<PblDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF4F8FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.classId)
            .collection('PBL')
            .doc(widget.pblId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pblData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final Timestamp? deadlineTimestamp =
              pblData['deadline'] as Timestamp?;
          final DateTime? deadline = deadlineTimestamp?.toDate();

          // Calculate Stats
          final assignments = pblData['studentAssignments'] as List? ?? [];
          int totalStudents = 0;
          int submittedStudents = 0;

          for (var assignment in assignments) {
            final students = assignment['students'] as List? ?? [];
            for (var student in students) {
              totalStudents++;
              if (student['submission'] != null &&
                  student['submission']['fileUrl'] != null) {
                submittedStudents++;
              }
            }
          }

          int remainingStudents = totalStudents - submittedStudents;
          double submittedPercentage = totalStudents == 0
              ? 0
              : (submittedStudents / totalStudents) * 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Problem Statement
                // Problem Statement
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152349),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROBLEM STATEMENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pblData['problemStatement'] ?? 'No problem statement',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Assign Students Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAssignStudentsDialog(),
                    icon: const Icon(Icons.group_add, color: Colors.black),
                    label: const Text(
                      'Assign Students to Pairs',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.cyanAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // View Assignments Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAssignments(pblData),
                    icon: const Icon(
                      Icons.visibility,
                      color: Colors.cyanAccent,
                    ),
                    label: const Text(
                      'View Student Assignments',
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.cyanAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Set Deadline Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDeadline(pblData),
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                    ),
                    label: Text(
                      deadline == null
                          ? 'Set Project Deadline'
                          : 'Edit Deadline (Due: ${DateFormat('MMM d').format(deadline)})',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Submission Stats Chart
                if (totalStudents > 0) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'SUBMISSION OVERVIEW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  color: Colors.green,
                                  value: submittedStudents.toDouble(),
                                  title:
                                      '${submittedPercentage.toStringAsFixed(0)}%',
                                  radius: 50,
                                  titleStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                PieChartSectionData(
                                  color: Colors.redAccent,
                                  value: remainingStudents.toDouble(),
                                  title: '',
                                  radius: 40,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                              color: Colors.green,
                              text: 'Submitted ($submittedStudents)',
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              color: Colors.redAccent,
                              text: 'Remaining ($remainingStudents)',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total Students: $totalStudents',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAssignStudentsDialog() {
    final pairCountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF152349),
        title: const Text(
          'Create Student Pairs',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How many students in each pair?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pairCountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Students per pair',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'e.g., 2 or 3',
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final studentsPerPair =
                  int.tryParse(pairCountController.text) ?? 2;
              Navigator.pop(context);
              _assignStudents(studentsPerPair);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text(
              'Assign',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignStudents(int studentsPerPair) async {
    try {
      // Fetch students enrolled in this class
      final classStudentsSnapshot = await FirebaseFirestore.instance
          .collection('class_students')
          .where('classId', isEqualTo: widget.classId)
          .get();

      if (classStudentsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No students enrolled in this class')),
          );
        }
        return;
      }

      final studentIds = classStudentsSnapshot.docs
          .map((doc) => doc['studentId'] as String)
          .toList();

      // Fetch student details
      final students = <Map<String, dynamic>>[];

      // Firestore 'whereIn' is limited to 10 items, so we might need to batch or fetch individually
      // safely fetching individually since class size is reasonable for this demo,
      // or using whereIn in chunks if performance is critical.
      // For simplicity and robustness here, fetching individually or getting all students
      // and filtering is options.
      // Better approach: fetch all students who are in the list.

      // actually, let's just fetch individual docs to be safe and accurate
      for (final uid in studentIds) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(uid)
            .get();
        if (studentDoc.exists) {
          students.add({
            'uid': uid,
            'name': studentDoc['name'] ?? 'Unknown',
            'email': studentDoc['email'] ?? 'Unknown',
          });
        }
      }

      if (students.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No students found')));
        }
        return;
      }

      // Shuffle students randomly
      students.shuffle(Random());

      // Create pairs
      final pairs = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < students.length; i += studentsPerPair) {
        final pair = students.sublist(
          i,
          (i + studentsPerPair > students.length)
              ? students.length
              : i + studentsPerPair,
        );
        pairs.add(pair);
      }

      // Save assignments to Firestore
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('PBL')
          .doc(widget.pblId)
          .update({
            'studentAssignments': pairs
                .asMap()
                .entries
                .map(
                  (entry) => {
                    'pairNumber': entry.key + 1,
                    'students': entry.value,
                  },
                )
                .toList(),
            'assignedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created ${pairs.length} pair${pairs.length > 1 ? 's' : ''} successfully!',
            ),
          ),
        );
        final assignmentsList = pairs
            .asMap()
            .entries
            .map(
              (entry) => {'pairNumber': entry.key + 1, 'students': entry.value},
            )
            .toList();

        _showAssignments({'studentAssignments': assignmentsList});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Widget _buildLegendItem({required Color color, required String text}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDeadline(Map<String, dynamic> pblData) async {
    final Timestamp? currentTimestamp = pblData['deadline'] as Timestamp?;
    final DateTime initialDate =
        currentTimestamp?.toDate() ??
        DateTime.now().add(const Duration(days: 7));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    if (!mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null) return;

    final DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('PBL')
          .doc(widget.pblId)
          .update({'deadline': Timestamp.fromDate(finalDateTime)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deadline set to ${DateFormat('MMM d, yyyy h:mm a').format(finalDateTime)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error setting deadline: $e')));
      }
    }
  }

  void _showAssignments(Map<String, dynamic> pblData) {
    final assignments = pblData['studentAssignments'] as List? ?? [];

    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No student assignments yet. Create pairs first!'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1C3F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Student Assignments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  final pairNumber = assignment['pairNumber'] ?? index + 1;
                  final students = (assignment['students'] as List?) ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF152349),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PairSubmissionsScreen(
                                classId: widget.classId,
                                pblId: widget.pblId,
                                pairNumber: pairNumber,
                                students: students,
                                problemStatement:
                                    widget.pblData['problemStatement'] ??
                                    'No Description',
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pair $pairNumber',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent.shade200,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...students.map((student) {
                                final bool isSubmitted =
                                    student['submission'] != null &&
                                    student['submission']['fileUrl'] != null;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student['name'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              student['email'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Tooltip(
                                        message: isSubmitted
                                            ? 'Submitted'
                                            : 'Pending',
                                        child: Icon(
                                          isSubmitted
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          color: isSubmitted
                                              ? Colors.greenAccent
                                              : Colors.white24,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}