import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class Permissions {
  static const viewEvents = 'view_events';
  static const createEvent = 'create_event';
  static const updateEvent = 'update_event';
  static const deleteEvent = 'delete_event';
  static const manageEventOrganizer = 'manage_event_organizer';
  static const manageEventMembers = 'manage_event_members';
  static const manageCategories = 'manage_categories';
  static const manageEventImages = 'manage_event_images';
  static const manageTicketTypes = 'manage_ticket_types';
  static const manageEventQuestions = 'manage_event_questions';
  static const manageAccounts = 'manage_accounts';
  static const manageOrders = 'manage_orders';
  static const manageWishlist = 'manage_wishlist';

  static const audienceViewPermissions = <String>[viewEvents];
}

class UserSession {
  final int accountId;
  final int statusId; // 1 = customer, 2 = organizer, 3 = superadmin
  final String? role; // CUSTOMER / ORGANIZER / SUPERADMIN
  final List<String> permissions;
  final String firstname;
  final String lastname;
  final String email;
  final String phoneNum;

  UserSession({
    required this.accountId,
    required this.statusId,
    this.role,
    this.permissions = const [],
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.phoneNum,
  });

  bool get isSuperAdmin => role == 'SUPERADMIN' || statusId == 3;
  bool get isOrganizer => role == 'ORGANIZER' || statusId == 2;
  bool get isCustomer => role == 'CUSTOMER' || statusId == 1;

  bool hasPermission(String permission) =>
      isSuperAdmin || permissions.contains(permission);

  Map<String, dynamic> toJson() => {
    'AccountID': accountId,
    'StatusID': statusId,
    'Role': role,
    'Permissions': permissions,
    'firstname': firstname,
    'lastname': lastname,
    'Email': email,
    'PhoneNum': phoneNum,
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    accountId: json['AccountID'] as int,
    statusId: json['StatusID'] as int,
    role: json['Role']?.toString(),
    permissions: _parsePermissions(json['Permissions']),
    firstname: json['firstname']?.toString() ?? '',
    lastname: json['lastname']?.toString() ?? '',
    email: json['Email']?.toString() ?? '',
    phoneNum: json['PhoneNum']?.toString() ?? '',
  );

  static List<String> _parsePermissions(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }
}

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  static const _sessionKey = 'user_session';
  static const _rememberKey = 'remember_me';
  static const _tokenKey = 'access_token';

  static const _secureStorage = FlutterSecureStorage();

  static UserSession? currentSession;
  static String? currentToken;

  static Future<UserSession> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final session = UserSession.fromJson(data);
      final token = data['access_token'] as String;

      currentSession = session;
      currentToken = token;

      return session;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail']?.toString() ?? 'Login failed');
    }
  }

  static Future<void> saveSession(UserSession session, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
      if (currentToken != null) {
        await _secureStorage.write(key: _tokenKey, value: currentToken);
      }
    } else {
      await prefs.remove(_sessionKey);
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  static Future<UserSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_rememberKey) ?? false;
    if (!remembered) return null;

    final raw = prefs.getString(_sessionKey);
    final token = await _secureStorage.read(key: _tokenKey);
    if (raw == null || token == null) return null;

    final session = UserSession.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    currentSession = session;
    currentToken = token;
    return session;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_rememberKey);
    await _secureStorage.delete(key: _tokenKey);
    currentSession = null;
    currentToken = null;
  }

  // now sends the JWT, and hits the developer-protected endpoint directly
  static Future<bool> verifyDeveloperStatus() async {
    if (currentToken == null) return false;

    final response = await http.get(
      Uri.parse(
        '$baseUrl/account/status',
      ), // no ID needed — token identifies the user
      headers: {'Authorization': 'Bearer $currentToken'},
    );

    if (response.statusCode == 200) {
      return true; // 200 only happens if require_developer passed
    }
    return false; // 401/403 = not valid or not a developer
  }

  /// Re-fetches role + permissions from /rbac/me and updates the stored session.
  /// Returns true if the session was refreshed, false if not logged in/authorized.
  static Future<bool> refreshRbac() async {
    if (currentToken == null || currentSession == null) return false;

    final response = await http.get(
      Uri.parse('$baseUrl/rbac/me'),
      headers: {'Authorization': 'Bearer $currentToken'},
    );
    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final old = currentSession!;
    final updated = UserSession(
      accountId: data['AccountID'] as int,
      statusId: data['StatusID'] as int,
      role: data['Role']?.toString(),
      permissions: data['Permissions'] is List
          ? (data['Permissions'] as List).map((e) => e.toString()).toList()
          : const [],
      firstname: old.firstname,
      lastname: old.lastname,
      email: old.email,
      phoneNum: old.phoneNum,
    );
    currentSession = updated;
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_rememberKey) ?? false;
    await saveSession(updated, remembered);
    return true;
  }

  /// True when the current session has the named permission (SUPERADMIN always passes).
  static bool hasPermission(String permission) =>
      currentSession?.hasPermission(permission) ?? false;
}
