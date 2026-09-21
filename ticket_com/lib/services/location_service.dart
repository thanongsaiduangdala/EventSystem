import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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

  /// Human-readable label (place, city, province, ...) for the current
  /// location, resolved via reverse geocoding. Null until one is known.
  static final ValueNotifier<String?> label = ValueNotifier<String?>(null);

  static const String _prefsKey = 'user_location';
  static const String _prefsKeyLabel = 'user_location_label';
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
      final labelRaw = prefs.getString(_prefsKeyLabel);
      if (labelRaw != null && labelRaw.isNotEmpty) label.value = labelRaw;
    } catch (_) {}
  }

  /// Current known location, or the Vientiane default when nothing is
  /// known yet (first launch / permissions denied / no GPS).
  static LatLng get currentOrFallback => position.value ?? kDefaultCenter;

  /// Sets [target] as the user location (manual pick or GPS fix), persists
  /// it so the next launch starts there, and kicks off reverse geocoding to
  /// fill [label] with a readable place name.
  static Future<void> setPosition(LatLng target) async {
    position.value = target;
    label.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, '${target.latitude},${target.longitude}');
    } catch (_) {}
    _resolveLabel(target);
  }

  /// Reverse geocodes [target] via OpenStreetMap's Nominatim, returning a
  /// readable "place, city, province" label, or null when unavailable.
  static Future<String?> reverseGeocode(LatLng target) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse')
          .replace(
            queryParameters: {
              'lat': target.latitude.toStringAsFixed(6),
              'lon': target.longitude.toStringAsFixed(6),
              'format': 'jsonv2',
              'accept-language': 'en',
            },
          );
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'reservation_system_flutter/1.0'},
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return _labelFromAddress(data['address'] as Map<String, dynamic>?);
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocodes [target] and stores the resulting label. Best effort:
  /// never throws, silently leaves [label] null when unavailable.
  static Future<void> _resolveLabel(LatLng target) async {
    final resolved = await reverseGeocode(target);
    if (resolved == null || resolved.isEmpty) return;
    label.value = resolved;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyLabel, resolved);
    } catch (_) {}
  }

  /// Builds a compact "name, place, city, province, country" label from the
  /// address object Nominatim returns, using the most specific fields first.
  static String _labelFromAddress(Map<String, dynamic>? address) {
    if (address == null) return '';
    const order = [
      'attraction', 'shop', 'amenity', 'tourism', 'building',
      'pedestrian', 'road',
      'neighbourhood', 'suburb', 'quarter',
      'city', 'town', 'village', 'county', 'municipality',
      'state', 'province', 'region', 'country',
    ];
    final parts = <String>[];
    for (final key in order) {
      final v = address[key]?.toString();
      if (v != null && v.isNotEmpty && !parts.contains(v)) parts.add(v);
    }
    if (parts.length > 4) parts.removeRange(4, parts.length);
    return parts.join(', ');
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