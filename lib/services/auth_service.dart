import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserSession {
  final int accountId;
  final int statusId; // 1 = customer, 2 = organizer, 3 = developer
  final String firstname;
  final String lastname;
  final String email;
  final String phoneNum;

  UserSession({
    required this.accountId,
    required this.statusId,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.phoneNum,
  });

  Map<String, dynamic> toJson() => {
    'AccountID': accountId,
    'StatusID': statusId,
    'firstname': firstname,
    'lastname': lastname,
    'Email': email,
    'PhoneNum': phoneNum,
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    accountId: json['AccountID'] as int,
    statusId: json['StatusID'] as int,
    firstname: json['firstname']?.toString() ?? '',
    lastname: json['lastname']?.toString() ?? '',
    email: json['Email']?.toString() ?? '',
    phoneNum: json['PhoneNum']?.toString() ?? '',
  );
}

class AuthService {
  static const String baseUrl = 'http://127.0.0.1:8000';

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
}
