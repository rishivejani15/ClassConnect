import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_detail_screen.dart';
import '../pbl/screens/upload_syllabus_screen.dart';

class QuizTabScreen extends StatelessWidget {
  final String classId;

  const QuizTabScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F), // Deep Blue Background
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .collection('chapters')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final chapters = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final chapterDoc = chapters[index];
              return _ChapterCard(
                classId: classId,
                chapterDoc: chapterDoc,
                index: index,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.book_outlined,
              size: 64,
              color: Colors.indigo.shade200,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No chapters found",
            style: TextStyle(
              color: Colors.indigo.shade100,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Upload a syllabus to automatically generate chapters.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: const Color(0xFF0F1C3F),
                    appBar: AppBar(
                      title: const Text("Upload Syllabus"),
                      backgroundColor: const Color(0xFF0F1C3F),
                      elevation: 0,
                    ),
                    body: UploadSyllabusScreen(classId: classId),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.upload_file, color: Colors.black),
            label: const Text(
              "Upload Syllabus",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: Colors.cyanAccent.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String classId;
  final QueryDocumentSnapshot chapterDoc;
  final int index;

  const _ChapterCard({
    required this.classId,
    required this.chapterDoc,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final data = chapterDoc.data() as Map<String, dynamic>;
    final String chapterName = data['title'] ?? data['name'] ?? 'Chapter';
    final int order = data['order'] ?? index + 1;
    final List<String> concepts = List<String>.from(data['concepts'] ?? []);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('quizzes')
          .doc(chapterDoc.id)
          .snapshots(),
      builder: (context, quizSnap) {
        bool isCompleted = false;

        if (quizSnap.hasData && quizSnap.data!.exists) {
          final quizData = quizSnap.data!.data() as Map<String, dynamic>;
          isCompleted = quizData['status'] == 'published';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF152349), // Slightly lighter than bg
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? Colors.green.withOpacity(0.3)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor:
                  Colors.transparent, // Remove expansion tile dividers
            ),
            child: ExpansionTile(
              iconColor: Colors.cyanAccent,
              collapsedIconColor: Colors.white54,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? Colors.greenAccent : Colors.white38,
                  size: 20,
                ),
              ),
              title: Text(
                "Chapter $order",
                style: TextStyle(
                  color: Colors.cyanAccent.shade100,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  chapterName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing: isCompleted
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                        ),
                      ),
                      child: const Text(
                        "Published",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  : null, // Let default icon show if not completed
              children: [
                Divider(color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 12),

                // Concepts List
                if (concepts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.white.withOpacity(0.4),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "No concepts added yet",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...concepts.map(
                    (concept) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade200,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              concept,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizDetailScreen(
                            classId: classId,
                            conceptId: chapterDoc.id,
                            conceptName: chapterName,
                            order: order,
                            chapterConcepts: concepts,
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      isCompleted
                          ? Icons.visibility_rounded
                          : Icons.edit_note_rounded,
                      size: 18,
                      color: isCompleted ? Colors.black : Colors.cyanAccent,
                    ),
                    label: Text(
                      isCompleted ? "View Published Quiz" : "Manage Quiz",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.black : Colors.cyanAccent,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted
                          ? Colors.greenAccent
                          : Colors.transparent,
                      foregroundColor: isCompleted
                          ? Colors.black
                          : Colors.cyanAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: isCompleted
                          ? null
                          : const BorderSide(color: Colors.cyanAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isCompleted ? 2 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
