import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'practice_quiz_loader_screen.dart';
import '../../config/feature_flags.dart';
import '../../services/ame_api_service.dart';

class PracticeConceptListScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String studentName;

  const PracticeConceptListScreen({
    super.key,
    required this.classId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<PracticeConceptListScreen> createState() =>
      _PracticeConceptListScreenState();
}

class _PracticeConceptListScreenState extends State<PracticeConceptListScreen> {
  final AmeApiService _ameApiService = AmeApiService.instance;
  String? _ameFocusConcept;
  String? _ameRecommendedAction;

  @override
  void initState() {
    super.initState();
    if (FeatureFlags.ameEnabled) {
      _fetchAmeFocusRecommendation();
    }
  }

  Future<void> _fetchAmeFocusRecommendation() async {
    final response = await _ameApiService.getFocus(
      studentId: widget.studentId,
      classId: widget.classId,
    );

    if (!mounted || response == null) {
      return;
    }

    final focusConcept = response['focus_concept'];
    final recommendedAction = response['recommended_action'];

    if (focusConcept is String &&
        focusConcept.trim().isNotEmpty &&
        recommendedAction is String &&
        recommendedAction.trim().isNotEmpty) {
      debugPrint(
        '[AME] Using focus concept ${focusConcept.trim()} with action ${recommendedAction.trim()}',
      );
      setState(() {
        _ameFocusConcept = focusConcept.trim();
        _ameRecommendedAction = recommendedAction.trim();
      });
      return;
    }

    debugPrint(
      '[AME] Invalid focus payload. Falling back to weakConcept path.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        title: const Text(
          "Practice Weak Concepts",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quiz_attempts')
            .where('classId', isEqualTo: widget.classId)
            .where('studentId', isEqualTo: widget.studentId)
            .where('quizType', isEqualTo: 'chapter')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final Set<String> weakConcepts = {};
          final Map<String, Map<String, dynamic>> masteryByConcept = {};

          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            // 1️⃣ Collect weak concepts
            final List<String> wc = List<String>.from(
              data['weakConcepts'] ?? [],
            );
            weakConcepts.addAll(wc);

            // 2️⃣ Collect mastery SAFELY per concept
            final Map<String, dynamic> mastery = Map<String, dynamic>.from(
              data['conceptMastery'] ?? {},
            );

            mastery.forEach((concept, masteryData) {
              masteryByConcept[concept] = Map<String, dynamic>.from(
                masteryData,
              );
            });
          }

          final focusConcept = _ameFocusConcept;
          if (focusConcept != null) {
            weakConcepts.add(focusConcept);
          }

          final weakConceptList = weakConcepts.toList();

          if (focusConcept != null && weakConceptList.contains(focusConcept)) {
            weakConceptList.remove(focusConcept);
            weakConceptList.insert(0, focusConcept);
          }

          if (weakConceptList.isEmpty) {
            if (snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No quiz attempts found"));
            }
            return const Center(child: Text("No weak concepts 🎉"));
          }

          final showAmeRecommendation =
              FeatureFlags.ameEnabled &&
              focusConcept != null &&
              _ameRecommendedAction != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (showAmeRecommendation)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2E52),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AME Recommendation',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Focus: ${_ameFocusConcept!}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Action: ${_ameRecommendedAction!}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ...weakConceptList.map((concept) {
                final mastery = masteryByConcept[concept];

                final bool validated =
                    mastery != null && mastery['validated'] == true;

                final int score = mastery != null
                    ? mastery['individualMasteryScore'] ?? 0
                    : 0;

                return Card(
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(
                      concept,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          validated
                              ? "Mastered ($score%)"
                              : "Needs Practice ($score%)",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                        if (showAmeRecommendation && concept == focusConcept)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Recommended action: ${_ameRecommendedAction!}',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: score / 100,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                            validated
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(
                      validated ? Icons.check_circle : Icons.play_circle_fill,
                      color: validated ? Colors.greenAccent : Colors.cyanAccent,
                    ),
                    onTap: () {
                      if (validated && score >= 80) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Concept already mastered 🎉"),
                          ),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PracticeQuizLoaderScreen(
                            classId: widget.classId,
                            studentId: widget.studentId,
                            studentName: widget.studentName,
                            conceptName: concept,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
