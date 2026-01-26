import 'dart:convert';
import 'package:http/http.dart' as http;

// AIzaSyDfoHkR03hRqlDIob1UVGoWhQ_83ze4SKI
// AIzaSyAes3PzM852ho-pWYj9VfLTly93qBSvpT0
// AIzaSyBtkJpDZ3IH6MSaKVyuvt3t2DEDXxkLaJ8

class GeminiQuizService {
  static const String _apiKey = "AIzaSyCOXcCMlYRcbrQqwHrnH5l4tUtdqLpFHso";

  static const String _url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey";

  // ============================================================
  // 🔹 CONCEPT-WISE QUIZ (UNCHANGED)
  // ============================================================
  static Future<List<Map<String, dynamic>>> generateQuizForConcept({
    required String conceptName,
  }) async {
    final prompt = _buildConceptPrompt(conceptName);

    final response = await http.post(
      Uri.parse(_url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Gemini API failed: ${response.body}");
    }

    final decoded = jsonDecode(response.body);
    final text = decoded['candidates'][0]['content']['parts'][0]['text'];

    final jsonString = _extractJson(text);
    final List<dynamic> parsed = jsonDecode(jsonString);

    return parsed.map((q) {
      return {
        'question': q['question'],
        'options': List<String>.from(q['options']),
        'correctAnswer': q['correctAnswer'],
        'difficulty': q['difficulty'],
        // concept-wise quiz already knows the concept
        'concept': conceptName,
      };
    }).toList();
  }

  // ============================================================
  // 🔥 CHAPTER-WISE QUIZ (CONCEPT-AWARE)
  // ============================================================
  static Future<List<Map<String, dynamic>>> generateQuizForChapter({
    required String chapterName,
    required List<String> concepts,
  }) async {
    final prompt = _buildChapterPrompt(
      chapterName: chapterName,
      concepts: concepts,
    );

    final response = await http.post(
      Uri.parse(_url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Gemini API failed: ${response.body}");
    }

    final decoded = jsonDecode(response.body);
    final text = decoded['candidates'][0]['content']['parts'][0]['text'];

    final jsonString = _extractJson(text);
    final List<dynamic> parsed = jsonDecode(jsonString);

    return parsed.map((q) {
      return {
        'question': q['question'],
        'options': List<String>.from(q['options']),
        'correctAnswer': q['correctAnswer'],
        'difficulty': q['difficulty'],
        // 🔥 THIS IS CRITICAL FOR WEAK CONCEPT LOGIC
        'concept': q['concept'],
        // Optional but useful later
        'chapter': chapterName,
      };
    }).toList();
  }

  // ============================================================
  // 🔹 CONCEPT PROMPT
  // ============================================================
  static String _buildConceptPrompt(String concept) {
    return '''
You are a JSON generator.

Generate EXACTLY 10 multiple-choice questions for the concept:
"$concept"

STRICT RULES:
1. Output MUST be valid JSON
2. Do NOT add explanations outside JSON
3. Do NOT use unescaped quotes inside strings
4. Do NOT use newline characters inside strings
5. Do NOT include markdown or comments
6. correctAnswer MUST be EXACTLY one of the options
7. Output ONLY JSON

JSON FORMAT:
[
  {
    "question": "string",
    "options": ["string", "string", "string", "string"],
    "correctAnswer": "string",
    "difficulty": "easy | medium | hard"
  }
]
''';
  }

  // ============================================================
  // 🔥 CHAPTER PROMPT (MOST IMPORTANT)
  // ============================================================
  static String _buildChapterPrompt({
    required String chapterName,
    required List<String> concepts,
  }) {
    return '''
You are a JSON generator.

Generate EXACTLY 20 multiple-choice questions.

Chapter:
"$chapterName"

Concept list:
${concepts.join(', ')}

VERY IMPORTANT RULES:
- EACH question MUST belong to EXACTLY ONE concept
- The concept MUST be chosen from the concept list
- Concepts MUST repeat across questions
- Questions must be evenly distributed across concepts
- correctAnswer MUST be EXACTLY one of the options

STRICT OUTPUT RULES:
1. Output MUST be valid JSON
2. Do NOT add explanations outside JSON
3. Do NOT use markdown or comments
4. Do NOT include newline characters inside strings
5. Output ONLY JSON

JSON FORMAT:
[
  {
    "question": "string",
    "options": ["string", "string", "string", "string"],
    "correctAnswer": "string",
    "difficulty": "easy | medium | hard",
    "concept": "ONE concept from the concept list"
  }
]
''';
  }

  // ============================================================
  // 🔐 SAFE JSON EXTRACTOR (UNCHANGED)
  // ============================================================
  static String _extractJson(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');

    if (start == -1 || end == -1) {
      throw Exception("No valid JSON array found in Gemini response");
    }

    return text.substring(start, end + 1);
  }
}
