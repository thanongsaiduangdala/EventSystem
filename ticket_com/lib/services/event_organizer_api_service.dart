import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
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

/// An account that has an accepted (VerificationStatusID == 2) identity
/// verification on file. Used to populate the "Created By" account picker.
class VerifiedAccount {
  final int id;
  final String firstName;
  final String lastName;
  final String email;

  VerifiedAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory VerifiedAccount.fromJson(Map<String, dynamic> json) {
    return VerifiedAccount(
      id: json['AccountID'] as int,
      firstName: json['FirstName']?.toString() ?? '',
      lastName: json['LastName']?.toString() ?? '',
      email: json['Email']?.toString() ?? '',
    );
  }
}

class EventOrganizerApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Same convention as SponserApiService.fullImageUrl: paths already
  /// containing a scheme are returned as-is, everything else is resolved
  /// against the backend's /static mount.
  static String fullImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$baseUrl/static/$path';
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
      return Exception('Developer access required.');
    }
    try {
      final error = jsonDecode(response.body);
      return Exception(error['detail']?.toString() ?? fallbackMsg);
    } catch (_) {
      return Exception(fallbackMsg);
    }
  }

  /// Backend returns a bare list (not wrapped in a key) for this endpoint.
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

  /// Accounts with an accepted identity verification (VerificationStatusID
  /// == 2), used to populate the "Created By" picker on the organizer form.
  /// Lives on the IdentityVerification router, not the organizer one.
  static Future<List<VerifiedAccount>> getVerifiedAccounts() async {
    final url = Uri.parse(
      '$baseUrl/identityverification/verification/verified-accounts',
    );
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => VerifiedAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load verified accounts');
    }
  }

  static Map<String, String> _multipartAuthHeaders() {
    final headers = <String, String>{};
    if (AuthService.currentToken != null) {
      headers['Authorization'] = 'Bearer ${AuthService.currentToken}';
    }
    return headers;
  }

  /// Creates a new organizer with a logo file sent directly (multipart) --
  /// same shape as SponserApiService.uploadSponser.
  static Future<Map<String, dynamic>> uploadOrganizer({
    required Uint8List bytes,
    required String filename,
    required String name,
    required int createdByAccountId,
    String? description,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/eventorganizer/organizer/upload'),
    );
    req.headers.addAll(_multipartAuthHeaders());
    req.fields['EventOrganizerName'] = name;
    req.fields['CreatedByAccountID'] = createdByAccountId.toString();
    if (description != null) {
      req.fields['EventOrganizerDiscription'] = description;
    }
    req.files.add(
      http.MultipartFile.fromBytes('logo', bytes, filename: filename),
    );
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw _handleError(res, 'Failed to create organizer');
    }
  }

  /// Updates an existing organizer's fields and, if provided, swaps its logo
  /// file -- same shape as SponserApiService.replaceSponserLogo.
  static Future<Map<String, dynamic>> replaceOrganizerLogo({
    required int organizerId,
    required String name,
    required int createdByAccountId,
    String? description,
    Uint8List? bytes,
    String? filename,
  }) async {
    final req = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/eventorganizer/organizer/replace'),
    );
    req.headers.addAll(_multipartAuthHeaders());
    req.fields['EventOrganizerID'] = organizerId.toString();
    req.fields['EventOrganizerName'] = name;
    req.fields['CreatedByAccountID'] = createdByAccountId.toString();
    if (description != null) {
      req.fields['EventOrganizerDiscription'] = description;
    }
    if (bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'logo',
          bytes,
          filename: filename ?? 'logo.jpg',
        ),
      );
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw _handleError(res, 'Failed to update organizer');
    }
  }

  static Future<Map<String, dynamic>> createOrganizer({
    required String name,
    required String logoPath,
    required int createdByAccountId,
    String? description,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/organizer/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventOrganizerName': name,
        'EventOrganizerLogoPath': logoPath,
        'CreatedByAccountID': createdByAccountId,
        'EventOrganizerDiscription': description,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create organizer');
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
