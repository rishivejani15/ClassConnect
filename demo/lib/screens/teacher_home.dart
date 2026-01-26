import 'package:flutter/material.dart';
import 'package:demo/services/auth_service.dart';
import 'teacher/teacher_dashboard_screen.dart';
import 'teacher/teacher_classes_screen.dart';
import 'teacher/teacher_settings_screen.dart';
import 'teacher/create_class_screen.dart';
import 'teacher_tasks/screens/teacher_task_screen.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _currentIndex = 0;
  final AuthService _auth = AuthService();

  // Updated pages to match your new Nav Bar order
  final List<Widget> _pages = const [
    TeacherDashboardPage(), // 0

    TeacherTaskScreen(), // 1 → Workload

    TeacherClassesPage(), // 2 → Classes

    TeacherSettingsScreen(), // 3
  ];

  AppBar _buildAppBar() {
    // Theme constants
    const appBarBgColor = Color(0xFF0F1C3F);
    const accentColor = Color(0xFF00D9FF);

    switch (_currentIndex) {
      // ================= ACTIVITY (Dashboard) =================
      case 0:
        return AppBar(
          backgroundColor: appBarBgColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.dashboard_rounded, color: accentColor),
              SizedBox(width: 8),
              Text("Dashboard", style: TextStyle(color: Colors.white)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async => await _auth.signOut(),
            ),
          ],
        );

      // ================= Workload =================
      case 1:
        return AppBar(
          backgroundColor: const Color( 0xFF0F1C3F),
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.work_outline_rounded, color: accentColor),
              SizedBox(width: 8),
              Text("Workload", style: TextStyle(color: Colors.white)),
            ],
          ),
        );

      // ================= Class =================
      case 2:
        return AppBar(
          backgroundColor: appBarBgColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.class_rounded, color: accentColor),
              SizedBox(width: 8),
              Text("Classes", style: TextStyle(color: Colors.white)),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'Create Class')
                  _navigateToCreateClassPage(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'Create Class',
                  child: Text('Create Class'),
                ),
              ],
            ),
          ],
        );

      // ================= SETTINGS =================
      case 3:
        return AppBar(
          backgroundColor: appBarBgColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.settings_rounded, color: accentColor),
              SizedBox(width: 8),
              Text("Settings", style: TextStyle(color: Colors.white)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _auth.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        );

      default:
        return AppBar(
          backgroundColor: appBarBgColor,
          title: const Text("Teacher"),
        );
    }
  }

  void _navigateToCreateClassPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateClassPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _pages[_currentIndex],
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
            icon: Icon(Icons.dashboard_rounded),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: "Workload",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_rounded),
            label: "Classes",
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
