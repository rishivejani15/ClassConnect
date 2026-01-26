import 'dart:convert';
import 'package:http/http.dart' as http;

// AIzaSyDfoHkR03hRqlDIob1UVGoWhQ_83ze4SKI
// AIzaSyBtkJpDZ3IH6MSaKVyuvt3t2DEDXxkLaJ8

class GeminiTextValidationService {
  static const String _apiKey = "AIzaSyBHjZpPhRcio0CES0Wx_aSc5chbUH9FucI";

  static const String _url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey";

  /// 🔍 VALIDATE TEXT EXPLANATION
  static Future<Map<String, dynamic>> validateTextExplanation({
    required String conceptName,
    required String explanation,
  }) async {
    final prompt =
        """
You are an academic evaluator.

Concept:
"$conceptName"

Student explanation:
"$explanation"

Evaluate strictly:
1. Is the explanation about the given concept?
2. Is the explanation technically meaningful (not random text)?

Respond ONLY in valid JSON:
{
  "isRelevant": true or false,
  "confidence": number between 0 and 1,
  "reason": "short explanation"
}
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

    if (response.statusCode != 200) {
      throw Exception("Gemini text validation failed");
    }

    final body = jsonDecode(response.body);

    final String text = body['candidates'][0]['content']['parts'][0]['text'];

    return extractJson(text);
  }
}

Map<String, dynamic> extractJson(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');

  if (start == -1 || end == -1 || end <= start) {
    throw Exception("Gemini response does not contain valid JSON");
  }

  final jsonString = raw.substring(start, end + 1);
  return jsonDecode(jsonString);
}
