import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _primary = Color(0xFF1E66F5);

  late LatLng _pickedLocation;
  final MapController _mapController = MapController();
  bool _mapLoading = true;
  bool _gettingAddress = false;
  String _addressText = 'Tap on map or drag pin to select location';

  @override
  void initState() {
    super.initState();
    // Default to India center if no initial location
    _pickedLocation = LatLng(
      widget.initialLat ?? 20.5937,
      widget.initialLng ?? 78.9629,
    );
    // Simulate map tile load delay
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _mapLoading = false);
    });
    if (widget.initialLat != null) _fetchAddress(_pickedLocation);
  }

  Future<void> _fetchAddress(LatLng pos) async {
    setState(() => _gettingAddress = true);
    final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
    if (mounted) {
      setState(() {
        _addressText = addr['address']!.isNotEmpty ? addr['address']! : 'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}';
        _gettingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom: widget.initialLat != null ? 15.0 : 5.0,
              onTap: (_, latlng) {
                setState(() => _pickedLocation = latlng);
                _fetchAddress(latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.janhelp.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pickedLocation,
                    width: 48,
                    height: 56,
                    child: Column(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 18),
                        ),
                        CustomPaint(size: const Size(12, 8), painter: _PinTailPainter()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Loading overlay
          if (_mapLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 56, height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation(_primary),
                        backgroundColor: _primary.withOpacity(0.15),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Loading Map...', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
                    const SizedBox(height: 6),
                    Text('Please wait', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
                  ],
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0f172a)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
                      ),
                      child: Text(
                        'Pick Location on Map',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom confirm panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: const Color(0xFFe2e8f0), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.location_pin, color: _primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _gettingAddress
                          ? Row(children: [
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
                              const SizedBox(width: 8),
                              Text('Getting address...', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
                            ])
                          : Text(_addressText, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a)), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(
                      'Lat: ${_pickedLocation.latitude.toStringAsFixed(6)},  Lng: ${_pickedLocation.longitude.toStringAsFixed(6)}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94a3b8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, _pickedLocation),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text('Confirm Location', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
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

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E66F5);
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
