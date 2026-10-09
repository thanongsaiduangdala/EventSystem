import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

/// Something about an event / organization approval changed on the server.
///
/// [isResync] is true right after the socket reconnects: changes may have been
/// missed while it was down, so the screen should simply re-fetch its list.
class ReviewChange {
  const ReviewChange({
    required this.kind,
    this.id,
    this.statusId,
    this.denyReason,
    this.isResync = false,
  });

  /// 'event' or 'organization' (empty for a resync).
  final String kind;
  final int? id;
  final int? statusId;
  final String? denyReason;
  final bool isResync;

  bool get isEvent => kind == 'event';
  bool get isOrganization => kind == 'organization';
}

/// Live approval changes.
///
/// Opens a WebSocket to `/review/ws`, authenticates with the session JWT and
/// emits a [ReviewChange] whenever an event or organization is submitted,
/// approved, denied or resubmitted. Employees / superadmins get every change;
/// an organizer only gets changes to their own organization and events.
/// Reconnects with backoff, and tells listeners to re-fetch after a reconnect.
class ReviewLiveService {
  ReviewLiveService();

  static const int _closeUnauthorized = 4401;

  final StreamController<ReviewChange> _changes =
      StreamController<ReviewChange>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _disposed = false;
  bool _hasConnectedBefore = false;

  Stream<ReviewChange> get changes => _changes.stream;

  /// Starts (or restarts) the connection. Does nothing if not logged in.
  void connect() {
    if (_disposed) return;
    final token = AuthService.currentToken;
    if (token == null) return;

    _teardown();
    try {
      final channel = WebSocketChannel.connect(_uri());
      _channel = channel;

      // The JWT goes in the first frame, not the URL, so it never lands in
      // server access logs.
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));

      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (channel.closeCode == _closeUnauthorized) return; // don't retry
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          channel.sink.add('ping');
        } catch (_) {}
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Uri _uri() {
    final base = Uri.parse(ApiConfig.baseUrl);
    final path = base.path.replaceAll(RegExp(r'/+$'), '');
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '$path/review/ws',
    );
  }

  void _onMessage(dynamic raw) {
    if (raw is! String || raw == 'pong') return;

    Map<String, dynamic>? msg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) msg = decoded;
    } catch (_) {}
    if (msg == null) return;

    switch (msg['type']) {
      case 'ready':
        _attempt = 0; // connection is healthy again
        if (_hasConnectedBefore) {
          _emit(const ReviewChange(kind: '', isResync: true));
        }
        _hasConnectedBefore = true;
        break;
      case 'review_changed':
        final id = msg['id'];
        final statusId = msg['statusID'];
        final reason = msg['denyReason'];
        _emit(ReviewChange(
          kind: msg['kind']?.toString() ?? '',
          id: id is num ? id.toInt() : null,
          statusId: statusId is num ? statusId.toInt() : null,
          denyReason: reason is String ? reason : null,
        ));
        break;
    }
  }

  void _emit(ReviewChange change) {
    if (!_disposed && !_changes.isClosed) _changes.add(change);
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_reconnectTimer?.isActive ?? false) return;
    _teardown();
    final seconds = math.min(15, 1 << math.min(_attempt, 4)); // 1,2,4,8,15
    _attempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  void _teardown() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _teardown();
    _changes.close();
  }
}
