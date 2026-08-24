import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';
import '../models/category_models.dart';

/// ---------------------------------------------------------------------
/// Route prefixes confirmed against EventCategory_router.py:
///   POST   /eventcategory/category/create
///   GET    /eventcategory/category/all
///   GET    /eventcategory/category/{category_id}
///   PUT    /eventcategory/category/update
///   DELETE /eventcategory/category/{category_id}
///   POST   /eventcategory/event/create
///   GET    /eventcategory/event/all
///   GET    /eventcategory/event/{event_category_id}
///   GET    /eventcategory/event/by-event/{event_id}
///   PUT    /eventcategory/event/update
///   DELETE /eventcategory/event/{event_category_id}
///
/// CategoryModel / EventCategoryModel live in category_models.dart, not
/// here -- event_category_form.dart imports both this file and that one,
/// so defining them in two places causes an ambiguous-import error.
/// ---------------------------------------------------------------------

class CategoryApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static const String _categoryPrefix = '/eventcategory/category';
  static const String _eventCategoryPrefix = '/eventcategory/event';

  static Uri _u(String path) => Uri.parse('$baseUrl$path');

  static String fullImageUrl(String path) {
    if (path.isEmpty) return '';
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

  /// Handles either a raw JSON array or an object wrapping the array under
  /// its first list-valued key -- keep this defensive since backend list
  /// endpoints aren't consistently shaped across routers.
  static List<dynamic> _normalizeToList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      for (final value in decoded.values) {
        if (value is List) return value;
      }
    }
    throw const FormatException('Unexpected list response shape');
  }

  // ---------------- category CRUD ----------------

  static Future<List<CategoryModel>> getAllCategories() async {
    final response = await http.get(_u('$_categoryPrefix/all'), headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to load categories');
    }
    final data = _normalizeToList(response.body);
    return data
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<CategoryModel> getCategoryById(int id) async {
    final response = await http.get(_u('$_categoryPrefix/$id'), headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to load category');
    }
    return CategoryModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> createCategory({
    required String name,
    required String iconPath,
  }) async {
    final response = await http.post(
      _u('$_categoryPrefix/create'),
      headers: _authHeaders(),
      body: jsonEncode({'CategoryName': name, 'CategoryIconPath': iconPath}),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to create category');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> updateCategory({
    required int categoryId,
    required String name,
    required String iconPath,
  }) async {
    final response = await http.put(
      _u('$_categoryPrefix/update'),
      headers: _authHeaders(),
      body: jsonEncode({
        'CategoryID': categoryId,
        'CategoryName': name,
        'CategoryIconPath': iconPath,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update category');
    }
  }

  static Future<void> deleteCategory(int categoryId) async {
    final response = await http.delete(_u('$_categoryPrefix/$categoryId'), headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete category');
    }
  }

  // ---------------- event <-> category linking ----------------

  static Future<List<EventCategoryModel>> getAllEventCategories() async {
    final response = await http.get(_u('$_eventCategoryPrefix/all'), headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to load event categories');
    }
    final data = _normalizeToList(response.body);
    return data
        .map((e) => EventCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<EventCategoryModel>> getCategoriesByEventId(int eventId) async {
    final response = await http.get(_u('$_eventCategoryPrefix/by-event/$eventId'), headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to load categories for event');
    }
    final data = _normalizeToList(response.body);
    return data
        .map((e) => EventCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> linkEventCategory({
    required int eventId,
    required int categoryId,
  }) async {
    final response = await http.post(
      _u('$_eventCategoryPrefix/create'),
      headers: _authHeaders(),
      body: jsonEncode({'EventID': eventId, 'CategoryID': categoryId}),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to link event and category');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> updateEventCategoryLink({
    required int eventCategoryId,
    required int eventId,
    required int categoryId,
  }) async {
    final response = await http.put(
      _u('$_eventCategoryPrefix/update'),
      headers: _authHeaders(),
      body: jsonEncode({
        'EventCategoryID': eventCategoryId,
        'EventID': eventId,
        'CategoryID': categoryId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update event-category link');
    }
  }

  static Future<void> deleteEventCategoryLink(int eventCategoryId) async {
    final response = await http.delete(_u('$_eventCategoryPrefix/$eventCategoryId'), headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete event-category link');
    }
  }
}
