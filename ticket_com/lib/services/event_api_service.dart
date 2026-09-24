import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

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

class EventStatus {
  static const int pending = 1;
  static const int approved = 2;
  static const int denied = 3;
}

class EventModel {
  final int id;
  final String name;
  final DateTime start;
  final DateTime end;
  final String address;
  final double latitude;
  final double longitude;
  final String description;
  final int organizerId;
  final bool onePerPerson;
  final int eventStatusId;

  EventModel({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.organizerId,
    this.onePerPerson = false,
    this.eventStatusId = EventStatus.approved,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final rawFlag = json['OnePerPerson'];
    return EventModel(
      id: json['EventID'] as int,
      name: json['EventName'] as String,
      start: DateTime.parse(json['EventStartingYMDT'].toString()),
      end: DateTime.parse(json['EventEndingYMDT'].toString()),
      address: json['EventAddress'] as String,
      latitude: double.parse(json['Latitude'].toString()),
      longitude: double.parse(json['Longitude'].toString()),
      description: json['EventDescription'] as String,
      organizerId: json['EventOrganizerID'] as int,
      onePerPerson: rawFlag == 1 || rawFlag == true,
      eventStatusId: (json['EventStatusID'] as int?) ?? EventStatus.approved,
    );
  }
}

class EventApiService {
  static String get baseUrl => ApiConfig.baseUrl;

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
      return Exception('You do not have permission for this action.');
    }
    try {
      final error = jsonDecode(response.body);
      return Exception(error['detail']?.toString() ?? fallbackMsg);
    } catch (_) {
      return Exception(fallbackMsg);
    }
  }

  static Future<List<EventModel>> getAllEvents() async {
    final url = Uri.parse('$baseUrl/event/all');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> events = data['events'] as List<dynamic>;
      return events
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw throw _handleError(response, 'Failed to load events');
    }
  }

  /// Management view: every event including Pending/Denied ones, so
  /// organizers can track approval and admins can review submissions.
  static Future<List<EventModel>> getAllEventsWithStatus() async {
    final url = Uri.parse('$baseUrl/event/all-with-status');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> events = data['events'] as List<dynamic>;
      return events
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw throw _handleError(response, 'Failed to load events');
    }
  }

  /// Admin/employee action: approve (2) or deny (3) an event.
  static Future<void> setEventStatus({
    required int eventId,
    required int eventStatusId,
  }) async {
    final url = Uri.parse('$baseUrl/event/status');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'EventStatusID': eventStatusId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update event status');
    }
  }

  static Future<void> updateEvent({
    required int eventId,
    required String eventName,
    required String eventStartingYMDT,
    required String eventEndingYMDT,
    required String eventAddress,
    required double latitude,
    required double longitude,
    required String eventDescription,
    required int eventOrganizerID,
    bool onePerPerson = false,
  }) async {
    final url = Uri.parse('$baseUrl/event/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'EventName': eventName,
        'EventStartingYMDT': eventStartingYMDT,
        'EventEndingYMDT': eventEndingYMDT,
        'EventAddress': eventAddress,
        'EventOrganizerID': eventOrganizerID,
        'Latitude': latitude,
        'Longitude': longitude,
        'EventDescription': eventDescription,
        'OnePerPerson': onePerPerson,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update event');
    }
  }

  static Future<void> deleteEvent(int eventId) async {
    final url = Uri.parse('$baseUrl/event/$eventId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete event');
    }
  }

  static Future<Map<String, dynamic>> createEvent({
    required String eventName,
    required String eventStartingYMDT,
    required String eventEndingYMDT,
    required String eventAddress,
    required double latitude,
    required double longitude,
    required String eventDescription,
    required int eventOrganizerID,
    bool onePerPerson = false,
  }) async {
    final url = Uri.parse('$baseUrl/event/create');

    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventName': eventName,
        'EventStartingYMDT': eventStartingYMDT,
        'EventEndingYMDT': eventEndingYMDT,
        'EventAddress': eventAddress,
        'Latitude': latitude,
        'Longitude': longitude,
        'EventDescription': eventDescription,
        'EventOrganizerID': eventOrganizerID,
        'OnePerPerson': onePerPerson,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create event');
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
