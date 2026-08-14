import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EventQuestionTypeModel {
  final int id;
  final String name;

  EventQuestionTypeModel({required this.id, required this.name});

  factory EventQuestionTypeModel.fromJson(Map<String, dynamic> json) {
    return EventQuestionTypeModel(
      id: json['EventQuestionTypeID'] as int,
      name: json['EventQuestionType'] as String,
    );
  }
}

class EventQuestionModel {
  final int id;
  final int eventId;
  final String question;
  final int questionTypeId;
  final bool isRequire;
  final int sortOrder;
  final List<String>? options;

  EventQuestionModel({
    required this.id,
    required this.eventId,
    required this.question,
    required this.questionTypeId,
    required this.isRequire,
    required this.sortOrder,
    this.options,
  });

  factory EventQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['Options'];
    return EventQuestionModel(
      id: json['EventQuestionID'] as int,
      eventId: json['EventID'] as int,
      question: json['EventQuestion'] as String,
      questionTypeId: json['EventQuestionTypeID'] as int,
      isRequire: json['IsRequire'] is bool
          ? json['IsRequire'] as bool
          : (json['IsRequire'] as int) == 1,
      sortOrder: json['SortOrder'] as int,
      options: rawOptions == null
          ? null
          : List<String>.from(rawOptions as List<dynamic>),
    );
  }
}

class EventQuestionApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Map<String, String> _authHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (AuthService.currentToken != null) {
      headers['Authorization'] = 'Bearer ${AuthService.currentToken}';
    }
    return headers;
  }

  static Exception _handleError(http.Response response, String fallbackMsg) {
    if (response.statusCode == 401) {
      return Exception('Session expired. Please log in again.');
    }
    if (response.statusCode == 403) {
      return Exception('Developer access required.');
    }
    try {
      final error = jsonDecode(response.body);
      return Exception(error['detail']?.toString() ?? fallbackMsg);
    } catch (_) {
      return Exception(fallbackMsg);
    }
  }

  // ---------------- eventquestioninfo ----------------

  static Future<List<EventQuestionModel>> getAllEventQuestions() async {
    final url = Uri.parse('$baseUrl/eventquestion/');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rows = data['events'] as List<dynamic>;
      return rows
          .map((e) => EventQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load event questions');
    }
  }

  static Future<Map<String, dynamic>> createEventQuestion({
    required int eventId,
    required String question,
    required int questionTypeId,
    required bool isRequire,
    required int sortOrder,
    List<String>? options,
  }) async {
    final url = Uri.parse('$baseUrl/eventquestion/');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'EventQuestion': question,
        'EventQuestionTypeID': questionTypeId,
        'IsRequire': isRequire,
        'SortOrder': sortOrder,
        'Options': options,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create event question');
    }
  }

  static Future<void> updateEventQuestion({
    required int eventQuestionId,
    required int eventId,
    required String question,
    required int questionTypeId,
    required bool isRequire,
    required int sortOrder,
    List<String>? options,
  }) async {
    final url = Uri.parse('$baseUrl/eventquestion/');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventQuestionID': eventQuestionId,
        'EventID': eventId,
        'EventQuestion': question,
        'EventQuestionTypeID': questionTypeId,
        'IsRequire': isRequire,
        'SortOrder': sortOrder,
        'Options': options,
      }),
    );

    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update event question');
    }
  }

  static Future<void> deleteEventQuestion(int eventQuestionId) async {
    final url = Uri.parse('$baseUrl/eventquestion/$eventQuestionId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete event question');
    }
  }

  // ---------------- eventquestiontype ----------------

  static Future<List<EventQuestionTypeModel>> getAllEventQuestionTypes() async {
    final url = Uri.parse('$baseUrl/eventquestion/type');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rows = data['eventquestiontypes'] as List<dynamic>;
      return rows
          .map(
            (e) => EventQuestionTypeModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw _handleError(response, 'Failed to load event question types');
    }
  }
}
