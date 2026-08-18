import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class TicketTypeModel {
  final int id;
  final int eventId;
  final String typeName;
  final int priceInKip;
  final int capacity;
  final String saleStart;
  final String saleEnd;

  TicketTypeModel({
    required this.id,
    required this.eventId,
    required this.typeName,
    required this.priceInKip,
    required this.capacity,
    required this.saleStart,
    required this.saleEnd,
  });

  factory TicketTypeModel.fromJson(Map<String, dynamic> json) {
    return TicketTypeModel(
      id: json['TicketTypeID'] as int,
      eventId: json['EventID'] as int,
      typeName: json['TypeName'] as String,
      priceInKip: json['PriceInKIP'] as int,
      capacity: json['Capacity'] as int,
      saleStart: json['SaleStartYMDT'].toString(),
      saleEnd: json['SaleEndYMDT'].toString(),
    );
  }
}

class TicketTypeApiService {
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

  static Future<List<TicketTypeModel>> getAllTicketTypes() async {
    final url = Uri.parse('$baseUrl/tickettype/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rows = data['tickettypes'] as List<dynamic>;
      return rows
          .map((e) => TicketTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load ticket types');
    }
  }

  /// Filters by event via GET /tickettype/event/{event_id}.
  /// Returns an empty list (not an error) when the backend responds 404
  /// "no ticket types for this event" -- that's a valid, non-error state.
  static Future<List<TicketTypeModel>> getTicketTypesByEvent(
    int eventId,
  ) async {
    final url = Uri.parse('$baseUrl/tickettype/event/$eventId');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rows = data['tickettypes'] as List<dynamic>;
      return rows
          .map((e) => TicketTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw _handleError(response, 'Failed to load ticket types for event');
    }
  }

  /// Free-text search via GET /tickettype/search/{value} -- matches
  /// TypeName, EventID, PriceInKip, Capacity, or sale dates on the backend.
  /// Returns an empty list (not an error) on a 404 "no matches" response.
  static Future<List<TicketTypeModel>> searchTicketTypes(String value) async {
    final url = Uri.parse(
      '$baseUrl/tickettype/search/${Uri.encodeComponent(value)}',
    );
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rows = data['tickettypes'] as List<dynamic>;
      return rows
          .map((e) => TicketTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw _handleError(response, 'Search failed');
    }
  }

  static Future<Map<String, dynamic>> createTicketType({
    required int eventId,
    required String typeName,
    required int priceInKip,
    required int capacity,
    required String saleStart,
    required String saleEnd,
  }) async {
    final url = Uri.parse('$baseUrl/tickettype/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'TypeName': typeName,
        'PriceInKip': priceInKip,
        'Capacity': capacity,
        'SaleStart': saleStart,
        'SaleEnd': saleEnd,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create ticket type');
    }
  }

  static Future<void> updateTicketType({
    required int ticketTypeId,
    required int eventId,
    required String typeName,
    required int priceInKip,
    required int capacity,
    required String saleStart,
    required String saleEnd,
  }) async {
    final url = Uri.parse('$baseUrl/tickettype/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'TicketTypeID': ticketTypeId,
        'EventID': eventId,
        'TypeName': typeName,
        'PriceInKip': priceInKip,
        'Capacity': capacity,
        'SaleStart': saleStart,
        'SaleEnd': saleEnd,
      }),
    );

    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update ticket type');
    }
  }

  static Future<void> deleteTicketType(int ticketTypeId) async {
    final url = Uri.parse('$baseUrl/tickettype/$ticketTypeId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete ticket type');
    }
  }
}
