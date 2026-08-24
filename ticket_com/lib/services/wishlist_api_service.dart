import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WishlistModel {
  final int id;
  final int accountId;
  final int eventId;
  final DateTime? createdAt;

  WishlistModel({
    required this.id,
    required this.accountId,
    required this.eventId,
    this.createdAt,
  });

  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    return WishlistModel(
      id: json['WishID'] as int,
      accountId: json['AccountID'] as int,
      eventId: json['EventID'] as int,
      createdAt: json['CreatedAtYMDT'] == null
          ? null
          : DateTime.parse(json['CreatedAtYMDT'].toString()),
    );
  }
}

class WishlistApiService {
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

  static Future<List<WishlistModel>> getAllWishes() async {
    final url = Uri.parse('$baseUrl/wishlist/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => WishlistModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load wishlist entries');
    }
  }

  static Future<Map<String, dynamic>> createWish({
    required int accountId,
    required int eventId,
  }) async {
    final url = Uri.parse('$baseUrl/wishlist/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({'AccountID': accountId, 'EventID': eventId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create wish');
    }
  }

  static Future<void> deleteWishById(int wishId) async {
    final url = Uri.parse('$baseUrl/wishlist/id/$wishId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete wish');
    }
  }
}
