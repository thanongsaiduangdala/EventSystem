import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// One notification shown to the user (dropdown panel and full page).
///
/// [type] is one of: `order`, `event`, `wish`, `promo`, `system`. It drives
/// the leading icon / colour shown on the tiles.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['NotificationID'] as int,
      type: (json['NotificationType'] ?? 'system').toString(),
      title: (json['Title'] ?? '').toString(),
      body: (json['Body'] ?? '').toString(),
      time: json['CreatedAtYMDT'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['CreatedAtYMDT'].toString()) ??
                DateTime.now(),
      read: (json['IsRead'] ?? 0) == 1,
    );
  }

  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime time;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    time: time,
    read: read ?? this.read,
  );
}

/// Notification store for the app.
///
/// For a signed-in account the list is fetched from the backend
/// (`/notification/...`, which first auto-generates real notifications from
/// the account's orders, wish list and followed organizers). Signed-out /
/// guest users fall back to a small in-memory sample list so the home page
/// badge and dropdown still render.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static String get baseUrl => ApiConfig.baseUrl;

  List<AppNotification> _items = _seed();
  int? _loadedForAccount;
  Timer? _pollTimer;
  http.Client? _sseClient;
  bool _realtimeEnabled = false;
  int? _realtimeForAccount;

  List<AppNotification> get items => List.unmodifiable(_items);

  List<AppNotification> get itemsNewestFirst {
    final list = List<AppNotification>.of(_items)
      ..sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  int get unreadCount => _items.where((n) => !n.read).length;

  /// Binds realtime + polling to the currently signed-in account and keeps
  /// them running for the whole app session (not tied to any widget). Safe to
  /// call repeatedly. Call [syncSession] after login, logout or account
  /// switch so the stream always serves the right account's notifications.
  void startRealtime() {
    final session = AuthService.currentSession;
    if (session == null) {
      _realtimeEnabled = false;
      return;
    }
    if (_realtimeForAccount != session.accountId) {
      // New session (or switched account). Tear down any stale stream bound
      // to the previous account/token before reconnecting.
      _sseClient?.close();
      _sseClient = null;
      _realtimeForAccount = session.accountId;
    }
    if (_realtimeEnabled && _sseClient != null)
      return; // already live for this account
    _realtimeEnabled = true;
    _connectSse();
  }

  void stopRealtime() {
    _realtimeEnabled = false;
    _realtimeForAccount = null;
    _loadedForAccount = null;
    _sseClient?.close();
    _sseClient = null;
  }

  /// App-wide lifecycle hook: starts / stops / rebinds realtime and polling to
  /// match the current auth session. Call it right after login, logout and
  /// session restore so home does not have to be reloaded to see updates.
  void syncSession() {
    final session = AuthService.currentSession;
    if (session == null) {
      stopRealtime();
      stopPolling();
      refresh(); // reseed for guests
      return;
    }
    final wasFor = _realtimeForAccount;
    startRealtime();
    startPolling();
    if (wasFor != session.accountId) {
      refresh(force: true); // new account -> fetch right away
    }
  }

  Future<void> _connectSse() async {
    final session = AuthService.currentSession;
    if (!_realtimeEnabled || session == null) return;
    if (_realtimeForAccount != null &&
        _realtimeForAccount != session.accountId) {
      return; // a different account now owns the stream; startRealtime rebinds
    }
    final client = http.Client();
    _sseClient = client;
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/notification/stream'),
    );
    final token = AuthService.currentToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw http.ClientException('SSE rejected: ${response.statusCode}');
      }
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!_realtimeEnabled) return;
        final unread = _parseUnreadCount(line);
        if (unread != null && unread != unreadCount) {
          await refresh(force: true);
        }
      }
    } catch (_) {
      // Stream dropped (network error or disconnect) -- schedule a reconnect.
    } finally {
      if (identical(_sseClient, client)) {
        _sseClient = null;
      }
    }
    if (_realtimeEnabled) {
      _scheduleSseReconnect();
    }
  }

  void _scheduleSseReconnect() {
    Timer(const Duration(seconds: 3), () {
      if (_realtimeEnabled && _sseClient == null) {
        _connectSse();
      }
    });
  }

  int? _parseUnreadCount(String sseLine) {
    const prefix = 'data:';
    if (!sseLine.startsWith(prefix)) return null;
    final payload = sseLine.substring(prefix.length).trim();
    if (payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return (map['UnreadCount'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Lightweight background poll so new backend notifications (e.g. an
  /// approval/denial result) show up without restarting the app. The poll
  /// only does a full refresh when the server-side unread count changes.
  void startPolling({Duration interval = const Duration(seconds: 20)}) {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    final session = AuthService.currentSession;
    if (session == null) return;
    if (_loadedForAccount != session.accountId) {
      await refresh(force: true);
      return;
    }
    try {
      await generateForAccount(session.accountId);
      final serverUnread = await getUnreadCount(session.accountId);
      if (serverUnread != unreadCount) {
        await refresh(force: true);
      }
    } catch (_) {}
  }

  /// Fetches the current user's notifications from the API (auto-generating
  /// them from real data first). Falls back to the sample list when signed
  /// out or when the request fails.
  ///
  /// Pass `force: true` to bypass the per-account cache (e.g. right after a
  /// new order is placed or when the notification page is opened).
  Future<void> refresh({bool force = false}) async {
    final session = AuthService.currentSession;
    if (session == null) {
      _items = _seed();
      _loadedForAccount = null;
      notifyListeners();
      return;
    }

    if (!force && _loadedForAccount == session.accountId) return;

    try {
      await generateForAccount(session.accountId);
      final list = await getByAccount(session.accountId);
      _items = list.isEmpty ? _seed() : list;
      _loadedForAccount = session.accountId;
      notifyListeners();
    } catch (_) {
      // Keep whatever we had (sample list or previous data).
    }
  }

  /// Marks one notification as read immediately and syncs it to the backend.
  void markRead(int id) {
    final session = AuthService.currentSession;
    if (session != null) {
      _fireAndForget(() => markReadOnServer(id));
    }
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1 || _items[index].read) return;
    _items[index] = _items[index].copyWith(read: true);
    notifyListeners();
  }

  void markAllRead() {
    final session = AuthService.currentSession;
    if (session != null) {
      _fireAndForget(() => markAllReadOnServer(session.accountId));
    }
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Runs a best-effort network call, swallowing failures so the UI never
  /// crashes on an unread notification tap.
  static Future<void> _fireAndForget(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  // ---------------- HTTP ----------------

  static Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (AuthService.currentToken != null) {
      headers['Authorization'] = 'Bearer ${AuthService.currentToken}';
    }
    return headers;
  }

  static Exception _handleError(http.Response response, String fallback) {
    if (response.statusCode == 401) {
      return Exception('Session expired. Please log in again.');
    }
    try {
      final error = jsonDecode(response.body);
      return Exception(error['detail']?.toString() ?? fallback);
    } catch (_) {
      return Exception(fallback);
    }
  }

  static Future<void> generateForAccount(int accountId) async {
    final url = Uri.parse('$baseUrl/notification/generate/$accountId');
    final response = await http.post(url, headers: _headers());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to generate notifications');
    }
  }

  static Future<List<AppNotification>> getByAccount(int accountId) async {
    final url = Uri.parse('$baseUrl/notification/account/$accountId');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to load notifications');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markReadOnServer(int notificationId) async {
    final url = Uri.parse('$baseUrl/notification/read/$notificationId');
    await http.put(url, headers: _headers());
  }

  static Future<void> markAllReadOnServer(int accountId) async {
    final url = Uri.parse('$baseUrl/notification/read-all/$accountId');
    await http.put(url, headers: _headers());
  }

  static Future<int> getUnreadCount(int accountId) async {
    final url = Uri.parse('$baseUrl/notification/unread/$accountId');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to load unread count');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['UnreadCount'] as int;
  }

  // ---------------- guest fallback ----------------

  static List<AppNotification> _seed() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: -1,
        type: 'order',
        title: 'Ticket confirmed',
        body: 'Your ticket for Rock Fest Vientiane has been confirmed.',
        time: now.subtract(const Duration(minutes: 6)),
      ),
      AppNotification(
        id: -2,
        type: 'event',
        title: 'Event starts soon',
        body: 'Food Fair Weekend starts today at 09:00.',
        time: now.subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: -3,
        type: 'wish',
        title: 'Price drop on your wish list',
        body: 'Laos Marathon tickets are now 10% cheaper.',
        time: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: -4,
        type: 'promo',
        title: 'Early bird sale',
        body: 'Get 20% off early bird tickets this week only.',
        time: now.subtract(const Duration(days: 1)),
      ),
      AppNotification(
        id: -5,
        type: 'system',
        title: 'Welcome to GAEA',
        body: 'Explore events near you and never miss out again.',
        time: now.subtract(const Duration(days: 3)),
        read: true,
      ),
    ];
  }
}
