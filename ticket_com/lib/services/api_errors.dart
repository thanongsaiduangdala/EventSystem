import 'dart:convert';
import 'package:http/http.dart' as http;

/// Message for an HTTP 403. The backend says exactly which permission is
/// missing (e.g. "Permission 'manage_ticket_types' required"), so show that
/// instead of a generic "Developer access required." -- organizers hit these
/// endpoints too, and the old text sent them looking in the wrong place.
String forbiddenMessage(http.Response response) {
  try {
    final body = jsonDecode(response.body);
    final detail = body is Map ? body['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;
  } catch (_) {
    // fall through to the generic message
  }
  return 'You do not have permission for this action.';
}
