import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category_models.dart';

class CategoryApiService {
  // TODO: point this at the same base URL your other *ApiService classes use.
  static const String baseUrl = 'http://localhost:8000';

  static Uri _u(String path) => Uri.parse('$baseUrl$path');

  static String fullImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl/static/$path';
  }

  // ---------------- category CRUD ----------------
  // NOTE: unlike sponsors, these endpoints return the raw row / list of rows
  // directly -- not wrapped in a named key like {"sponserinfo": [...]}.

  static Future<List<CategoryModel>> getAllCategories() async {
    final res = await http.get(_u('/eventcategory/category/all'));
    if (res.statusCode != 200) throw Exception(res.body);
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map((e) => CategoryModel.fromJson(e)).toList();
  }

  static Future<CategoryModel> getCategoryById(int id) async {
    final res = await http.get(_u('/eventcategory/category/$id'));
    if (res.statusCode != 200) throw Exception(res.body);
    return CategoryModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> createCategory({
    required String name,
    required String iconPath,
  }) async {
    final res = await http.post(
      _u('/eventcategory/category/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'CategoryName': name, 'CategoryIconPath': iconPath}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateCategory({
    required int categoryId,
    required String name,
    required String iconPath,
  }) async {
    final res = await http.put(
      _u('/eventcategory/category/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'CategoryID': categoryId,
        'CategoryName': name,
        'CategoryIconPath': iconPath,
      }),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteCategory(int categoryId) async {
    final res = await http.delete(_u('/eventcategory/category/$categoryId'));
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ---------------- event <-> category linking ----------------

  static Future<List<EventCategoryModel>> getAllEventCategories() async {
    final res = await http.get(_u('/eventcategory/event/all'));
    if (res.statusCode != 200) throw Exception(res.body);
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map((e) => EventCategoryModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> linkEventCategory({
    required int eventId,
    required int categoryId,
  }) async {
    final res = await http.post(
      _u('/eventcategory/event/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'EventID': eventId, 'CategoryID': categoryId}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateEventCategoryLink({
    required int eventCategoryId,
    required int eventId,
    required int categoryId,
  }) async {
    final res = await http.put(
      _u('/eventcategory/event/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'EventCategoryID': eventCategoryId,
        'EventID': eventId,
        'CategoryID': categoryId,
      }),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteEventCategoryLink(int eventCategoryId) async {
    final res = await http.delete(_u('/eventcategory/event/$eventCategoryId'));
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
