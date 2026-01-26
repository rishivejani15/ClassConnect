import 'package:flutter/material.dart';
import 'package:demo/services/firestore_service.dart';
import 'package:demo/services/moderation_service.dart';
import 'package:demo/models/tag.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customTagController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final ModerationService _moderationService = ModerationService();
  bool _isSubmitting = false;
  final List<Tag> _selectedTags = [];
  final List<Tag> _customTags = [];

  // Available tags
  final List<Tag> _availableTags = [
    Tag(id: 't1', name: 'Flutter', color: '#42A5F5'),
    Tag(id: 't2', name: 'Dart', color: '#AB47BC'),
    Tag(id: 't3', name: 'UI/UX', color: '#66BB6A'),
    Tag(id: 't4', name: 'Database', color: '#FFA726'),
    Tag(id: 't5', name: 'API', color: '#EC407A'),
    Tag(id: 't6', name: 'State Management', color: '#AB47BC'),
    Tag(id: 't7', name: 'Performance', color: '#FFCA28'),
  ];

  late final String _currentUserId;
  String _userName = 'Student';
  String _userAvatar = '👤';

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await _firestoreService.getUserData(_currentUserId);
    if (userData != null && mounted) {
      setState(() {
        _userName = userData['name'] ?? 'Student';
        _userAvatar = userData['photoUrl'] ?? '👤';
      });
    }
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one tag')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Moderate the question first
    final moderationError = await _moderationService.moderateQuestion(
      title: _titleController.text,
      description: _descriptionController.text,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (moderationError != null) {
      // Content was rejected
      if (mounted) {
        _showModerationDialog('Question Not Allowed', moderationError);
      }
      return;
    }

    // Content approved, post the question
    try {
      await _firestoreService.addQuestion(
        userId: _currentUserId,
        userName: _userName,
        userAvatar: _userAvatar,
        title: _titleController.text,
        description: _descriptionController.text,
        tags: _selectedTags,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question posted successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error posting question: $e')));
      }
    }
  }

  void _showModerationDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addCustomTag() {
    final tagName = _customTagController.text.trim();
    if (tagName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a tag name')));
      return;
    }

    // Check if tag already exists
    final allTags = [..._availableTags, ..._customTags];
    if (allTags.any((t) => t.name.toLowerCase() == tagName.toLowerCase())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tag already exists')));
      return;
    }

    // Generate random color for custom tag
    final colors = [
      '#42A5F5',
      '#AB47BC',
      '#66BB6A',
      '#FFA726',
      '#EC407A',
      '#FFCA28',
      '#26C6DA',
    ];
    final color = colors[_customTags.length % colors.length];

    setState(() {
      final customTag = Tag(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: tagName,
        color: color,
      );
      _customTags.add(customTag);
      _selectedTags.add(customTag);
      _customTagController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Tag "$tagName" added')));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ask a Question',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F1C3F),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ), // Modern rounded back icon
          color: Colors.white, // Matching your Cyan accent
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field
                Text(
                  'Question Title',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  maxLines: 2,
                  minLines: 1,
                  maxLength: 200,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What is your question?',
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a question title';
                    }
                    if (value.trim().length < 10) {
                      return 'Title must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description field
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 8,
                  minLines: 4,
                  maxLength: 2000,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                        'Provide details about your question. Include relevant code snippets if applicable.',
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    if (value.trim().length < 20) {
                      return 'Description must be at least 20 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Tags selection
                Text(
                  'Tags (Select at least one)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Predefined tags
                Text(
                  'Predefined Tags:',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTags.map((tag) {
                    final isSelected = _selectedTags.any((t) => t.id == tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.removeWhere((t) => t.id == tag.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Custom tag input
                Text(
                  'Add Custom Tag:',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customTagController,
                        maxLength: 20,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter custom tag name',
                          hintStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _addCustomTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addCustomTag,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Custom tags display
                if (_customTags.isNotEmpty) ...[
                  Text(
                    'Your Custom Tags:',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _customTags.map((tag) {
                      final isSelected = _selectedTags.any(
                        (t) => t.id == tag.id,
                      );
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.removeWhere((t) => t.id == tag.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                // Selected tags display
                if (_selectedTags.isNotEmpty) ...[
                  Text(
                    'Selected Tags:',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _selectedTags.map((tag) {
                      return Chip(
                        label: Text(tag.name),
                        onDeleted: () {
                          setState(() {
                            _selectedTags.removeWhere((t) => t.id == tag.id);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitQuestion,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'Posting...' : 'Post Question'),
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
