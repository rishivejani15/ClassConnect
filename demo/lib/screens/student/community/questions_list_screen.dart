import 'package:demo/screens/student/community/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:demo/services/firestore_service.dart';
import 'package:demo/models/question.dart';
import 'package:demo/models/reaction.dart';
import 'package:demo/widgets/question_card.dart';
import 'package:demo/widgets/common_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'question_detail_screen.dart';
import 'ask_question_screen.dart';

class QuestionsListScreen extends StatefulWidget {
  const QuestionsListScreen({super.key});

  @override
  State<QuestionsListScreen> createState() => _QuestionsListScreenState();
}

class _QuestionsListScreenState extends State<QuestionsListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  late final String _currentUserId;
  List<Question>? _searchResults;

  void _searchQuestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
      });
    } else {
      final results = await _firestoreService.searchQuestions(query);
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _onQuestionReaction(Question question, ReactionType type) {
    final hasReaction = question.reactions.any(
      (r) => r.userId == _currentUserId && r.type == type,
    );

    if (hasReaction) {
      _firestoreService.removeReactionFromQuestion(
        question.id,
        _currentUserId,
        type,
      );
    } else {
      _firestoreService.addReactionToQuestion(
        question.id,
        _currentUserId,
        type,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Questions', style: TextStyle(color: Colors.white)),
      //   backgroundColor: const Color(0xFF0F1C3F),
      //   elevation: 0,
      //   centerTitle: true,
      //   leading: IconButton(
      //     icon: const Icon(
      //       Icons.arrow_back_ios_new_rounded,
      //     ), // Modern rounded back icon
      //     color: Colors.white, // Matching your Cyan accent
      //     onPressed: () {
      //       if (Navigator.canPop(context)) {
      //         Navigator.pop(context);
      //       }
      //     },
      //   ),
      // ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
  controller: _searchController,
  onChanged: _searchQuestions,
  backgroundColor: MaterialStateProperty.all(
    const Color(0xFF1E1E1E),
  ),
  surfaceTintColor: MaterialStateProperty.all(
    const Color(0xFF1E1E1E),
  ),
  shadowColor: MaterialStateProperty.all(Colors.transparent),
  leading: const Icon(Icons.search, color: Colors.white70),
  hintText: 'Search questions...',
  hintStyle: MaterialStateProperty.all(
    const TextStyle(color: Colors.white54),
  ),
  textStyle: MaterialStateProperty.all(
    const TextStyle(color: Colors.white),
  ),
  trailing: [
    if (_searchController.text.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.white70),
        onPressed: () {
          _searchController.clear();
          _searchQuestions('');
        },
      ),
  ],
),

          ),

          // Questions list
          Expanded(
            child: _searchResults != null
                ? _buildQuestionsList(_searchResults!)
                : StreamBuilder<List<Question>>(
                    stream: _firestoreService.getQuestionsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return EmptyStateWidget(
                          title: 'Error',
                          message:
                              'Failed to load questions: ${snapshot.error}',
                          icon: Icons.error_outline,
                        );
                      }

                      final questions = snapshot.data ?? [];
                      return _buildQuestionsList(questions);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'leaderboardFab',
            backgroundColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
            tooltip: 'Leaderboard',
            child: const Icon(Icons.leaderboard, color: Colors.black),
          ),

          const SizedBox(height: 12),

          FloatingActionButton(
            heroTag: 'askQuestionFab',
            backgroundColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AskQuestionScreen()),
              );
            },
            tooltip: 'Ask a question',
            child: const Icon(Icons.add, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(List<Question> questions) {
    if (questions.isEmpty) {
      return EmptyStateWidget(
        title: 'No Questions',
        message: _searchController.text.isEmpty
            ? 'No questions yet. Be the first to ask!'
            : 'No questions match your search.',
        icon: Icons.help_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return QuestionCard(
          question: question,
          onTap: () {
            _firestoreService.incrementQuestionViews(question.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuestionDetailScreen(questionId: question.id),
              ),
            );
          },
          currentUserId: _currentUserId,
          onReaction: (type) => _onQuestionReaction(question, type),
        );
      },
    );
  }
}
