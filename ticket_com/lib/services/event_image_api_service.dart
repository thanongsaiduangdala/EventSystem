import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EventImageModel {
  final int id;
  final int eventId;
  final String imageName;
  final String imagePath;
  final bool isThumbnail;

  EventImageModel({
    required this.id,
    required this.eventId,
    required this.imageName,
    required this.imagePath,
    this.isThumbnail = false,
  });

  factory EventImageModel.fromJson(Map<String, dynamic> json) {
    return EventImageModel(
      id: json['ImageID'] as int,
      eventId: json['EventID'] as int,
      imageName: json['ImageName'] as String,
      imagePath: json['ImagePath'] as String,
      // pymysql can hand this back as 0/1, true/false, or missing on older rows.
      isThumbnail: json['IsThumbnail'] == 1 || json['IsThumbnail'] == true,
    );
  }
}

class EventImageApiService {
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

  // ---------------- eventimageinfo ----------------

  /// Backend has no filter-by-event endpoint for images (only lookup by
  /// ImageID), so callers that need "images for event X" should fetch
  /// everything with this method and filter client-side.
  static Future<List<EventImageModel>> getAllEventImages() async {
    final url = Uri.parse('$baseUrl/eventimage/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rows = data['eventimageinfo'] as List<dynamic>;
      return rows
          .map((e) => EventImageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load event images');
    }
  }

  static Future<EventImageModel> getEventImageById(int imageId) async {
    final url = Uri.parse('$baseUrl/eventimage/$imageId');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return EventImageModel.fromJson(
        data['eventimageinfo'] as Map<String, dynamic>,
      );
    } else {
      throw _handleError(response, 'Failed to load event image');
    }
  }

  static Future<Map<String, dynamic>> createEventImage({
    required int eventId,
    required String imageName,
    required String imagePath,
  }) async {
    final url = Uri.parse('$baseUrl/eventimage/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'ImageName': imageName,
        'ImagePath': imagePath,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create event image');
    }
  }

  static Future<void> updateEventImage({
    required int imageId,
    required int eventId,
    required String imageName,
    required String imagePath,
  }) async {
    final url = Uri.parse('$baseUrl/eventimage/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'ImageID': imageId,
        'EventID': eventId,
        'ImageName': imageName,
        'ImagePath': imagePath,
      }),
    );

    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update event image');
    }
  }

  /// Uploads a picked image for a brand-new image record. This is what the
  /// "Create Image" flow should call -- it saves the file on the server AND
  /// creates the eventimageinfo row in one request.
  ///
  /// Takes raw bytes + a filename (rather than a dart:io File) so this works
  /// on every platform, including Flutter Web where dart:io isn't available.
  static Future<Map<String, dynamic>> uploadEventImage({
    required int eventId,
    required Uint8List bytes,
    required String filename,
    String? imageName,
  }) async {
    final url = Uri.parse('$baseUrl/eventimage/upload');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(_authHeaders()..remove('Content-Type'));
    request.fields['event_id'] = eventId.toString();
    if (imageName != null && imageName.isNotEmpty) {
      request.fields['image_name'] = imageName;
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to upload event image');
    }
  }

  /// Swaps the underlying file for an existing image record (and deletes the
  /// old file server-side). Use this from the "Update Image" flow when the
  /// user picked a new file.
  static Future<Map<String, dynamic>> replaceEventImage({
    required int imageId,
    required Uint8List bytes,
    required String filename,
    String? imageName,
  }) async {
    final url = Uri.parse('$baseUrl/eventimage/$imageId/replace');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(_authHeaders()..remove('Content-Type'));
    if (imageName != null && imageName.isNotEmpty) {
      request.fields['image_name'] = imageName;
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to replace event image');
    }
  }

  /// ImagePath from the backend is a relative path like
  /// "/static/event_images/12/abc.jpg" -- prefix it with baseUrl to display it.
  static String fullImageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return '$baseUrl$imagePath';
  }

  /// The backend generates a "<name>_thumb.<ext>" alongside every uploaded
  /// image (see _thumb_name_for in EventImageInfo_controllers.py). Use this
  /// smaller version anywhere you're showing a list/grid of images -- it's
  /// much lighter than loading the full-size file just for a preview.
  static String thumbnailUrl(String imagePath) {
    final full = fullImageUrl(imagePath);
    final dotIndex = full.lastIndexOf('.');
    final lastSlash = full.lastIndexOf('/');
    if (dotIndex == -1 || dotIndex < lastSlash) return full;
    return '${full.substring(0, dotIndex)}_thumb${full.substring(dotIndex)}';
  }

  /// Marks [imageId] as the thumbnail for its event. The backend clears the
  /// flag off whichever image previously held it for that same event, so
  /// only one image per event is ever the thumbnail.
  static Future<Map<String, dynamic>> setThumbnail(int imageId) async {
    final url = Uri.parse('$baseUrl/eventimage/$imageId/set-thumbnail');
    final response = await http.post(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to set thumbnail');
    }
  }

  static Future<void> deleteEventImage(int imageId) async {
    final url = Uri.parse('$baseUrl/eventimage/$imageId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete event image');
    }
  }
}