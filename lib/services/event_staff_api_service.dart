import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EventStaffModel {
  final int id;
  final int eventId;
  final int memberId;
  final int eventRoleId;
  final DateTime? assignedAt;

  EventStaffModel({
    required this.id,
    required this.eventId,
    required this.memberId,
    required this.eventRoleId,
    this.assignedAt,
  });

  factory EventStaffModel.fromJson(Map<String, dynamic> json) {
    return EventStaffModel(
      // NOTE: the DB column is actually spelled "AssigmentID" (missing the
      // "n") -- that's what SELECT * returns, even though the create/update
      // request bodies use the correctly-spelled "AssignmentID".
      id: json['AssigmentID'] as int,
      eventId: json['EventID'] as int,
      memberId: json['MemberID'] as int,
      eventRoleId: json['EventRoleID'] as int,
      assignedAt: json['AssignedAtYMDT'] != null
          ? DateTime.tryParse(json['AssignedAtYMDT'].toString())
          : null,
    );
  }
}

class EventRoleModel {
  final int id;
  final String name;

  EventRoleModel({required this.id, required this.name});

  factory EventRoleModel.fromJson(Map<String, dynamic> json) {
    return EventRoleModel(
      id: json['EventRoleID'] as int,
      name: json['RoleName']?.toString() ?? '',
    );
  }
}

class EventStaffApiService {
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

  // ---------------- event staff ----------------

  static Future<List<EventStaffModel>> getAllStaff() async {
    final url = Uri.parse('$baseUrl/eventstaff/staff/all');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => EventStaffModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load event staff');
    }
  }

  static Future<Map<String, dynamic>> createStaff({
    required int eventId,
    required int memberId,
    required int eventRoleId,
    DateTime? assignedAt,
  }) async {
    final url = Uri.parse('$baseUrl/eventstaff/staff/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'MemberID': memberId,
        'EventRoleID': eventRoleId,
        'AssignedAtYMDT': assignedAt?.toIso8601String(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create staff assignment');
    }
  }

  static Future<void> updateStaff({
    required int assignmentId,
    required int eventId,
    required int memberId,
    required int eventRoleId,
    DateTime? assignedAt,
  }) async {
    final url = Uri.parse('$baseUrl/eventstaff/staff/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'AssignmentID': assignmentId,
        'EventID': eventId,
        'MemberID': memberId,
        'EventRoleID': eventRoleId,
        'AssignedAtYMDT': assignedAt?.toIso8601String(),
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update staff assignment');
    }
  }

  static Future<void> deleteStaff(int assignmentId) async {
    final url = Uri.parse('$baseUrl/eventstaff/staff/$assignmentId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete staff assignment');
    }
  }

  // ---------------- event roles ----------------

  static Future<List<EventRoleModel>> getAllEventRoles() async {
    final url = Uri.parse('$baseUrl/eventstaff/role/all');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => EventRoleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load event roles');
    }
  }
}
