import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AmeApiService {
  AmeApiService._();

  static final AmeApiService instance = AmeApiService._();

  static const String _baseUrl = 'https://rudraaaa76-ame-backend.hf.space';
  static const Duration _requestTimeout = Duration(seconds: 6);
  static const int _maxRetries = 2;
  static const Duration _initialBackoff = Duration(milliseconds: 400);

  final http.Client _client = http.Client();

  Future<bool> sendEvent({
    required String studentId,
    required String conceptId,
    required String classId,
    required String eventType,
    required double score,
    required DateTime timestamp,
  }) async {
    final payload = <String, dynamic>{
      'student_id': studentId,
      'concept_id': conceptId,
      'class_id': classId,
      'event_type': eventType,
      'score': score,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };

    final response = await _postJsonWithRetry(
      path: '/ame/update-event',
      payload: payload,
      operation: 'sendEvent($eventType:$conceptId)',
    );

    return response != null;
  }

  Future<bool> updateAttendance({
    required String studentId,
    required String classId,
    required double attendanceRate,
  }) async {
    final payload = <String, dynamic>{
      'student_id': studentId,
      'class_id': classId,
      'attendance_rate': attendanceRate,
    };

    final response = await _postJsonWithRetry(
      path: '/attendance/update',
      payload: payload,
      operation: 'updateAttendance',
    );

    return response != null;
  }

  Future<Map<String, dynamic>?> getFocus({
    required String studentId,
    required String classId,
  }) async {
    final response = await _getWithRetry(
      path: '/ame/student/$studentId/focus/$classId',
      operation: 'getFocus',
    );

    if (response == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      debugPrint('[AME] getFocus returned non-object JSON. Fallback to null.');
      return null;
    } catch (e) {
      debugPrint('[AME] getFocus JSON parse error: $e. Fallback to null.');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getClassWeakConcepts({
    required String classId,
  }) async {
    final response = await _getWithRetry(
      path: '/ame/class/$classId/concepts/weak',
      operation: 'getClassWeakConcepts',
    );

    if (response == null) {
      return null;
    }

    return _decodeJsonObjectList(
      response.body,
      operation: 'getClassWeakConcepts',
    );
  }

  Future<Map<String, dynamic>?> getClassRisk({required String classId}) async {
    final response = await _getWithRetry(
      path: '/ame/class/$classId/risk',
      operation: 'getClassRisk',
    );

    if (response == null) {
      return null;
    }

    return _decodeJsonObject(response.body, operation: 'getClassRisk');
  }

  Future<Map<String, dynamic>?> getClassIntervention({
    required String classId,
  }) async {
    final response = await _getWithRetry(
      path: '/ame/class/$classId/intervention',
      operation: 'getClassIntervention',
    );

    if (response == null) {
      return null;
    }

    return _decodeJsonObject(response.body, operation: 'getClassIntervention');
  }

  Map<String, dynamic>? _decodeJsonObject(
    String body, {
    required String operation,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      debugPrint(
        '[AME] $operation returned non-object JSON. Fallback to null.',
      );
      return null;
    } catch (e) {
      debugPrint('[AME] $operation JSON parse error: $e. Fallback to null.');
      return null;
    }
  }

  List<Map<String, dynamic>>? _decodeJsonObjectList(
    String body, {
    required String operation,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      debugPrint('[AME] $operation returned non-list JSON. Fallback to null.');
      return null;
    } catch (e) {
      debugPrint('[AME] $operation JSON parse error: $e. Fallback to null.');
      return null;
    }
  }

  Future<http.Response?> _postJsonWithRetry({
    required String path,
    required Map<String, dynamic> payload,
    required String operation,
  }) {
    return _runWithRetry(
      operation: operation,
      request: () => _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ),
    );
  }

  Future<http.Response?> _getWithRetry({
    required String path,
    required String operation,
  }) {
    return _runWithRetry(
      operation: operation,
      request: () => _client.get(Uri.parse('$_baseUrl$path')),
    );
  }

  Future<http.Response?> _runWithRetry({
    required String operation,
    required Future<http.Response> Function() request,
  }) async {
    var backoff = _initialBackoff;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final currentAttempt = attempt + 1;
      final maxAttempts = _maxRetries + 1;

      try {
        debugPrint('[AME] $operation attempt $currentAttempt/$maxAttempts');

        final response = await request().timeout(_requestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint(
            '[AME] $operation success (status=${response.statusCode})',
          );
          return response;
        }

        debugPrint(
          '[AME] $operation failed with status=${response.statusCode}, body=${_truncate(response.body)}',
        );
      } on TimeoutException {
        debugPrint(
          '[AME] $operation timed out after ${_requestTimeout.inSeconds}s',
        );
      } catch (e) {
        debugPrint('[AME] $operation request error: $e');
      }

      if (attempt < _maxRetries) {
        debugPrint('[AME] $operation retrying in ${backoff.inMilliseconds}ms');
        await Future<void>.delayed(backoff);
        backoff = Duration(milliseconds: backoff.inMilliseconds * 2);
      }
    }

    debugPrint('[AME] $operation fallback after retries (fail-open).');
    return null;
  }

  String _truncate(String value, {int maxLength = 220}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }
}
