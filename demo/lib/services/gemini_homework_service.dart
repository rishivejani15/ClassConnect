import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiHomeworkService {
  static const String _apiKey = "GeminiHomeworkService_GEMINI_API_KEY";
  static const String _url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey";

  static Future<Map<String, dynamic>> generateHomework({
    required List<String> weakConcepts,
    required String className,
  }) async {
    print("🚀 [HOMEWORK] Starting generation for: $weakConcepts");

    final prompt =
        """
You are an expert tutor. Create a personalized homework assignment for a student struggling with these concepts in $className:
${weakConcepts.join(', ')}

Generate a homework assignment with EXACTLY 5 Theory/Short Answer Questions.
No MCQs. No Creative Tasks. Just 5 solid questions that test their understanding.

STRICT RULES:
- Output ONLY valid JSON
- No markdown formatting (no ```json blocks)
- No explanations outside the JSON
- The output must be a single JSON object with key: "theory".

JSON SCHEMA:
{
  "theory": [
    {
      "question": "string",
      "expectedKeyPoints": ["point 1", "point 2"]
    }
  ]
}
""";

    try {
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
        throw Exception("Gemini API failed with ${response.statusCode}");
      }

      final body = jsonDecode(response.body);
      String text = body['candidates'][0]['content']['parts'][0]['text'];

      // Clean up markdown if present
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      final decoded = jsonDecode(text);
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      print("❌ Error generating homework: $e");
      throw Exception("Failed to generate homework");
    }
  }

  /// 🔹 EVALUATE HOMEWORK
  static Future<Map<String, dynamic>> evaluateHomework({
    required List<Map<String, dynamic>> qna, // [{question, answer}]
    String? attachmentName,
  }) async {
    final prompt =
        """
You are a strict but fair teacher. Evaluate this student's homework.

Questions and Answers:
${jsonEncode(qna)}

${attachmentName != null ? "The student has also attached a file named '$attachmentName'. Acknowledge this in the feedback." : ""}

Evaluate each answer based on correctness and depth. 
If an answer is blank or nonsense, give 0.

Output EXACTLY valid JSON:
{
  "score": 0, // Integer out of 100
  "feedback": "Overall feedback summary...",
  "corrections": [
    {
      "questionIndex": 0,
      "feedback": "Specific feedback for this answer..."
    }
  ]
}
""";

    try {
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

      final body = jsonDecode(response.body);
      String text = body['candidates'][0]['content']['parts'][0]['text'];
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      return Map<String, dynamic>.from(jsonDecode(text));
    } catch (e) {
      print("❌ Error evaluating homework: $e");
      return {
        "score": 0,
        "feedback":
            "Error evaluating homework. Please wait for teacher review.",
        "corrections": [],
      };
    }
  }
}
