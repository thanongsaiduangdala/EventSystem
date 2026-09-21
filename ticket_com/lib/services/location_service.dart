import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default map center / fallback location (Vientiane).
const LatLng kDefaultCenter = LatLng(17.9757, 102.6331);

/// Single shared holder for the user's current location. Grab the latest
/// value with [LocationService.currentOrFallback] or listen to [position]
/// to react (map markers, distance filters, location label) whenever it
/// changes from GPS or a manual pick.
class LocationService {
  LocationService._();

  static final ValueNotifier<LatLng?> position = ValueNotifier<LatLng?>(null);

  static const String _prefsKey = 'user_location';
  static bool _restored = false;

  /// Restores the last saved location (instant, no GPS needed) and then
  /// tries to resolve the real GPS fix. Safe to call more than once.
  static Future<void> ensureResolved() async {
    await _restoreStored();
    await determineCurrentPosition();
  }

  static Future<void> _restoreStored() async {
    if (_restored) return;
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final parts = raw.split(',');
      if (parts.length != 2) return;
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat == null || lng == null) return;
      position.value = LatLng(lat, lng);
    } catch (_) {}
  }

  /// Current known location, or the Vientiane default when nothing is
  /// known yet (first launch / permissions denied / no GPS).
  static LatLng get currentOrFallback => position.value ?? kDefaultCenter;

  /// Sets [target] as the user location (manual pick or GPS fix) and
  /// persists it so the next launch starts there.
  static Future<void> setPosition(LatLng target) async {
    position.value = target;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, '${target.latitude},${target.longitude}');
    } catch (_) {}
  }

  /// Asks the OS for the current GPS position. Updates [position] and the
  /// persisted value once a fix arrives. Returns null when unavailable.
  static Future<LatLng?> determineCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      await setPosition(target);
      return target;
    } catch (_) {
      return null;
    }
  }
}