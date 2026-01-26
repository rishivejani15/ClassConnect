import 'package:demo/services/class_automation_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_home.dart';

class ParentDetailsScreen extends StatefulWidget {
  final String uid;

  const ParentDetailsScreen({required this.uid});

  @override
  State<ParentDetailsScreen> createState() => _ParentDetailsScreenState();
}

class _ParentDetailsScreenState extends State<ParentDetailsScreen> {
  final TextEditingController parentEmailController = TextEditingController();
  final TextEditingController parentPhoneController = TextEditingController();
  final TextEditingController rollNoController = TextEditingController();
  final TextEditingController semController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController collegeSchoolController = TextEditingController();
  bool _isLoading = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    parentEmailController.dispose();
    parentPhoneController.dispose();
    rollNoController.dispose();
    semController.dispose();
    classController.dispose();
    departmentController.dispose();
    collegeSchoolController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
      filled: true,
      fillColor: const Color(0xFF1E2E52),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          "Complete Your Profile",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Parent & Student Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please provide your parent contact details and student information to continue',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Parent Information Section
            Text(
              'Parent Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Parent Email
            TextField(
              controller: parentEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                'Parent Email',
                Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // Parent Phone
            TextField(
              controller: parentPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                'Parent Phone Number',
                Icons.phone_outlined,
              ),
            ),

            const SizedBox(height: 32),

            // Student Information Section
            Text(
              'Student Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Roll Number
            TextField(
              controller: rollNoController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                'Student Roll Number',
                Icons.badge_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // Semester
            TextField(
              controller: semController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                'Semester (-1 for School)',
                Icons.school_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // Class / Division
            TextField(
              controller: classController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                'Class / Division',
                Icons.class_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // Department
            TextField(
              controller: departmentController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                'Department Name',
                Icons.business_center_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // College / School Name
            TextField(
              controller: collegeSchoolController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                'College / School Name',
                Icons.account_balance_outlined,
              ),
            ),

            const SizedBox(height: 40),

            // Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleContinue,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                label: Text(
                  _isLoading ? 'Saving...' : 'Continue',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF3B82F6).withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    // ✅ Empty field validation
    if (parentEmailController.text.trim().isEmpty ||
        parentPhoneController.text.trim().isEmpty ||
        rollNoController.text.trim().isEmpty ||
        semController.text.trim().isEmpty ||
        classController.text.trim().isEmpty ||
        departmentController.text.trim().isEmpty ||
        collegeSchoolController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all fields"),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // ✅ Safe semester parsing
    final sem = int.tryParse(semController.text.trim());

    if (sem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Enter a valid semester"),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔁 Original logic preserved
      final String studentType = sem == -1 ? 'school' : 'college';

      await _db.collection('students').doc(widget.uid).update({
        // student academic (one-time)
        'studentRollNo': rollNoController.text.trim(),
        'studentSem': sem,
        'studentType': studentType,
        'studentClass': classController.text.trim(),
        'studentDepartment': departmentController.text.trim(),
        'collegeSchoolName': collegeSchoolController.text.trim(),

        // parent
        'parentEmail': parentEmailController.text.trim(),
        'parentPhoneNumber': parentPhoneController.text.trim(),
      });

      if (!mounted) return;
      await ClassAutomationService().autoEnrollNewStudent(
        studentId: widget.uid,
        studentSem: sem,
        studentDiv: classController.text.trim(),
        collegeSchoolName: collegeSchoolController.text.trim(),
        studentType: studentType,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => StudentHome()),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}
