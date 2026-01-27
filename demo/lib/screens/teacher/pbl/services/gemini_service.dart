import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import '../models/pbl_project.dart';

class GeminiService {
  static const String apiKey = 'GeminiService_API_KEY';

  static final _conceptModel = GenerativeModel(
    model: 'gemini-2.5-flash-lite',
    apiKey: apiKey,
  );

  static final _pblModel = GenerativeModel(
    model: 'gemini-2.5-flash-lite',
    apiKey: apiKey,
  );

  /// STEP 1: Extract main concepts (Legacy - keeping for fallback if needed, or remove if unused)
  static Future<List<String>> extractConcepts(String syllabusText) async {
    final prompt =
        r'''
You are an expert teacher.

From the syllabus text below, extract ONLY the main academic concepts.
Return STRICT JSON in this format:
{
  "concepts": ["Concept 1", "Concept 2"]
}

Syllabus:
''' +
        syllabusText;

    final response = await _conceptModel.generateContent([
      Content.text(prompt),
    ]);

    try {
      final Map<String, dynamic> json = jsonDecode(
        _clean(response.text ?? '{}'),
      );
      final list = json['concepts'] ?? [];
      return (list as List).map((item) => _toStringValue(item)).toList();
    } catch (e) {
      debugPrint('Concept extraction error: $e');
      return [];
    }
  }

