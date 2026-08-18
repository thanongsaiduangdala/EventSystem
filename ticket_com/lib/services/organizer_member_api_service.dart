import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';

class OrganizerMemberModel {
  final int id;
  final int accountId;
  final int eventOrganizerId;
  final int teamRoleId;

  OrganizerMemberModel({
    required this.id,
    required this.accountId,
    required this.eventOrganizerId,
    required this.teamRoleId,
  });

  factory OrganizerMemberModel.fromJson(Map<String, dynamic> json) {
    return OrganizerMemberModel(
      id: json['MemberID'] as int,
      accountId: json['AccountID'] as int,
      eventOrganizerId: json['EventOrganizerID'] as int,
      teamRoleId: json['TeamRoleID'] as int,
    );
  }
}

class TeamRoleModel {
  final int id;
  final String name;

  TeamRoleModel({required this.id, required this.name});

  factory TeamRoleModel.fromJson(Map<String, dynamic> json) {
    return TeamRoleModel(
      id: json['TeamRoleID'] as int,
      name: json['TeamRoleName']?.toString() ?? '',
    );
  }
}

class OrganizerMemberApiService {
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

  // ---------------- organizer members ----------------

  static Future<List<OrganizerMemberModel>> getAllMembers() async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/all');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => OrganizerMemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load organizer members');
    }
  }

  static Future<Map<String, dynamic>> createMember({
    required int accountId,
    required int eventOrganizerId,
    required int teamRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'AccountID': accountId,
        'EventOrganizerID': eventOrganizerId,
        'TeamRoleID': teamRoleId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create organizer member');
    }
  }

  static Future<void> updateMember({
    required int memberId,
    required int accountId,
    required int eventOrganizerId,
    required int teamRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'MemberID': memberId,
        'AccountID': accountId,
        'EventOrganizerID': eventOrganizerId,
        'TeamRoleID': teamRoleId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update organizer member');
    }
  }

  static Future<void> deleteMember(int memberId) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/$memberId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete organizer member');
    }
  }

  // ---------------- team roles ----------------

  static Future<List<TeamRoleModel>> getAllTeamRoles() async {
    final url = Uri.parse('$baseUrl/teamrole/role/all');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => TeamRoleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load team roles');
    }
  }
}
