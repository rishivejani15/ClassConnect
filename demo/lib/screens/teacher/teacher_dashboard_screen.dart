import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;

  // Dashboard Data
  List<Map<String, dynamic>> students = [];
  late List<Map<String, dynamic>> _filteredStudents;

  int _totalClasses = 0;
  int _totalConcepts = 0;
  int _totalPBLs = 0;
  int _pendingTasks = 0;
  int _totalCommunityQuestions = 0;
  double _avgQuizScore = 0.0;
  double _avgCommunityScore = 0.0;
  double _avgPBLScore = 0.0;
  double _avgXP = 0.0;

  List<Map<String, dynamic>> _weakConcepts = [];
  List<Map<String, dynamic>> _attendanceData = [];
  Map<String, int> _taskWorkload = {};
  List<Map<String, dynamic>> _communityEngagement = [];

  @override
  void initState() {
    super.initState();
    _filteredStudents = [];
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final teacherId = FirebaseAuth.instance.currentUser?.uid;
      if (teacherId == null) return;

      await Future.wait([
        _fetchClassesData(teacherId),
        _fetchStudentsData(teacherId),
        _fetchAttendanceData(teacherId),
        _fetchWeakConcepts(teacherId),
        _fetchTaskWorkload(teacherId),
        _fetchCommunityData(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchClassesData(String teacherId) async {
    final classesSnapshot = await _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    _totalClasses = classesSnapshot.docs.length;
    _totalConcepts = 0;
    _totalPBLs = 0;

    for (var classDoc in classesSnapshot.docs) {
      final conceptsSnapshot = await classDoc.reference
          .collection('concepts')
          .get();
      _totalConcepts += conceptsSnapshot.docs.length;

      final pblSnapshot = await classDoc.reference.collection('pbl').get();
      _totalPBLs += pblSnapshot.docs.length;
    }
  }

  Future<void> _fetchStudentsData(String teacherId) async {
    final classesSnapshot = await _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final classIds = classesSnapshot.docs.map((d) => d.id).toList();

    Set<String> studentIds = {};
    for (final classId in classIds) {
      final classStudentsSnapshot = await _firestore
          .collection('class_students')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in classStudentsSnapshot.docs) {
        studentIds.add(doc['studentId']);
      }
    }

    List<Map<String, dynamic>> loadedStudents = [];
    double totalQuiz = 0;
    double totalCommunity = 0;
    double totalPBL = 0;
    double totalXP = 0;

    for (final studentId in studentIds) {
      final studentDoc = await _firestore
          .collection('students')
          .doc(studentId)
          .get();
      if (!studentDoc.exists) continue;

      final studentData = studentDoc.data()!;

      // Quiz performance
      final quizSnapshot = await _firestore
          .collection('quiz_attempts')
          .where('studentId', isEqualTo: studentId)
          .get();

      double avgQuizScore = 0;
      if (quizSnapshot.docs.isNotEmpty) {
        final scores = quizSnapshot.docs
            .where((q) {
              final score = q['score'] as num?;
              final total = q['total'] as num?;
              return score != null && total != null && total != 0;
            })
            .map((q) => ((q['score'] as num) / (q['total'] as num)) * 100)
            .toList();

        if (scores.isNotEmpty) {
          avgQuizScore = scores.reduce((a, b) => a + b) / scores.length;
        }
      }

      // Leaderboard data
      final leaderboardSnapshot = await _firestore
          .collection('class_leaderboard')
          .get();

      double communityScore = 0;
      double pblScore = 0;
      double xp = 0;

      for (final lb in leaderboardSnapshot.docs) {
        final lbData = lb.data();
        if (lbData['studentId'] == studentId) {
          communityScore = (lbData['community_score'] as num?)?.toDouble() ?? 0;
          pblScore = (lbData['pbl_score'] as num?)?.toDouble() ?? 0;
          xp = (lbData['xp'] as num?)?.toDouble() ?? 0;
          break;
        }
      }

      // Attendance calculation
      double attendancePercentage = 0.0;
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      int presentCount = 0;
      int totalCount = 0;

      for (final att in attendanceSnapshot.docs) {
        final presentIds = att['presentStudentIds'] as List<dynamic>? ?? [];
        final absentIds = att['absentStudentIds'] as List<dynamic>? ?? [];

        if (presentIds.contains(studentId) || absentIds.contains(studentId)) {
          totalCount++;
          if (presentIds.contains(studentId)) {
            presentCount++;
          }
        }
      }

      if (totalCount > 0) {
        attendancePercentage = (presentCount / totalCount) * 100;
      }

      // PBL submissions
      final pblSubmissions = await _firestore
          .collection('students')
          .doc(studentId)
          .collection('submittedPBL')
          .get();

      double assignmentCompletion =
          (pblSubmissions.docs.length / (_totalPBLs > 0 ? _totalPBLs : 1)) *
          100;
      if (assignmentCompletion > 100) assignmentCompletion = 100;

      totalQuiz += avgQuizScore;
      totalCommunity += communityScore;
      totalPBL += pblScore;
      totalXP += xp;

      loadedStudents.add({
        'name': studentData['name'] ?? 'Unknown',
        'email': studentData['email'] ?? '',
        'quiz_score': avgQuizScore,
        'attendance': attendancePercentage,
        'assignments': assignmentCompletion,
        'xp': xp,
        'community_score': communityScore,
        'pbl_score': pblScore,
      });
    }

    if (loadedStudents.isNotEmpty) {
      _avgQuizScore = totalQuiz / loadedStudents.length;
      _avgCommunityScore = totalCommunity / loadedStudents.length;
      _avgPBLScore = totalPBL / loadedStudents.length;
      _avgXP = totalXP / loadedStudents.length;
    }

    setState(() {
      students = loadedStudents;
      _filteredStudents = List.from(students);
    });
  }

  Future<void> _fetchAttendanceData(String teacherId) async {
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('date', descending: true)
        .limit(30)
        .get();

    _attendanceData = [];

    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final present = (data['presentCount'] as int?) ?? 0;
      final total = (data['totalStudents'] as int?) ?? 0;

      _attendanceData.add({
        'date': data['date'],
        'present': present,
        'total': total,
        'percentage': total > 0 ? (present / total * 100) : 0,
      });
    }
  }

  Future<void> _fetchWeakConcepts(String teacherId) async {
    final classesSnapshot = await _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final classIds = classesSnapshot.docs.map((d) => d.id).toList();
    Set<String> studentIds = {};

    for (final classId in classIds) {
      final classStudents = await _firestore
          .collection('class_students')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in classStudents.docs) {
        studentIds.add(doc['studentId']);
      }
    }

    Map<String, int> conceptFrequency = {};

    for (final studentId in studentIds) {
      final quizAttempts = await _firestore
          .collection('quiz_attempts')
          .where('studentId', isEqualTo: studentId)
          .get();

      for (var doc in quizAttempts.docs) {
        final weakConcepts = doc.data()['weakConcepts'] as List<dynamic>?;
        if (weakConcepts != null) {
          for (var concept in weakConcepts) {
            conceptFrequency[concept.toString()] =
                (conceptFrequency[concept.toString()] ?? 0) + 1;
          }
        }
      }
    }

    _weakConcepts =
        conceptFrequency.entries
            .map((e) => {'concept': e.key, 'count': e.value})
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    _weakConcepts = _weakConcepts.take(10).toList();
  }

  Future<void> _fetchTaskWorkload(String teacherId) async {
    final tasksSnapshot = await _firestore
        .collection('teacher_tasks')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    _taskWorkload = {'pending': 0, 'completed': 0, 'overdue': 0};
    _pendingTasks = 0;

    final now = DateTime.now();

    for (var doc in tasksSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'pending';
      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();

      if (status == 'pending' || status == 'in_progress') {
        _pendingTasks++;
        if (dueDate != null && dueDate.isBefore(now)) {
          _taskWorkload['overdue'] = (_taskWorkload['overdue'] ?? 0) + 1;
        } else {
          _taskWorkload['pending'] = (_taskWorkload['pending'] ?? 0) + 1;
        }
      } else if (status == 'completed') {
        _taskWorkload['completed'] = (_taskWorkload['completed'] ?? 0) + 1;
      }
    }
  }

  Future<void> _fetchCommunityData() async {
    final communitySnapshot = await _firestore
        .collection('community')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    _totalCommunityQuestions = communitySnapshot.docs.length;
    _communityEngagement = [];

    for (var doc in communitySnapshot.docs) {
      final data = doc.data();
      _communityEngagement.add({
        'title': data['title'] ?? 'Untitled',
        'userName': data['userName'] ?? 'Anonymous',
        'views': data['views'] ?? 0,
        'answers': data['answerCount'] ?? 0,
      });
    }
  }

  double _calculateAverage(String key) {
    if (_filteredStudents.isEmpty) return 0;
    double sum = 0;
    for (var student in _filteredStudents) {
      sum += student[key] as double;
    }
    return sum / _filteredStudents.length;
  }

  List<Map<String, dynamic>> _getTopPerformers() {
    List<Map<String, dynamic>> ranked = List.from(_filteredStudents);
    ranked.sort((a, b) => (b['xp'] as double).compareTo(a['xp'] as double));
    return ranked.take(3).toList();
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredStudents = List.from(students);
      } else {
        _filteredStudents = students
            .where(
              (student) => (student['name'] as String).toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF0F1C3F), const Color(0xFF0F1C3F)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
          ),
        ),
      );
    }

    final avgAttendance = _calculateAverage('attendance');
    final avgAssignments = _calculateAverage('assignments');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF0F1C3F), const Color(0xFF0F1C3F)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(user?.displayName ?? 'Teacher'),
                  const SizedBox(height: 30),

                  // Quick Stats Overview
                  _sectionTitle('Quick Overview'),
                  _buildQuickStatsGrid(constraints.maxWidth),
                  const SizedBox(height: 30),

                  _buildSearchBar(),
                  const SizedBox(height: 30),

                  _buildStatsRow(isMobile),
                  const SizedBox(height: 30),

                  _sectionTitle('Performance Overview'),
                  _buildGlassCard(child: _performanceChart()),
                  const SizedBox(height: 30),

                  _sectionTitle('Student XP Trend'),
                  _buildGlassCard(child: _studentTrendChart()),
                  const SizedBox(height: 30),

                  if (isMobile) ...[
                    _sectionTitle('Attendance'),
                    _buildGlassCard(child: _attendanceWidget(avgAttendance)),
                    const SizedBox(height: 30),
                    _sectionTitle('PBL Submissions'),
                    _buildGlassCard(child: _assignmentsWidget(avgAssignments)),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Attendance'),
                              _buildGlassCard(
                                child: _attendanceWidget(avgAttendance),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('PBL Submissions'),
                              _buildGlassCard(
                                child: _assignmentsWidget(avgAssignments),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 30),

                  // Weak Concepts
                  if (_weakConcepts.isNotEmpty) ...[
                    _sectionTitle('Weak Concepts (Needs Attention)'),
                    _buildWeakConceptsSection(),
                    const SizedBox(height: 30),
                  ],

                  // Task Workload
                  _sectionTitle('Task Workload'),
                  _buildGlassCard(child: _buildTaskWorkloadChart()),
                  const SizedBox(height: 30),

                  _sectionTitle('Top 3 Performers (By XP)'),
                  _buildTopPerformersSection(),
                  const SizedBox(height: 30),

                  _sectionTitle('All Students Performance'),
                  _buildStudentsTable(),
                  const SizedBox(height: 30),

                  _sectionTitle('Performance Distribution'),
                  _buildGlassCard(child: _performanceDistributionChart()),
                  const SizedBox(height: 30),

                  if (isMobile) ...[
                    _sectionTitle('Score Breakdown'),
                    _buildGlassCard(child: _scorePieChart()),
                    const SizedBox(height: 30),
                    _sectionTitle('Performance Stats'),
                    _buildGlassCard(child: _performanceStatsWidget()),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Score Breakdown'),
                              _buildGlassCard(child: _scorePieChart()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Performance Stats'),
                              _buildGlassCard(child: _performanceStatsWidget()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 30),

                  _sectionTitle('Class Statistics Overview'),
                  _buildStatisticsOverview(isMobile),
                  const SizedBox(height: 30),

                  if (_communityEngagement.isNotEmpty) ...[
                    _sectionTitle('Community Engagement'),
                    _buildCommunityEngagementSection(),
                    const SizedBox(height: 30),
                  ],

                  _sectionTitle('XP vs Performance'),
                  _buildGlassCard(child: _xpVsPerformance()),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ========== WIDGETS ==========

  Widget _buildQuickStatsGrid(double width) {
    int crossAxisCount = width < 600
        ? 2
        : width < 1200
        ? 3
        : 6;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _quickStatCard(
          'Total Classes',
          _totalClasses.toString(),
          '🏫',
          const Color(0xFF00D9FF),
        ),
        _quickStatCard(
          'Total Students',
          students.length.toString(),
          '👥',
          const Color(0xFF6BCB77),
        ),
        _quickStatCard(
          'Concepts',
          _totalConcepts.toString(),
          '📚',
          const Color(0xFFFF9F43),
        ),
        _quickStatCard(
          'PBL Projects',
          _totalPBLs.toString(),
          '🎯',
          const Color(0xFFFF6B6B),
        ),
        _quickStatCard(
          'Pending Tasks',
          _pendingTasks.toString(),
          '✓',
          const Color(0xFFFFD93D),
        ),
        _quickStatCard(
          'Community Q&A',
          _totalCommunityQuestions.toString(),
          '💬',
          const Color(0xFF4ECDC4),
        ),
      ],
    );
  }

  Widget _quickStatCard(String title, String value, String icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakConceptsSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _weakConcepts.take(5).map((concept) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF6B6B).withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept['concept'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${concept['count']} students struggling',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskWorkloadChart() {
    if (_taskWorkload.isEmpty) {
      return const Center(
        child: Text('No task data', style: TextStyle(color: Colors.white70)),
      );
    }

    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const titles = ['Pending', 'Completed', 'Overdue'];
                if (value.toInt() < titles.length) {
                  return Text(
                    titles[value.toInt()],
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                );
              },
            ),
          ),
        ),
        barGroups: [
          _buildBarGroup(
            0,
            _taskWorkload['pending']!.toDouble(),
            const Color(0xFFFFD93D),
          ),
          _buildBarGroup(
            1,
            _taskWorkload['completed']!.toDouble(),
            const Color(0xFF6BCB77),
          ),
          _buildBarGroup(
            2,
            _taskWorkload['overdue']!.toDouble(),
            const Color(0xFFFF6B6B),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityEngagementSection() {
    return Column(
      children: _communityEngagement.take(5).map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'by ${item['userName']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '👁 ${item['views']} | 💬 ${item['answers']}',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: _filterStudents,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: Colors.white70),
          hintText: 'Search student by name...',
          hintStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    _filterStudents('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildHeader(String teacherName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          teacherName,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF00D9FF),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF00D9FF),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(height: 250, child: child),
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    List<Widget> cards = [
      _statCard(
        title: 'Quiz Avg',
        value: _avgQuizScore.toStringAsFixed(1),
        color: const Color(0xFFFF6B6B),
        icon: '📐',
      ),
      _statCard(
        title: 'Community',
        value: _avgCommunityScore.toStringAsFixed(1),
        color: const Color(0xFF4ECDC4),
        icon: '💬',
      ),
      _statCard(
        title: 'PBL Avg',
        value: _avgPBLScore.toStringAsFixed(1),
        color: const Color(0xFFFFD93D),
        icon: '🎯',
      ),
    ];

    // Always return Row to keep them in one line horizontally
    return Row(
      children: cards
          .map((c) => Expanded(child: c))
          .toList()
          .expand((element) => [element, const SizedBox(width: 12)])
          .take(cards.length * 2 - 1)
          .toList(),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required Color color,
    required String icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _performanceChart() {
    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const titles = ['Quiz', 'Community', 'PBL'];
                if (value.toInt() < titles.length) {
                  return Text(
                    titles[value.toInt()],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                );
              },
            ),
          ),
        ),
        barGroups: [
          _buildBarGroup(0, _avgQuizScore, const Color(0xFFFF6B6B)),
          _buildBarGroup(1, _avgCommunityScore, const Color(0xFF4ECDC4)),
          _buildBarGroup(2, _avgPBLScore, const Color(0xFFFFD93D)),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 40,
          borderRadius: BorderRadius.circular(8),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _studentTrendChart() {
    if (_filteredStudents.isEmpty) {
      return const Center(
        child: Text('No student data', style: TextStyle(color: Colors.white70)),
      );
    }

    final xpScores = _filteredStudents.map((s) => s['xp'] as double).toList();
    final spots = List.generate(
      xpScores.length,
      (i) => FlSpot(i.toDouble(), xpScores[i]),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                'S${(value + 1).toInt()}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF00D9FF),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: const Color(0xFF00D9FF),
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00D9FF).withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceWidget(double value) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 8,
              color: const Color(0xFF6BCB77),
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Present',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assignmentsWidget(double value) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 8,
              color: const Color(0xFFFF9F43),
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Completed',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformersSection() {
    final topThree = _getTopPerformers();
    if (topThree.isEmpty) {
      return const Center(
        child: Text('No student data', style: TextStyle(color: Colors.white70)),
      );
    }

    const medals = ['🥇', '🥈', '🥉'];
    const colors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];

    return Column(
      children: List.generate(topThree.length, (index) {
        final student = topThree[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: colors[index].withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors[index].withOpacity(0.5),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'XP: ${(student['xp'] as double).toInt()} | Community: ${(student['community_score'] as double).toInt()} | PBL: ${(student['pbl_score'] as double).toInt()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(medals[index], style: const TextStyle(fontSize: 20)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _performanceDistributionChart() {
    if (_filteredStudents.isEmpty) {
      return const Center(
        child: Text('No student data', style: TextStyle(color: Colors.white70)),
      );
    }

    Map<String, int> xpRanges = {
      '0-50': 0,
      '51-100': 0,
      '101-200': 0,
      '200+': 0,
    };

    for (var student in _filteredStudents) {
      double xp = student['xp'] as double;
      if (xp <= 50)
        xpRanges['0-50'] = xpRanges['0-50']! + 1;
      else if (xp <= 100)
        xpRanges['51-100'] = xpRanges['51-100']! + 1;
      else if (xp <= 200)
        xpRanges['101-200'] = xpRanges['101-200']! + 1;
      else
        xpRanges['200+'] = xpRanges['200+']! + 1;
    }

    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const ranges = ['0-50', '51-100', '101-200', '200+'];
                if (value.toInt() < ranges.length) {
                  return Text(
                    ranges[value.toInt()],
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
        ),
        barGroups: [
          _buildBarGroup(
            0,
            xpRanges['0-50']!.toDouble(),
            const Color(0xFFFF6B6B),
          ),
          _buildBarGroup(
            1,
            xpRanges['51-100']!.toDouble(),
            const Color(0xFFFFD93D),
          ),
          _buildBarGroup(
            2,
            xpRanges['101-200']!.toDouble(),
            const Color(0xFF4ECDC4),
          ),
          _buildBarGroup(
            3,
            xpRanges['200+']!.toDouble(),
            const Color(0xFF6BCB77),
          ),
        ],
      ),
    );
  }

  Widget _scorePieChart() {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: _avgQuizScore,
            title: 'Quiz\n${_avgQuizScore.toStringAsFixed(0)}',
            color: const Color(0xFFFF6B6B),
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: _avgCommunityScore,
            title: 'Comm\n${_avgCommunityScore.toStringAsFixed(0)}',
            color: const Color(0xFF4ECDC4),
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: _avgPBLScore,
            title: 'PBL\n${_avgPBLScore.toStringAsFixed(0)}',
            color: const Color(0xFFFFD93D),
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _performanceStatsWidget() {
    if (_filteredStudents.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    List<double> allXP =
        _filteredStudents.map((s) => s['xp'] as double).toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statItem(
            'Highest XP',
            allXP.last.toStringAsFixed(0),
            const Color(0xFF6BCB77),
          ),
          const SizedBox(height: 12),
          _statItem(
            'Lowest XP',
            allXP.first.toStringAsFixed(0),
            const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 12),
          _statItem(
            'Avg XP',
            _avgXP.toStringAsFixed(0),
            const Color(0xFF00D9FF),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.6), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsOverview(bool isMobile) {
    // if (_filteredStudents.isEmpty) return const SizedBox.shrink();

    double avgAttendance = _calculateAverage('attendance');

    List<Widget> cards = [
      _overviewCard(
        title: 'Avg XP',
        value: _avgXP.toStringAsFixed(0),
        color: const Color(0xFF00D9FF),
        icon: '⭐',
      ),
      _overviewCard(
        title: 'Total Students',
        value: _filteredStudents.length.toString(),
        color: const Color(0xFF6BCB77),
        icon: '👥',
      ),
      _overviewCard(
        title: 'Avg Attendance',
        value: '${avgAttendance.toStringAsFixed(0)}%',
        color: const Color(0xFFFF9F43),
        icon: '✓',
      ),
    ];

    // Always return a Row to display cards horizontally
    return Row(
      children: cards
          .map((c) => Expanded(child: c))
          .toList()
          .expand((element) => [element, const SizedBox(width: 12)])
          .take(cards.length * 2 - 1)
          .toList(),
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required Color color,
    required String icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _xpVsPerformance() {
    if (_filteredStudents.isEmpty) {
      return const Center(
        child: Text('No student data', style: TextStyle(color: Colors.white70)),
      );
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < _filteredStudents.length; i++) {
      double xp = (_filteredStudents[i]['xp'] as double) / 20;
      if (xp > 10) xp = 10;
      if (xp < 0) xp = 0;
      double avgScore = (_filteredStudents[i]['quiz_score'] as double);
      spots.add(FlSpot(xp, avgScore));
    }

    return ScatterChart(
      ScatterChartData(
        scatterSpots: spots
            .asMap()
            .entries
            .map((entry) => ScatterSpot(entry.value.x, entry.value.y))
            .toList(),
        showingTooltipIndicators: [],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
        ),
        minX: 0,
        maxX: 10,
        minY: 0,
        maxY: 100,
      ),
    );
  }

  Widget _buildStudentsTable() {
    if (_filteredStudents.isEmpty) {
      return const Center(
        child: Text('No student data', style: TextStyle(color: Colors.white70)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text(
              'Student',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Quiz %',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Community',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'PBL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Attend %',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'XP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        rows: _filteredStudents
            .map(
              (student) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      student['name'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(student['quiz_score'] as double).toInt()}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(student['community_score'] as double).toInt()}',
                      style: const TextStyle(
                        color: Color(0xFF4ECDC4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(student['pbl_score'] as double).toInt()}',
                      style: const TextStyle(
                        color: Color(0xFFFFD93D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(student['attendance'] as double).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFF6BCB77),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(student['xp'] as double).toInt()}',
                      style: const TextStyle(
                        color: Color(0xFFFF9F43),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
