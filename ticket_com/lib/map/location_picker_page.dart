// lib/DeveloperPage/location_picker_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ticket_com/services/location_service.dart';

class LocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation;
  const LocationPickerPage({super.key, this.initialLocation});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late LatLng _pickedLocation;
  String? _pickedLabel;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation ?? kDefaultCenter;
    _refreshLabel();
  }

  Future<void> _refreshLabel() async {
    final resolved = await LocationService.reverseGeocode(_pickedLocation);
    if (!mounted) return;
    setState(() => _pickedLabel = resolved);
  }

  Future<void> _useMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    await LocationService.ensureResolved();
    final current = LocationService.position.value;
    if (!mounted) return;
    if (current == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not detect your location. Check GPS settings.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _pickedLocation = current);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Using your current location'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Pick Event Location',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () => Navigator.pop(context, _pickedLocation),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom: 14,
              onTap: (tapPosition, point) {
                setState(() => _pickedLocation = point);
                _refreshLabel();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.reservation_system', // match your app id
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pickedLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 88,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'picker-locate',
              onPressed: _useMyLocation,
              backgroundColor: Colors.black87,
              elevation: 4,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pickedLabel != null && _pickedLabel!.isNotEmpty)
                    Text(
                      _pickedLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (_pickedLabel != null && _pickedLabel!.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    'Lat: ${_pickedLocation.latitude.toStringAsFixed(6)}, '
                    'Lng: ${_pickedLocation.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
