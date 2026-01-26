import 'package:flutter/material.dart';
import 'community/questions_list_screen.dart';
import 'community/ask_question_screen.dart';
import 'package:demo/screens/student/community/leaderboard_screen.dart';

class StudentCommunityPage extends StatelessWidget {
  const StudentCommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const Text(
            //   "🌍 Community",
            //   style: TextStyle(
            //     fontSize: 26,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.white,
            //   ),
            // ),
            const SizedBox(height: 8),

            const Text(
              "Discussion, doubts, and announcements.",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 30),

            // 🏆 Leaderboard Button
            _card(
              icon: Icons.leaderboard,
              title: "Leaderboard",
              subtitle: "View student rankings & stats",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            // ✅ ASK QUESTION (old /ask-question)
            _card(
              icon: Icons.edit,
              title: "Ask a Question",
              subtitle: "Post your doubt to the community",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AskQuestionScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            // ✅ VIEW QUESTIONS (old /questions)
            _card(
              icon: Icons.forum,
              title: "All Questions",
              subtitle: "Browse community discussions",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QuestionsListScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ✅ EXAMPLE DETAIL NAV (old /question-detail)
            // _card(
            //   icon: Icons.question_answer,
            //   title: "Open Sample Question",
            //   subtitle: "Navigate to a question detail",
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) =>
            //             QuestionDetailScreen(questionId: "sample_id"),
            //       ),
            //     );
            //   },
            // ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}
