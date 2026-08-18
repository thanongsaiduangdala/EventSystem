import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/sponser_models.dart';

class SponserApiService {
  // TODO: point this at the same base URL / config your EventApiService and
  // EventImageApiService already use, so everything hits the same backend.
  static const String baseUrl = 'http://localhost:8000';

  static Uri _u(String path) => Uri.parse('$baseUrl$path');

  static String fullImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$baseUrl/static/$path';
  }

  // ---------------- sponsor CRUD ----------------

  static Future<List<SponserModel>> getAllSponsers() async {
    final res = await http.get(_u('/eventsponser/sponser/all'));
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['sponserinfo'] as List).cast<Map<String, dynamic>>();
    return list.map((e) => SponserModel.fromJson(e)).toList();
  }

  static Future<SponserModel> getSponserById(int id) async {
    final res = await http.get(_u('/eventsponser/sponser/$id'));
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
    final req = http.MultipartRequest('POST', _u('/eventsponser/sponser/upload'));
    req.fields['SponserName'] = name;
    req.files.add(http.MultipartFile.fromBytes('logo', bytes, filename: filename));
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
    final req = http.MultipartRequest('PUT', _u('/eventsponser/sponser/replace'));
    req.fields['SponserID'] = sponserId.toString();
    req.fields['SponserName'] = name;
    if (bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes('logo', bytes, filename: filename ?? 'logo.jpg'),
      );
    }
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'SponserID': sponserId,
        'SponserName': name,
        'SponserLogoPath': logoPath,
      }),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteSponser(int sponserId) async {
    final res = await http.delete(_u('/eventsponser/sponser/$sponserId'));
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ---------------- event <-> sponsor linking ----------------

  static Future<List<EventSponserModel>> getAllEventSponsers() async {
    final res = await http.get(_u('/eventsponser/eventsponser/all'));
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['eventsponserinfo'] as List).cast<Map<String, dynamic>>();
    return list.map((e) => EventSponserModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> linkEventSponser({
    required int eventId,
    required int sponserId,
  }) async {
    final res = await http.post(
      _u('/eventsponser/eventsponser/createsponser'),
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'EventSponserID': eventSponserId,
        'EventID': eventId,
        'SponserID': sponserId,
      }),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteEventSponserLink(int eventSponserId) async {
    final res = await http.delete(_u('/eventsponser/eventsponser/$eventSponserId'));
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
