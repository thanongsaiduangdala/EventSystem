import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps one unfinished "Create Event" form per account on this device, so an
/// organizer can save it without submitting and pick it up later. Nothing is
/// sent to the server (and nobody is notified) until the event is submitted.
///
/// Photos are not stored: they can be several MB each, which is too large for
/// local key/value storage.
class EventDraftStore {
  static String _key(int accountId) => 'event_form_draft_v1_$accountId';

  static Future<void> save(int accountId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(accountId), jsonEncode(data));
  }

  /// The saved draft, or null when there is none (or it can't be read).
  static Future<Map<String, dynamic>?> load(int accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(accountId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(accountId));
  }
}