  /// STEP 1 (New): Extract Chapters and Concepts
  static Future<Map<String, List<String>>> extractChaptersAndConcepts(
    String syllabusText,
  ) async {
    final prompt =
        r'''
You are an expert curriculum designer.

From the syllabus text below, extract the Chapter Names and all the specific academic concepts for each chapter.
Return STRICT JSON in this format:
{
  "chapters": [
    {
      "name": "Chapter 1 Title",
      "concepts": ["Concept 1", "Concept 2", "Concept 3"]
    },
    {
      "name": "Chapter 2 Title",
      "concepts": ["Concept A", "Concept B"]
    }
  ]
}

Syllabus:
''' +
        syllabusText;

    final response = await _conceptModel.generateContent([
      Content.text(prompt),
    ]);

    try {
      final Map<String, dynamic> json = jsonDecode(
        _clean(response.text ?? '{}'),
      );
      final List<dynamic> chapters = json['chapters'] ?? [];

      final Map<String, List<String>> result = {};

      for (var chapter in chapters) {
        if (chapter is Map) {
          final String name = _toStringValue(chapter['name']);
          final List<dynamic> conceptsJson = chapter['concepts'] ?? [];
          final List<String> concepts = conceptsJson
              .map((c) => _toStringValue(c))
              .toList();
          if (name.isNotEmpty && concepts.isNotEmpty) {
            result[name] = concepts;
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('Syllabus extraction error: $e');
      return {};
    }
  }

  /// STEP 2: Generate Problem Scenarios (Options)
  static Future<List<Map<String, dynamic>>> generateProjectScenarios(
    List<String> concepts,
  ) async {
    final prompt =
        r'''
    You are an expert PBL (Project-Based Learning) designer.
    
    The teacher wants to teach the following concepts:
    ''' +
        concepts.join(', ') +
        r'''

    Generate 3 DISTINCT, ENGAGING problem scenarios that would require students to learn and apply these concepts to solve.
    Encourage a MULTIDISCIPLINARY approach (connecting with Technology).
    
    For each scenario, provide:
    1. A catchy Title.
    2. A compelling Problem Statement (The Driving Question).
    3. A brief explanation of how it triggers learning of the concepts.
    4. 10 Mini Project Titles and brief descriptions related to this problem scenario that students can choose.

    Return STRICT JSON in this format:
    {
      "scenarios": [
        {
          "title": "...",
          "problemStatement": "...",
          "educationalValue": "...",
          "miniProjects": [
            {"title": "Mini Project 1", "description": "Brief description..."},
            ... (10 items)
          ]
        }
      ]
    }
    ''';

    final response = await _pblModel.generateContent([Content.text(prompt)]);

    try {
      final Map<String, dynamic> json = jsonDecode(
        _clean(response.text ?? '{}'),
      );
      final List<dynamic> list = json['scenarios'] ?? [];
      return list.map((e) {
        if (e is Map) {
          // Parse basic string fields
          final map = <String, dynamic>{
            'title': _toStringValue(e['title']),
            'problemStatement': _toStringValue(e['problemStatement']),
            'educationalValue': _toStringValue(e['educationalValue']),
          };

          // Parse miniProjects
          final miniList = e['miniProjects'];
          if (miniList is List) {
            map['miniProjects'] = miniList.map((m) {
              if (m is Map) {
                return <String, String>{
                  'title': _toStringValue(m['title']),
                  'description': _toStringValue(m['description']),
                };
              }
              return <String, String>{};
            }).toList();
          } else {
            map['miniProjects'] = <Map<String, String>>[];
          }

          return map;
        }
        return <String, dynamic>{};
      }).toList();
    } catch (e) {
      debugPrint('Scenario generation error: $e');
      return [];
    }
  }

  /// STEP 3: Generate full PBL Project from selected scenario
  static Future<PblProject> generateProjectDetails(
    String title,
    String problemStatement,
    List<String> concepts,
  ) async {
    final prompt =
        r'''
    Create a complete, detailed Project-Based Learning (PBL) plan.

    Title: ''' +
        title +
        r'''
    Problem Statement: ''' +
        problemStatement +
        r'''
    Core Concepts: ''' +
        concepts.join(', ') +
        r'''

    Requirements:
    1. Objectives: clearly stated learning goals.
    2. Milestones: sequential steps for the project lifecycle.
    3. Rubric: must be MULTIDISCIPLINARY and MEASURABLE.
       - Include specific criteria for 'Collaboration', 'Communication', and 'Critical Thinking'.
       - For each criterion, provide a brief descriptor of what 'Exemplary' performance looks like.
    4. Mini Projects: Generate 10 DISTINCT mini-project titles with small descriptions related to this PBL.
       - These should be smaller tasks that students can choose from to demonstrate understanding.
    
    Return STRICT JSON ONLY:
    {
      "learningObjectives": ["Objective 1", "Objective 2"],
      "milestones": ["Milestone 1", "Milestone 2"],
      "rubric": [
        {
          "criteria": "Collaboration", 
          "weight": 20, 
          "descriptor": "Student actively facilitates group consensus and values all contributions."
        }
      ],
      "miniProjects": [
        {
          "title": "Mini Project 1",
          "description": "Description of mini project 1"
        }
      ]
    }
    ''';

    final response = await _pblModel.generateContent([Content.text(prompt)]);

    final Map<String, dynamic> json = jsonDecode(_clean(response.text ?? '{}'));

    // Safely parse learning objectives and milestones to strings
    final learningObjectives = (json['learningObjectives'] ?? [])
        .map((e) => _toStringValue(e))
        .toList()
        .cast<String>();

    final milestones = (json['milestones'] ?? [])
        .map((e) => _toStringValue(e))
        .toList()
        .cast<String>();

    // Safely parse rubric entries into maps
    final List<Map<String, dynamic>> rubricList = [];
    if (json['rubric'] is List) {
      for (final item in json['rubric']) {
        if (item is Map) {
          rubricList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Safely parse mini projects
    final List<Map<String, String>> miniProjectsList = [];
    if (json['miniProjects'] is List) {
      for (final item in json['miniProjects']) {
        if (item is Map) {
          miniProjectsList.add(
            Map<String, String>.from(
              item.map((k, v) => MapEntry(k.toString(), _toStringValue(v))),
            ),
          );
        }
      }
    }

    return PblProject(
      title: title,
      problemStatement: problemStatement,
      learningObjectives: learningObjectives,
      milestones: milestones,
      rubric: rubricList,
      miniProjects: miniProjectsList,
    );
  }

  static String _clean(String text) {
    return text.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  /// Helper to safely convert any value to String
  static String _toStringValue(dynamic value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    if (value is Map) return value.toString();
    if (value is List) return value.toString();
    return value?.toString() ?? '';
  }

  /// Extract text from PDF file
  static Future<String> extractTextFromPdf(File file) async {
    try {
      final pdf = sfpdf.PdfDocument(inputBytes: await file.readAsBytes());
      final String text = sfpdf.PdfTextExtractor(pdf).extractText();
      pdf.dispose();
      return text.trim();
    } catch (e) {
      debugPrint('PDF extraction error: $e');
      return '';
    }
  }

  /// Extract text from image using Gemini Vision
  static Future<String> extractTextFromImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      String mimeType = 'image/jpeg';
      if (file.path.toLowerCase().endsWith('.png')) mimeType = 'image/png';

      final content = [
        Content.multi([
          TextPart('Extract all text from this image.'),
          DataPart(mimeType, bytes),
        ]),
      ];

      final response = await _conceptModel.generateContent(content);
      return response.text ?? '';
    } catch (e) {
      debugPrint('Gemini Image extraction error: $e');
      return '';
    }
  }

  /// Extract text from DOC/DOCX file
  static Future<String> extractTextFromDoc(File file) async {
    try {
      // For DOCX files, we can use docx package or read as archive
      // For now, returning placeholder - add docx package for full support
      return 'Document content extraction requires additional setup';
    } catch (e) {
      debugPrint('DOC extraction error: $e');
      return '';
    }
  }
}
