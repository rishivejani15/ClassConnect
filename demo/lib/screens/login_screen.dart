import 'package:demo/screens/parent_details_screen.dart';
import 'package:demo/screens/teacher_details_screen.dart';
import 'package:demo/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'student_home.dart';
import 'teacher_home.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  // Color Palette
  static const Color primaryDark = Color(0xFF0F1C3F);
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color studentColor = Color(0xFF6366F1);
  static const Color teacherColor = Color(0xFF8B5CF6);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1C3F), Color(0xFF0F1C3F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Logo and Title Section
                  _buildHeader(),

                  const SizedBox(height: 48),

                  // Main Login Card
                  _buildLoginCard(context),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icons/logo.png',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        ),

        const SizedBox(width: 16),

        Expanded(
          // 🔑 prevents overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Welcome Back",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26, // ⬅️ decreased from 32
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                "Login to continue with AMEP",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14, // ⬅️ decreased from 16
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20), // ⬅️ reduced
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Access Section
            // Student Login Button
            _buildRoleButton(
              context: context,
              role: 'student',
              icon: Icons.school_rounded,
              label: "Continue as Student",
              color: studentColor,
              onPressed: () async {
                print("🔵 Student Google Login button clicked");

                final user = await _auth.signInWithGoogle(role: 'student');

                if (!context.mounted || user == null) {
                  print("❌ Student Google login failed");
                  return;
                }

                print("✅ Student logged in: ${user.email}");

                final hasParentDetails = await _auth.isParentDetailsFilled(
                  user.uid,
                );
                print("🧪 Parent details filled? $hasParentDetails");

                if (!context.mounted) return;

                if (hasParentDetails) {
                  // ✅ Parent details already present
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => StudentHome()),
                  );
                } else {
                  // ❌ Parent details missing → go to form
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentDetailsScreen(uid: user.uid),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 12),

            _buildRoleButton(
              context: context,
              role: 'teacher',
              icon: Icons.person_outline_rounded,
              label: "Continue as Teacher",
              color: teacherColor,
              onPressed: () async {
                print("🟣 Teacher Google Login button clicked");

                final user = await _auth.signInWithGoogle(role: 'teacher');

                if (!context.mounted || user == null) {
                  print("❌ Teacher Google login failed");
                  return;
                }

                print("✅ Teacher logged in: ${user.email}");

                final hasTeacherDetails = await _auth.isTeacherDetailsFilled(
                  user.uid,
                );
                print("🧪 Teacher details filled? $hasTeacherDetails");

                if (!context.mounted) return;

                if (hasTeacherDetails) {
                  // ✅ Teacher details already present
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => TeacherHome()),
                  );
                } else {
                  // ❌ Teacher details missing → go to form
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherDetailsScreen(uid: user.uid),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "OR",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 13, // ⬅️ reduced
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
              ],
            ),

            const SizedBox(height: 16),

            _inputField(
              controller: emailController,
              label: "Email",
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 12),

            _inputField(
              controller: passwordController,
              label: "Password",
              icon: Icons.lock_outline_rounded,
              obscure: true,
            ),

            const SizedBox(height: 18),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: 48, // ⬅️ reduced
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final user = await _auth.signInWithEmail(
                    emailController.text.trim(),
                    passwordController.text.trim(),
                  );
                },
                child: const Text(
                  "Login",
                  style: TextStyle(
                    fontSize: 16, // ⬅️ reduced
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: RichText(
                  text: TextSpan(
                    text: "New user? ",
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    children: [
                      TextSpan(
                        text: "Create an account",
                        style: TextStyle(
                          color: accentBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required String role,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),

                const SizedBox(width: 16),

                // Text
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Google Icon
                Image.asset('assets/icons/google_icon.png', height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: label == "Email" ? TextInputType.emailAddress : null,
        style: TextStyle(fontSize: 16, color: primaryDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
          prefixIcon: Icon(icon, color: accentBlue, size: 22),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accentBlue, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}
