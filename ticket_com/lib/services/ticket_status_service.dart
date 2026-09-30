import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

/// Check-in state of one ticket, as reported by the server.
class TicketCheckInStatus {
  const TicketCheckInStatus({required this.attendeeId, this.checkedInAt});

  final int attendeeId;

  /// When staff scanned the ticket in; null while it has not been scanned.
  final DateTime? checkedInAt;

  bool get isCheckedIn => checkedInAt != null;
}

/// A change pushed by the server.
///
/// [isSnapshot] is true for the full state sent right after connecting
/// (replace whatever you had); false for a single live change (patch it in).
class TicketStatusUpdate {
  const TicketStatusUpdate({required this.tickets, required this.isSnapshot});

  final List<TicketCheckInStatus> tickets;
  final bool isSnapshot;
}

/// Live check-in status for the signed-in user's tickets to one event.
///
/// Opens a WebSocket to `/ticketattendence/ws/my-tickets`, authenticates with
/// the session JWT, and emits a [TicketStatusUpdate] whenever staff scan a
/// ticket in (or undo it). Reconnects with backoff if the connection drops,
/// and every reconnect starts with a fresh snapshot so nothing is missed.
class TicketStatusService {
  TicketStatusService({required this.eventId});

  final int eventId;

  static const int _closeUnauthorized = 4401;

  final StreamController<TicketStatusUpdate> _updates =
      StreamController<TicketStatusUpdate>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _disposed = false;

  Stream<TicketStatusUpdate> get updates => _updates.stream;

  /// Starts (or restarts) the connection. Does nothing if not logged in.
  void connect() {
    if (_disposed) return;
    final token = AuthService.currentToken;
    if (token == null) return;

    _teardown();
    try {
      final channel = WebSocketChannel.connect(_uri());
      _channel = channel;

      // Authentication is the first frame (not a URL parameter) so the JWT
      // never lands in server access logs.
      channel.sink.add(
        jsonEncode({'type': 'auth', 'token': token, 'eventID': eventId}),
      );

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
      path: '$path/ticketattendence/ws/my-tickets',
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
      case 'snapshot':
        _attempt = 0; // connection is healthy again
        final list = (msg['tickets'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_parseTicket)
            .whereType<TicketCheckInStatus>()
            .toList();
        _emit(TicketStatusUpdate(tickets: list, isSnapshot: true));
        break;
      case 'checked_in':
      case 'check_in_cancelled':
        final ticket = _parseTicket(msg);
        if (ticket == null) return;
        _emit(TicketStatusUpdate(tickets: [ticket], isSnapshot: false));
        break;
    }
  }

  static TicketCheckInStatus? _parseTicket(Map<String, dynamic> json) {
    final id = json['attendeeID'];
    if (id is! num) return null;
    final at = json['checkedInAt'];
    return TicketCheckInStatus(
      attendeeId: id.toInt(),
      checkedInAt: at is String ? DateTime.tryParse(at) : null,
    );
  }

  void _emit(TicketStatusUpdate update) {
    if (!_disposed && !_updates.isClosed) _updates.add(update);
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
    _updates.close();
  }
}
