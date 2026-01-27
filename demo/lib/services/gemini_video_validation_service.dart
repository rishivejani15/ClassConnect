import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiVideoValidationService {
  static const String _apiKey = "GeminiVideoValidationService_GEMINI_API_KEY";

  static const String _url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey";

  /// ⚠️ ADVISORY ONLY — NEVER BLOCK USER
  static Future<Map<String, dynamic>> validateVideoExplanation({
    required String conceptName,
    required String challengePhrase,
    required String transcript,
  }) async {
    try {
      final prompt =
          """
You are an academic examiner.

Concept:
"$conceptName"

Required spoken phrase:
"$challengePhrase"

Student explanation:
"$transcript"

Answer ONLY in JSON:
{
  "isRelevant": true or false,
  "phraseMatched": true or false,
  "confidence": number between 0 and 1
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
        return _fallback(); // ✅ FAIL OPEN
      }

      final body = jsonDecode(response.body);
      final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];

      if (text == null) return _fallback();

      return _safeExtractJson(text);
    } catch (e) {
      return _fallback(); // ✅ NEVER THROW
    }
  }

  /// ✅ SAFE JSON EXTRACTION
  static Map<String, dynamic> _safeExtractJson(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');

      if (start == -1 || end == -1 || end <= start) {
        return _fallback();
      }

      final jsonString = raw.substring(start, end + 1);
      return jsonDecode(jsonString);
    } catch (_) {
      return _fallback();
    }
  }

  /// 🔒 FALLBACK (USER ALWAYS PASSES)
  static Map<String, dynamic> _fallback() {
    return {"isRelevant": true, "phraseMatched": true, "confidence": 0.6};
  }
}
