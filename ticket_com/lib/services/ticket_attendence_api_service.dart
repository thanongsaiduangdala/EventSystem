import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TicketAttendeeModel {
  final int id;
  final int ticketTypeId;
  final int orderId;
  final String firstName;
  final String lastName;
  final String phoneNum;
  final String email;

  TicketAttendeeModel({
    required this.id,
    required this.ticketTypeId,
    required this.orderId,
    required this.firstName,
    required this.lastName,
    required this.phoneNum,
    required this.email,
  });

  factory TicketAttendeeModel.fromJson(Map<String, dynamic> json) {
    return TicketAttendeeModel(
      id: json['attendeeID'] as int,
      ticketTypeId: json['TicketTypeID'] as int,
      orderId: json['OrderID'] as int,
      firstName: json['FirstName'] as String,
      lastName: json['LastName'] as String,
      phoneNum: json['PhoneNum'] as String,
      email: json['Email'] as String,
    );
  }
}

class TicketAttendenceApiService {
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

  static Future<List<TicketAttendeeModel>> getAllTicketAttendees() async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => TicketAttendeeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load ticket attendees');
    }
  }

  static Future<Map<String, dynamic>> createTicketAttendee({
    required int ticketTypeId,
    required int orderId,
    required String firstName,
    required String lastName,
    required String phoneNum,
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/create');

    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'TicketTypeID': ticketTypeId,
        'OrderID': orderId,
        'FirstName': firstName,
        'LastName': lastName,
        'PhoneNum': phoneNum,
        'Email': email,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create ticket attendee');
    }
  }

  static Future<void> updateTicketAttendee({
    required int attendeeId,
    required int ticketTypeId,
    required int orderId,
    required String firstName,
    required String lastName,
    required String phoneNum,
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'attendeeID': attendeeId,
        'TicketTypeID': ticketTypeId,
        'OrderID': orderId,
        'FirstName': firstName,
        'LastName': lastName,
        'PhoneNum': phoneNum,
        'Email': email,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update ticket attendee');
    }
  }

  static Future<void> deleteTicketAttendee(int attendeeId) async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/$attendeeId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete ticket attendee');
    }
  }
}
