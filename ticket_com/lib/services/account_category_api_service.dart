import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AccountCategoryModel {
  final int id;
  final int accountId;
  final int categoryId;
  final String categoryName;
  final DateTime? createdAt;

  AccountCategoryModel({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.categoryName,
    this.createdAt,
  });

  factory AccountCategoryModel.fromJson(Map<String, dynamic> json) {
    return AccountCategoryModel(
      id: json['AccountCategoryID'] as int,
      accountId: json['AccountID'] as int,
      categoryId: json['CategoryID'] as int,
      categoryName: json['CategoryName'] as String,
      createdAt: json['CreatedAtYMDT'] == null
          ? null
          : DateTime.parse(json['CreatedAtYMDT'].toString()),
    );
  }
}

class AccountCategoryApiService {
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

  /// All account<->category favorites across every account, joined with
  /// category names -- for the admin dashboard table.
  static Future<List<AccountCategoryModel>> getAllAccountCategories() async {
    final url = Uri.parse('$baseUrl/accountcategory/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => AccountCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load account categories');
    }
  }

  /// Favorite a single category for one account.
  static Future<Map<String, dynamic>> addAccountCategory({
    required int accountId,
    required int categoryId,
  }) async {
    final url = Uri.parse('$baseUrl/accountcategory/add');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({'AccountID': accountId, 'CategoryID': categoryId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to favorite category');
    }
  }

  static Future<void> deleteAccountCategory(int accountCategoryId) async {
    final url = Uri.parse('$baseUrl/accountcategory/$accountCategoryId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to remove favorite');
    }
  }
}
