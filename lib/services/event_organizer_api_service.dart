import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EventOrganizer {
  final int id;
  final String name;
  final String? logoPath;
  final int createdByAccountId;
  final String? description;

  EventOrganizer({
    required this.id,
    required this.name,
    this.logoPath,
    required this.createdByAccountId,
    this.description,
  });

  factory EventOrganizer.fromJson(Map<String, dynamic> json) {
    return EventOrganizer(
      id: json['EventOrganizerID'] as int,
      name: json['EventOrganizerName'] as String,
      logoPath: json['EventOrganizerLogoPath'] as String?,
      createdByAccountId: json['CreatedByAccountID'] as int,
      description: json['EventOrganizerDiscription'] as String?,
    );
  }
}

class EventOrganizerApiService {
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

  /// Backend returns a bare list (not wrapped in a key) for this endpoint.
  static Future<List<EventOrganizer>> getAllOrganizers() async {
    final url = Uri.parse('$baseUrl/eventorganizer/organizer/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => EventOrganizer.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load organizers');
    }
  }

  static Future<Map<String, dynamic>> createOrganizer({
    required String name,
    required String logoPath,
    required int createdByAccountId,
    String? description,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/organizer/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventOrganizerName': name,
        'EventOrganizerLogoPath': logoPath,
        'CreatedByAccountID': createdByAccountId,
        'EventOrganizerDiscription': description,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create organizer');
    }
  }

  static Future<void> updateOrganizer({
    required int id,
    required String name,
    String? logoPath,
    required int createdByAccountId,
    String? description,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/organizer/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventOrganizerID': id,
        'EventOrganizerName': name,
        'EventOrganizerLogoPath': logoPath,
        'CreatedByAccountID': createdByAccountId,
        'EventOrganizerDiscription': description,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update organizer');
    }
  }

  static Future<void> deleteOrganizer(int id) async {
    final url = Uri.parse('$baseUrl/eventorganizer/organizer/$id');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete organizer');
    }
  }
}
