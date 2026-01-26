import 'package:demo/screens/student/community/questions_list_screen.dart';
import 'package:demo/screens/student/student_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:demo/services/auth_service.dart';
import 'package:demo/services/class_service.dart';
import 'student/student_community_screen.dart';
import 'student/student_class_screen.dart';
import 'package:demo/screens/home_screen.dart';
import 'package:demo/screens/student/pbl/student_pbl_screen.dart';
import 'package:demo/screens/student/student_settings_screen.dart';
import 'package:demo/main.dart'; // for AuthWrapper

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _currentIndex = 0;

  final AuthService _auth = AuthService();
  final ClassService _classService = ClassService();

  // Pages for bottom navigation
  final List<Widget> _pages = const [
    StudentActivityScreen(),
    // StudentPblScreen(),
    StudentClassesPage(),
    QuestionsListScreen(),
    StudentSettingsScreen(),
  ];

  // Dynamic AppBar title
  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return "📊 Class Activity";
      // case 1:
      //   return "PBL";
      case 1:
        return "🏫 My Classes";
      case 2:
        return "🌍 Community";
      case 3:
        return "⚙️ Settings";
      default:
        return "Student";
    }
  }

  // ================= JOIN CLASS =================

  Future<void> _joinClassByCode(String code) async {
    try {
      await _classService.joinClassByCode(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Joined class successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showJoinClassDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Join Class"),
          content: TextField(
            controller: codeController,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: "Enter 6-digit class code",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.length != 6) return;

                Navigator.pop(context);
                await _joinClassByCode(code);
              },
              child: const Text("Join"),
            ),
          ],
        );
      },
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),

      // 🔹 APP BAR
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _getTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight
                .w600, // Optional: adds boldness for better visibility
          ),
        ),
        backgroundColor: const Color(0xFF0F1C3F),
        actions: [
          // 👇 3-dot menu only on "My Classes"
          if (_currentIndex == 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'join') {
                  _showJoinClassDialog();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'join', child: Text('Join Class')),
              ],
            ),

          // 👇 Logout only in Settings tab
          if (_currentIndex == 3)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _auth.signOut();

                if (!mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              },
            ),
        ],
      ),

      // 🔹 BODY
      body: _pages[_currentIndex],

      // 🔹 BOTTOM NAV BAR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0F1C3F),
        selectedItemColor: const Color(0xFF00D9FF),
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_rounded),
            label: "Activity",
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.class_rounded),
          //   label: "PBL",
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_rounded),
            label: "Classes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_rounded),
            label: "Community",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   ======================= PAGES ===============================
   ============================================================ */

class _StudentActivityPage extends StatelessWidget {
  const _StudentActivityPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "📊 Recent Activity\n\nAssignments, tests, announcements will appear here.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }
}
