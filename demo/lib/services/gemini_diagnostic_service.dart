import 'dart:convert';
import 'package:http/http.dart' as http;

// AIzaSyCSAfRKq2v4zMhwnx9HcPgwKp6qqpGzJ-w
// AIzaSyARQqG1EFlhN-cKrDtiampHANAOdqMZRvQ

class GeminiDiagnosticQuizService {
  static const String _apiKey = "AIzaSyCDoAWAiHVywnopzanzmtKE845xOJl8BP0";
  static const String _url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey";

  static Future<List<Map<String, dynamic>>> generateDiagnosticQuiz({
    required List<String> concepts,
  }) async {
    print("🚀 [DIAGNOSTIC] Starting quiz generation");
    print("📚 Concepts count: ${concepts.length}");
    print("📚 Concepts: $concepts");

    final prompt =
        """
You are an API.

Generate EXACTLY 20 multiple choice questions.
Questions must cover these concepts evenly:
${concepts.join(', ')}

STRICT RULES:
- Output ONLY valid JSON
- No markdown
- No explanations
- No extra text

JSON FORMAT:
[
  {
    "question": "string",
    "options": [
      "Option A",
      "Option B",
      "Option C",
      "Option D"
    ],
    "correctAnswer": "Option A",
    "difficulty": "easy|medium|hard",
    "concept": "concept name"
  }
]
""";

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

    print("🌐 Gemini status code: ${response.statusCode}");

    if (response.statusCode != 200) {
      throw Exception("❌ Gemini API failed");
    }

    final body = jsonDecode(response.body);
    final text = body['candidates'][0]['content']['parts'][0]['text'];

    if (!text.trim().startsWith('[')) {
      throw Exception("❌ Gemini returned non-JSON response");
    }

    final decoded = jsonDecode(text);

    if (decoded is! List || decoded.isEmpty) {
      throw Exception("❌ Gemini returned empty diagnostic quiz");
    }

    print("✅ Parsed diagnostic questions: ${decoded.length}");

    return List<Map<String, dynamic>>.from(decoded);
  }
}
