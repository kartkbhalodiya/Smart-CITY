import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class MapSelectionScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapSelectionScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  double _zoom = 13.0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      widget.initialLat ?? 20.5937,
      widget.initialLng ?? 78.9629,
    );
    
    // Zoom out effect animation logic after map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _mapController.move(_selectedLocation!, 15.0);
          setState(() {
            _zoom = 15.0;
            _ready = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_ready)
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedLocation),
              child: Text('CONFIRM', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5))),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation!,
              initialZoom: _zoom,
              onTap: (tapPosition, point) {
                setState(() => _selectedLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartcity.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation!,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 45),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tap on the map to select the incident location',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _selectedLocation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Confirm Location', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _mapController.move(_selectedLocation!, _mapController.camera.zoom + 1);
              },
              child: const Icon(Icons.add, color: Color(0xFF0F172A)),
            ),
          ),
          Positioned(
            top: 72,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _mapController.move(_selectedLocation!, _mapController.camera.zoom - 1);
              },
              child: const Icon(Icons.remove, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
