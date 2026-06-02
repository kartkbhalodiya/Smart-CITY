import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;
  final void Function(LatLng) onLocationSelected;

  const LocationPickerDialog({
    Key? key,
    this.initialLocation,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> with TickerProviderStateMixin {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  bool _isLocating = false;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? LatLng(23.0225, 72.5714); // Default: Ahmedabad
    
    // Automatically fetch current location on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentLocation();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        
        final newLoc = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLocation = newLoc;
          _isLocating = false;
        });

        // Smoothly zoom in to the detected location
        _animatedMapMove(newLoc, 16.5);
      } else {
        setState(() => _isLocating = false);
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
      setState(() => _isLocating = false);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.zoom, end: destZoom);

    final controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    final Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 350,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Select Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _selectedLocation,
                      zoom: 14.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.janhelp.smartcity',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40,
                            height: 40,
                            point: _selectedLocation,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isLocating)
                    Container(
                      color: Colors.black.withOpacity(0.1),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.red),
                            SizedBox(height: 12),
                            Text('Locating you...', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: _fetchCurrentLocation,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Return the selected location map to the caller
                      Navigator.of(context).pop({
                        'lat': _selectedLocation.latitude,
                        'lng': _selectedLocation.longitude,
                        'address': 'Map Selection',
                      });
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
