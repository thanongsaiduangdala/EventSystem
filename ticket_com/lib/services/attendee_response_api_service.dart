import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';

class AttendeeResponseModel {
  final int id;
  final int eventQuestionId;
  final int attendeeId;
  final String attendeeAnswer;

  AttendeeResponseModel({
    required this.id,
    required this.eventQuestionId,
    required this.attendeeId,
    required this.attendeeAnswer,
  });

  factory AttendeeResponseModel.fromJson(Map<String, dynamic> json) {
    return AttendeeResponseModel(
      id: json['ResponseID'] as int,
      eventQuestionId: json['EventQuestionID'] as int,
      attendeeId: json['attendeeID'] as int,
      attendeeAnswer: json['attendeeAnswer'] as String,
    );
  }
}

class AttendeeResponseApiService {
  static String get baseUrl => ApiConfig.baseUrl;

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

  static Future<List<AttendeeResponseModel>> getAllAttendeeResponses() async {
    final url = Uri.parse('$baseUrl/response/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => AttendeeResponseModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load attendee responses');
    }
  }

  static Future<AttendeeResponseModel> getAttendeeResponseById(
    int responseId,
  ) async {
    final url = Uri.parse('$baseUrl/response/$responseId');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      return AttendeeResponseModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw _handleError(response, 'Failed to load attendee response');
    }
  }

  /// Convenience lookup: all question responses for a given attendeeID.
  static Future<List<AttendeeResponseModel>> getResponsesByAttendee(
    int attendeeId,
  ) async {
    final url = Uri.parse('$baseUrl/response/by-attendee/$attendeeId');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => AttendeeResponseModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw _handleError(response, 'Failed to load responses for attendee');
    }
  }

  static Future<Map<String, dynamic>> createAttendeeResponse({
    required int eventQuestionId,
    required int attendeeId,
    required String attendeeAnswer,
  }) async {
    final url = Uri.parse('$baseUrl/response/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventQuestionID': eventQuestionId,
        'attendeeID': attendeeId,
        'attendeeAnswer': attendeeAnswer,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create attendee response');
    }
  }

  static Future<void> updateAttendeeResponse({
    required int responseId,
    required int eventQuestionId,
    required int attendeeId,
    required String attendeeAnswer,
  }) async {
    final url = Uri.parse('$baseUrl/response/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'ResponseID': responseId,
        'EventQuestionID': eventQuestionId,
        'attendeeID': attendeeId,
        'attendeeAnswer': attendeeAnswer,
      }),
    );

    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update attendee response');
    }
  }

  static Future<void> deleteAttendeeResponse(int responseId) async {
    final url = Uri.parse('$baseUrl/response/$responseId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete attendee response');
    }
  }
}
