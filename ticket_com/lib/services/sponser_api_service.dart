import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/sponser_models.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class SponserApiService {
  // TODO: point this at the same base URL / config your EventApiService and
  // EventImageApiService already use, so everything hits the same backend.
  static String get baseUrl => ApiConfig.baseUrl;

  static Uri _u(String path) => Uri.parse('$baseUrl$path');

  /// Same bearer-token header every other service sends. Without it the
  /// backend answers "Not authenticated" (e.g. when linking sponsors to an
  /// event). Pass json: false for multipart requests so http can set the
  /// multipart Content-Type (with its boundary) itself.
  static Map<String, String> _authHeaders({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final token = AuthService.currentToken;
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static String fullImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$baseUrl/static/$path';
  }

  // ---------------- sponsor CRUD ----------------

  static Future<List<SponserModel>> getAllSponsers() async {
    final res = await http.get(_u('/eventsponser/sponser/all'), headers: _authHeaders());
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['sponserinfo'] as List).cast<Map<String, dynamic>>();
    return list.map((e) => SponserModel.fromJson(e)).toList();
  }

  static Future<SponserModel> getSponserById(int id) async {
    final res = await http.get(_u('/eventsponser/sponser/$id'), headers: _authHeaders());
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return SponserModel.fromJson(data['sponserinfo'] as Map<String, dynamic>);
  }

  /// Creates a new sponsor with a logo file sent directly (multipart).
  static Future<Map<String, dynamic>> uploadSponser({
    required Uint8List bytes,
    required String filename,
    required String name,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      _u('/eventsponser/sponser/upload'),
    );
    req.fields['SponserName'] = name;
    req.files.add(
      http.MultipartFile.fromBytes('logo', bytes, filename: filename),
    );
    req.headers.addAll(_authHeaders(json: false));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Updates an existing sponsor's name and, if provided, swaps its logo file.
  static Future<Map<String, dynamic>> replaceSponserLogo({
    required int sponserId,
    required String name,
    Uint8List? bytes,
    String? filename,
  }) async {
    final req = http.MultipartRequest(
      'PUT',
      _u('/eventsponser/sponser/replace'),
    );
    req.fields['SponserID'] = sponserId.toString();
    req.fields['SponserName'] = name;
    if (bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'logo',
          bytes,
          filename: filename ?? 'logo.jpg',
        ),
      );
    }
    req.headers.addAll(_authHeaders(json: false));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Rename only, keeping whatever logo path is already stored.
  static Future<void> updateSponserNameOnly({
    required int sponserId,
    required String name,
    required String logoPath,
  }) async {
    final res = await http.put(
      _u('/eventsponser/sponser/update'),
      headers: _authHeaders(),
      body: jsonEncode({
        'SponserID': sponserId,
        'SponserName': name,
        'SponserLogoPath': logoPath,
      }),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteSponser(int sponserId) async {
    final res = await http.delete(
      _u('/eventsponser/sponser/$sponserId'),
      headers: _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ---------------- event <-> sponsor linking ----------------

  static Future<List<EventSponserModel>> getAllEventSponsers() async {
    final res = await http.get(_u('/eventsponser/eventsponser/all'), headers: _authHeaders());
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['eventsponserinfo'] as List)
        .cast<Map<String, dynamic>>();
    return list.map((e) => EventSponserModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> linkEventSponser({
    required int eventId,
    required int sponserId,
  }) async {
    final res = await http.post(
      _u('/eventsponser/eventsponser/createsponser'),
      headers: _authHeaders(),
      body: jsonEncode({'EventID': eventId, 'SponserID': sponserId}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateEventSponserLink({
    required int eventSponserId,
    required int eventId,
    required int sponserId,
  }) async {
    final res = await http.put(
      _u('/eventsponser/eventsponser/update'),
      headers: _authHeaders(),
      body: jsonEncode({
        'EventSponserID': eventSponserId,
        'EventID': eventId,
        'SponserID': sponserId,
      }),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteEventSponserLink(int eventSponserId) async {
    final res = await http.delete(
      _u('/eventsponser/eventsponser/$eventSponserId'),
      headers: _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
