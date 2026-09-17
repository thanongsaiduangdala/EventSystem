import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AccountStatus {
  final int id;
  final String statusType;

  AccountStatus({required this.id, required this.statusType});

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    return AccountStatus(
      id: json['StatusID'] as int,
      statusType: json['StatusType'] as String,
    );
  }
}

class AccountModel {
  final int id;
  final String firstName;
  final String lastName;
  final String phoneNum;
  final String email;
  final int statusId;

  AccountModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNum,
    required this.email,
    required this.statusId,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['AccountID'] as int,
      firstName: json['FirstName'] as String,
      lastName: json['LastName'] as String,
      phoneNum: json['PhoneNum'] as String,
      email: json['Email'] as String,
      statusId: json['StatusID'] as int,
    );
  }
}

class AccountApiService {
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

  // ---------------- account status ----------------

  static Future<List<AccountStatus>> getAllAccountStatuses() async {
    final url = Uri.parse('$baseUrl/accountstatus/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => AccountStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load account statuses');
    }
  }

  // ---------------- accounts ----------------

  static Future<List<AccountModel>> getAllAccounts() async {
    final url = Uri.parse('$baseUrl/Account/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> accounts = data['Accounts'] as List<dynamic>;
      return accounts
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load accounts');
    }
  }

  static Future<Map<String, dynamic>> createAccount({
    required String firstName,
    required String lastName,
    required String phoneNum,
    required String email,
    required int statusId,
    required String passwordEnc,
  }) async {
    final url = Uri.parse('$baseUrl/Account/create');

    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'FirstName': firstName,
        'LastName': lastName,
        'PhoneNum': phoneNum,
        'Email': email,
        'StatusID': statusId,
        'PasswordEnc': passwordEnc,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create account');
    }
  }

  static Future<void> updateAccount({
    required int accountId,
    required String firstName,
    required String lastName,
    required String phoneNum,
    required String email,
    required int statusId,
  }) async {
    final url = Uri.parse('$baseUrl/Account/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'AccountID': accountId,
        'FirstName': firstName,
        'LastName': lastName,
        'PhoneNum': phoneNum,
        'Email': email,
        'StatusID': statusId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update account');
    }
  }

  static Future<void> deleteAccount(int accountId) async {
    final url = Uri.parse('$baseUrl/Account/$accountId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete account');
    }
  }
}
