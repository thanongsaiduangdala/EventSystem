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

/// Thrown by [AccountApiService.deleteAccount] when the server answers
/// 409 ACCOUNT_HAS_DEPENDENCIES (other records still point at the account).
class AccountHasDependenciesException implements Exception {
  final String message;
  AccountHasDependenciesException(this.message);

  @override
  String toString() => message;
}

/// One "something is linked to this account" row from
/// GET /Account/{id}/dependencies. [children] hang off this row
/// (e.g. Orders -> Tickets -> Check-ins).
class AccountDependencyNode {
  /// "table.column" - sent back in `targets` for a selective delete.
  final String key;
  final String table;
  final String column;
  final String label;
  final int count;

  /// true when the database refuses to delete the account while these exist.
  final bool blocking;

  /// 'delete' = rows get deleted, 'set_null' = rows are kept, link cleared.
  final String action;
  final List<AccountDependencyNode> children;

  AccountDependencyNode({
    required this.key,
    required this.table,
    required this.column,
    required this.label,
    required this.count,
    required this.blocking,
    required this.action,
    required this.children,
  });

  bool get isUnlinkOnly => action == 'set_null';

  factory AccountDependencyNode.fromJson(Map<String, dynamic> json) {
    return AccountDependencyNode(
      key: json['key'] as String,
      table: json['table'] as String,
      column: json['column'] as String,
      label: json['label'] as String,
      count: (json['count'] as num).toInt(),
      blocking: json['blocking'] as bool,
      action: json['action'] as String,
      children: ((json['children'] as List<dynamic>?) ?? [])
          .map((e) => AccountDependencyNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AccountDependencies {
  final int accountId;
  final String accountName;
  final String email;
  final bool hasBlocking;
  final List<AccountDependencyNode> nodes;

  AccountDependencies({
    required this.accountId,
    required this.accountName,
    required this.email,
    required this.hasBlocking,
    required this.nodes,
  });

  factory AccountDependencies.fromJson(Map<String, dynamic> json) {
    return AccountDependencies(
      accountId: (json['account_id'] as num).toInt(),
      accountName: (json['account_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      hasBlocking: (json['has_blocking'] as bool?) ?? false,
      nodes: ((json['dependencies'] as List<dynamic>?) ?? [])
          .map((e) => AccountDependencyNode.fromJson(e as Map<String, dynamic>))
          .toList(),
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

  /// The server answers 409 with a `code` when the account is still linked
  /// to other records; returns its message, or null for any other 409.
  static String? _dependencyConflictMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : null;
      if (detail is Map && detail['code'] == 'ACCOUNT_HAS_DEPENDENCIES') {
        return detail['message']?.toString() ??
            'This account is still linked to other records.';
      }
    } catch (_) {
      // not our JSON shape -> treat as a normal error
    }
    return null;
  }

  /// What is linked to this account? (read-only preview, nothing is changed)
  static Future<AccountDependencies> getAccountDependencies(
    int accountId,
  ) async {
    final url = Uri.parse('$baseUrl/Account/$accountId/dependencies');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      return AccountDependencies.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw _handleError(response, 'Failed to load linked records');
  }

  /// [mode]:
  ///  - 'normal'    plain delete (throws [AccountHasDependenciesException] if linked)
  ///  - 'selective' delete the [targets] ("table.column" keys) and, once nothing
  ///                blocks it any more, the account too
  ///  - 'cascade'   delete the account and everything connected to it
  ///  - 'force'     delete only the account and ignore foreign keys
  static Future<void> deleteAccount(
    int accountId, {
    String mode = 'normal',
    List<String> targets = const [],
  }) async {
    final query = <String, String>{
      if (mode != 'normal') 'mode': mode,
      if (targets.isNotEmpty) 'targets': targets.join(','),
    };
    final url = Uri.parse(
      '$baseUrl/Account/$accountId',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode == 200) return;

    if (response.statusCode == 409) {
      final message = _dependencyConflictMessage(response);
      if (message != null) throw AccountHasDependenciesException(message);
    }
    throw _handleError(response, 'Failed to delete account');
  }
}
