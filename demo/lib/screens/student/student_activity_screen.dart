import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:demo/screens/student/resources/student_resources_screen.dart';
import 'package:demo/screens/student/pbl/student_pbl_selection_screen.dart';
import 'package:demo/screens/student/student_class_detail_screen.dart';

class StudentActivityScreen extends StatefulWidget {
  const StudentActivityScreen({super.key});

  @override
  State<StudentActivityScreen> createState() => _StudentActivityScreenState();
}

class _StudentActivityScreenState extends State<StudentActivityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _classSubscription;
  final Map<String, StreamSubscription<QuerySnapshot>> _postSubscriptions = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _updateSubscriptions =
      {};
  final Map<String, StreamSubscription<QuerySnapshot>>
  _announcementSubscriptions = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _resourceSubscriptions =
      {};
  final Map<String, StreamSubscription<QuerySnapshot>> _pblSubscriptions = {};

  final Map<String, _StudentAlert> _alertMap = {};
  final Map<String, String> _classNames = {};
  final Map<String, int> _miniProjectCountByClass =
      {}; // Track mini project count per class
  final Map<String, String> _assignedPblIdByClass =
      {}; // Latest assigned PBL id per class for routing mini projects

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _listenToJoinedClasses();
  }

  @override
  void dispose() {
    _classSubscription?.cancel();
    for (final sub in _postSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _updateSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _announcementSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _resourceSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _pblSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listenToJoinedClasses() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    _classSubscription = _firestore
        .collection('class_students')
        .where('studentId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) async {
          final classIds = snapshot.docs
              .map((d) => d['classId'] as String)
              .toList();

          // Clean up removed classes
          final currentIds = classIds.toSet();
          final removedPosts = _postSubscriptions.keys
              .where((id) => !currentIds.contains(id))
              .toList();
          for (final id in removedPosts) {
            _postSubscriptions.remove(id)?.cancel();
          }
          final removedUpdates = _updateSubscriptions.keys
              .where((id) => !currentIds.contains(id))
              .toList();
          for (final id in removedUpdates) {
            _updateSubscriptions.remove(id)?.cancel();
          }
          final removedAnnouncements = _announcementSubscriptions.keys
              .where((id) => !currentIds.contains(id))
              .toList();
          for (final id in removedAnnouncements) {
            _announcementSubscriptions.remove(id)?.cancel();
          }

          final removedResources = _resourceSubscriptions.keys
              .where((id) => !currentIds.contains(id))
              .toList();
          for (final id in removedResources) {
            _resourceSubscriptions.remove(id)?.cancel();
          }

          final removedPbl = _pblSubscriptions.keys
              .where((id) => !currentIds.contains(id))
              .toList();
          for (final id in removedPbl) {
            _pblSubscriptions.remove(id)?.cancel();
          }

          // Clear alerts for removed classes
          _alertMap.removeWhere(
            (key, _) => !currentIds.contains(key.split('|').first),
          );

          // Attach listeners for new classes
          for (final classId in currentIds) {
            if (!_classNames.containsKey(classId)) {
              _fetchClassName(classId);
            }
            if (!_postSubscriptions.containsKey(classId)) {
              _postSubscriptions[classId] = _firestore
                  .collection('classes')
                  .doc(classId)
                  .collection('posts')
                  .snapshots()
                  .listen(
                    (s) => _handleSnapshot(classId, 'post', s),
                    onError: (e) => print('Posts listener error: $e'),
                  );
            }
            if (!_updateSubscriptions.containsKey(classId)) {
              _updateSubscriptions[classId] = _firestore
                  .collection('classes')
                  .doc(classId)
                  .collection('updates')
                  .orderBy('created_at', descending: true)
                  .snapshots()
                  .listen((s) => _handleSnapshot(classId, 'update', s));
            }
            if (!_announcementSubscriptions.containsKey(classId)) {
              _announcementSubscriptions[classId] = _firestore
                  .collection('classes')
                  .doc(classId)
                  .collection('announcements')
                  .orderBy('created_at', descending: true)
                  .snapshots()
                  .listen((s) => _handleSnapshot(classId, 'announcement', s));
            }
            if (!_resourceSubscriptions.containsKey(classId)) {
              _resourceSubscriptions[classId] = _firestore
                  .collection('classes')
                  .doc(classId)
                  .collection('resources')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  .listen((s) => _handleSnapshot(classId, 'resource', s));
            }
            if (!_pblSubscriptions.containsKey(classId)) {
              _pblSubscriptions[classId] = _firestore
                  .collection('classes')
                  .doc(classId)
                  .collection('PBL')
                  .snapshots()
                  .listen(
                    (s) => _handleSnapshot(classId, 'pbl', s),
                    onError: (e) => print('PBL listener error: $e'),
                  );
            }
          }

          setState(() => _loading = false);
          _emitAlerts();
        });
  }

  Future<void> _fetchClassName(String classId) async {
    try {
      final doc = await _firestore.collection('classes').doc(classId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final name = (data['class_name'] ?? data['name'] ?? 'Class') as String;
        setState(() => _classNames[classId] = name);
      }
    } catch (_) {
      // ignore lookup errors
    }
  }

  void _handleSnapshot(String classId, String type, QuerySnapshot snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp =
          (data['created_at'] ?? data['createdAt'] ?? data['timestamp'])
              as Timestamp?;
      final createdAt = timestamp?.toDate() ?? DateTime.now();

      String title = (data['title'] ?? data['headline'] ?? data['type'] ?? '')
          .toString();
      String message =
          (data['description'] ??
                  data['details'] ??
                  data['content'] ??
                  data['message'] ??
                  '')
              .toString();

      // Allow overriding alert type based on content
      var effectiveType = type;

      if (type == 'resource') {
        final url = (data['url'] ?? '').toString();
        if (title.isEmpty)
          title = (data['description'] ?? 'New resource').toString();
        if (message.isEmpty) message = url;
      } else if (type == 'post') {
        // Posts typically have description as content
        if (title.isEmpty) title = 'Post';
        if (message.isEmpty)
          message =
              (data['description'] ?? data['body'] ?? data['content'] ?? '')
                  .toString();

        // Classify certain posts as assignments to keep routing empty
        final subtype = (data['type'] ?? '').toString();
        if (subtype == 'chapter_quiz' ||
            subtype == 'assignment' ||
            subtype == 'homework') {
          effectiveType = 'assignment';
        }

        // Include deadline if present
        final dlRaw = data['deadline'];
        DateTime? deadline;
        if (dlRaw is Timestamp) {
          deadline = dlRaw.toDate();
        } else if (dlRaw is String) {
          deadline = DateTime.tryParse(dlRaw);
        }
        if (deadline != null) {
          final dlText = _formatDate(deadline);
          message = message.isNotEmpty
              ? '$message • Deadline: $dlText'
              : 'Deadline: $dlText';
        }
      } else if (type == 'pbl') {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) continue; // Skip if not logged in

        // Check if current student is assigned to this PBL
        bool isAssigned = false;

        // Check studentAssignments array for student with matching uid
        final studentAssignments =
            (data['studentAssignments'] as List?) ?? const [];

        print(
          'DEBUG: Checking PBL ${doc.id}, studentAssignments count: ${studentAssignments.length}',
        );

        for (final assignment in studentAssignments) {
          if (assignment is Map<String, dynamic>) {
            final students = (assignment['students'] as List?) ?? const [];
            print('DEBUG: Assignment has ${students.length} students');
            for (final student in students) {
              if (student is Map<String, dynamic>) {
                final studentUid = student['uid'];
                print(
                  'DEBUG: Comparing student uid: $studentUid with current: $currentUserId',
                );
                if (studentUid == currentUserId) {
                  isAssigned = true;
                  break;
                }
              }
            }
            if (isAssigned) break;
          }
        }

        print('DEBUG: PBL ${doc.id} isAssigned: $isAssigned');

        // Skip if not assigned
        if (!isAssigned) {
          continue;
        }

        // Track latest assigned PBL id for this class for mini project routing
        _assignedPblIdByClass[classId] = doc.id;

        if (title.isEmpty) {
          title = (data['title'] ?? 'PBL Project').toString();
        }

        if (message.isEmpty) {
          final mp = (data['miniProjects'] as List?) ?? const [];
          final fallback = (data['problemStatement'] ?? data['overview'] ?? '')
              .toString();
          if (mp.isNotEmpty) {
            message =
                '${mp.length} mini project${mp.length == 1 ? '' : 's'} available';
          } else {
            message = fallback;
          }
        }

        // Track mini project count for this class and only alert if there ARE mini projects
        final mp = (data['miniProjects'] as List?) ?? const [];
        if (mp.isNotEmpty) {
          final currentCount = _miniProjectCountByClass[classId] ?? 0;
          if (mp.length > currentCount) {
            _miniProjectCountByClass[classId] = mp.length;
            // Add a mini projects alert for this class (only if mp exist)
            final miniProjectKey = _alertKey(classId, 'miniproject', 'all');
            if (!_alertMap.containsKey(miniProjectKey)) {
              _alertMap[miniProjectKey] = _StudentAlert(
                id: 'all',
                classId: classId,
                type: 'miniproject',
                title: 'Mini Projects Available',
                message:
                    '${mp.length} mini project${mp.length == 1 ? '' : 's'} ready to select',
                createdAt: createdAt,
              );
            }
          }
        }
      }

      if (title.isEmpty) title = 'Update';

      final key = _alertKey(classId, effectiveType, doc.id);
      _alertMap[key] = _StudentAlert(
        id: doc.id,
        classId: classId,
        type: effectiveType,
        title: title,
        message: message,
        createdAt: createdAt,
      );
    }
    _emitAlerts();
  }

  void _emitAlerts() {
    final alerts = _alertMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() => _sortedAlerts = alerts);
  }

  List<_StudentAlert> _sortedAlerts = [];

  String _alertKey(String classId, String type, String docId) =>
      '$classId|$type|$docId';

  Color _chipBg(String type) {
    switch (type) {
      case 'announcement':
        return Colors.orange.shade100;
      case 'resource':
        return Colors.green.shade100;
      case 'pbl':
        return Colors.purple.shade100;
      case 'miniproject':
        return Colors.blue.shade100;
      default:
        return Colors.blue.shade100;
    }
  }

  Color _chipFg(String type) {
    switch (type) {
      case 'announcement':
        return Colors.orange.shade900;
      case 'resource':
        return Colors.green.shade900;
      case 'pbl':
        return Colors.purple.shade900;
      case 'miniproject':
        return Colors.blue.shade900;
      default:
        return Colors.blue.shade900;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'announcement':
        return 'Announcement';
      case 'resource':
        return 'Resource';
      case 'assignment':
        return 'Assignment';
      case 'post':
        return 'Post';
      case 'update':
        return 'Post';
      case 'pbl':
        return 'PBL';
      case 'miniproject':
        return 'Mini Projects';
      default:
        return 'Post';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sortedAlerts.isEmpty) {
      return const Center(
        child: Text(
          'No alerts yet. You will see class updates and announcements here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sortedAlerts.length,
      itemBuilder: (context, index) {
        final alert = _sortedAlerts[index];
        final className = _classNames[alert.classId] ?? 'Class';

        return InkWell(
          onTap: () => _navigateToAlert(context, alert, className),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _chipBg(alert.type),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _typeLabel(alert.type),
                        style: TextStyle(
                          color: _chipFg(alert.type),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        className,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(alert.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (alert.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      alert.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToAlert(
    BuildContext context,
    _StudentAlert alert,
    String className,
  ) async {
    print('DEBUG: Navigating to alert type: ${alert.type}, id: ${alert.id}');

    switch (alert.type) {
      case 'resource':
        print('DEBUG: Navigating to Resources');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentResourcesScreen(
              classId: alert.classId,
              className: className,
            ),
          ),
        );
        break;
      case 'assignment':
        // Keep assignment routing empty for now
        print('DEBUG: Assignment routing kept empty');
        return;
      case 'post':
        print('DEBUG: Navigating to Class Detail (Post)');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentClassDetailScreen(classId: alert.classId),
          ),
        );
        break;
      case 'pbl':
        print('DEBUG: Navigating to PBL Selection');
        // Fetch full PBL data before navigating
        try {
          final pblDoc = await _firestore
              .collection('classes')
              .doc(alert.classId)
              .collection('PBL')
              .doc(alert.id)
              .get();

          if (!pblDoc.exists) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('PBL not found')));
            }
            return;
          }

          final pblData = pblDoc.data()!;
          final miniProjects =
              (pblData['miniProjects'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentPblSelectionScreen(
                  classId: alert.classId,
                  pblId: alert.id,
                  title: pblData['title'] ?? 'PBL Project',
                  problemStatement: pblData['problemStatement'] ?? '',
                  miniProjects: miniProjects,
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error loading PBL: $e')));
          }
        }
        break;
      case 'miniproject':
        print('DEBUG: Navigating to Mini Projects (Assigned PBL Selection)');
        final assignedPblId = _assignedPblIdByClass[alert.classId];
        if (assignedPblId == null) {
          print('DEBUG: No assigned PBL id found for class ${alert.classId}');
          return;
        }
        try {
          final pblDoc = await _firestore
              .collection('classes')
              .doc(alert.classId)
              .collection('PBL')
              .doc(assignedPblId)
              .get();
          if (!pblDoc.exists) return;
          final pblData = pblDoc.data()!;
          final miniProjects =
              (pblData['miniProjects'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentPblSelectionScreen(
                  classId: alert.classId,
                  pblId: assignedPblId,
                  title: pblData['title'] ?? 'PBL Project',
                  problemStatement: pblData['problemStatement'] ?? '',
                  miniProjects: miniProjects,
                ),
              ),
            );
          }
        } catch (_) {
          // swallow navigation errors
        }
        break;
      case 'announcement':
      case 'update':
      default:
        print('DEBUG: Navigating to Class Detail (default)');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentClassDetailScreen(classId: alert.classId),
          ),
        );
        break;
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDate(DateTime dt) {
    // Simple date format: Jan 31, 2026 12:00 AM
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m $day, $year $hour:$minute $ampm';
  }
}

class _StudentAlert {
  final String id;
  final String classId;
  final String type; // 'update' or 'announcement'
  final String title;
  final String message;
  final DateTime createdAt;

  _StudentAlert({
    required this.id,
    required this.classId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
  });
}
