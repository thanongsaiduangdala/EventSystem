import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class EventViewModel {
  final int id;
  final int accountId;
  final int eventId;
  final DateTime? viewedAt;

  EventViewModel({
    required this.id,
    required this.accountId,
    required this.eventId,
    this.viewedAt,
  });

  factory EventViewModel.fromJson(Map<String, dynamic> json) {
    return EventViewModel(
      id: json['ViewID'] as int,
      accountId: json['AccountID'] as int,
      eventId: json['EventID'] as int,
      viewedAt: json['ViewedAtYMDT'] == null
          ? null
          : DateTime.parse(json['ViewedAtYMDT'].toString()),
    );
  }
}

class EventViewApiService {
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

  static Future<List<EventViewModel>> getAllEventViews() async {
    final url = Uri.parse('$baseUrl/eventview/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => EventViewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load event views');
    }
  }

  static Future<Map<String, dynamic>> createEventView({
    required int accountId,
    required int eventId,
  }) async {
    final url = Uri.parse('$baseUrl/eventview/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({'AccountID': accountId, 'EventID': eventId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to record event view');
    }
  }
}