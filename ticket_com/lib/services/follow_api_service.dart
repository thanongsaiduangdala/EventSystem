import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class FollowModel {
  final int id;
  final int accountId;
  final int organizerId;
  final DateTime? createdAt;

  FollowModel({
    required this.id,
    required this.accountId,
    required this.organizerId,
    this.createdAt,
  });

  factory FollowModel.fromJson(Map<String, dynamic> json) {
    return FollowModel(
      id: json['FollowID'] as int,
      accountId: json['AccountID'] as int,
      organizerId: json['EventOrganizerID'] as int,
      createdAt: json['CreatedAtYMDT'] == null
          ? null
          : DateTime.parse(json['CreatedAtYMDT'].toString()),
    );
  }
}

class FollowApiService {
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

  static Future<List<FollowModel>> getAllFollows() async {
    final url = Uri.parse('$baseUrl/follow/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => FollowModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load follows');
    }
  }

  static Future<List<FollowModel>> getFollowsByAccount(int accountId) async {
    final url = Uri.parse('$baseUrl/follow/account/$accountId');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => FollowModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load follows');
    }
  }

  static Future<Map<String, dynamic>> createFollow({
    required int accountId,
    required int organizerId,
  }) async {
    final url = Uri.parse('$baseUrl/follow/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'AccountID': accountId,
        'EventOrganizerID': organizerId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to follow organizer');
    }
  }

  static Future<void> deleteFollow({
    required int accountId,
    required int organizerId,
  }) async {
    final url = Uri.parse('$baseUrl/follow/$accountId/$organizerId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to unfollow organizer');
    }
  }
}