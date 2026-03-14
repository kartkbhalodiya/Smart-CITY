import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class DepartmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> department;
  const DepartmentDetailScreen({super.key, required this.department});
  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _accent = Color(0xFF1E66F5);

  LatLng? _userLocation;
  bool _locating = true;
  final MapController _mapCtrl = MapController();
  bool _mapReady = false;

  static const _emojiMap = {
    'police': '🚓', 'traffic': '🚦', 'construction': '🏗️',
    'water': '🚰', 'electricity': '💡', 'garbage': '🗑️',
    'road': '🛣️', 'drainage': '🌊', 'illegal': '⚠️',
    'transportation': '🚌', 'cyber': '🛡️', 'other': '📋',
  };

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _locating = false;
        });
        if (_mapReady) _fitBounds();
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  LatLng get _deptLocation {
    final lat = double.tryParse(widget.department['latitude']?.toString() ?? '') ?? 20.5937;
    final lng = double.tryParse(widget.department['longitude']?.toString() ?? '') ?? 78.9629;
    return LatLng(lat, lng);
  }

  void _fitBounds() {
    if (_userLocation == null) {
      _mapCtrl.move(_deptLocation, 14);
      return;
    }
    final bounds = LatLngBounds.fromPoints([_userLocation!, _deptLocation]);
    _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  void _onMapReady() {
    _mapReady = true;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fitBounds();
    });
  }

  Future<void> _openInMaps() async {
    final dept = _deptLocation;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${dept.latitude},${dept.longitude}&travelmode=driving');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _email(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.department;
    final type = (d['department_type'] ?? 'other').toString();
    final emoji = _emojiMap[type] ?? '🏢';
    final name = d['name'] ?? 'Department';
    final typeDisplay = d['department_type_display'] ?? type;
    final city = d['city'] ?? '';
    final state = d['state'] ?? '';
    final address = d['address'] ?? '';
    final phone = d['phone'] ?? '';
    final emailAddr = d['email'] ?? '';
    final sla = d['sla_hours']?.toString() ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Container(
            color: _card,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8, right: 16, bottom: 14),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(typeDisplay,
                    style: GoogleFonts.inter(fontSize: 12, color: _accent)),
              ])),
            ]),
          ),

          Expanded(child: SingleChildScrollView(children: [
            // ── Map ──────────────────────────────────────────────────────
            SizedBox(
              height: 260,
              child: Stack(children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _deptLocation,
                    initialZoom: 13,
                    onMapReady: _onMapReady,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.janhelp.app',
                    ),
                    // Route line (straight line between user and dept)
                    if (_userLocation != null)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [_userLocation!, _deptLocation],
                          color: _accent,
                          strokeWidth: 3.5,
                          isDotted: true,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      // Department marker
                      Marker(
                        point: _deptLocation,
                        width: 52, height: 60,
                        child: Column(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [BoxShadow(
                                  color: _accent.withOpacity(0.5), blurRadius: 10)],
                            ),
                            child: Center(
                                child: Text(emoji, style: const TextStyle(fontSize: 18))),
                          ),
                          CustomPaint(
                              size: const Size(12, 8),
                              painter: _PinTail(color: _accent)),
                        ]),
                      ),
                      // User location marker
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 44, height: 44,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [BoxShadow(
                                  color: const Color(0xFF22C55E).withOpacity(0.5),
                                  blurRadius: 10)],
                            ),
                            child: const Icon(Icons.my_location_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                    ]),
                  ],
                ),

                // Loading overlay
                if (_locating)
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF22C55E))),
                        const SizedBox(width: 8),
                        Text('Getting your location...',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                      ]),
                    ),
                  ),

                // Legend
                Positioned(
                  bottom: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _legendItem(const Color(0xFF22C55E), 'Your Location'),
                      const SizedBox(height: 3),
                      _legendItem(_accent, 'Department'),
                    ]),
                  ),
                ),

                // Open in Maps button
                Positioned(
                  bottom: 12, right: 12,
                  child: GestureDetector(
                    onTap: _openInMaps,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: _accent, borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.directions_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Get Directions',
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Details ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Name + type
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: _card, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(typeDisplay,
                            style: GoogleFonts.inter(fontSize: 13, color: _accent)),
                      ])),
                    ]),
                    if (city.isNotEmpty) ...[ 
                      const SizedBox(height: 12),
                      _infoRow(Icons.location_city_rounded, '$city, $state'),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoRow(Icons.location_on_outlined, address),
                    ],
                    if (sla.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoRow(Icons.timer_outlined, 'SLA: $sla hours response time'),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),

                // Contact card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: _card, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Contact',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 14),

                    if (phone.isNotEmpty) ...[
                      _contactRow(Icons.phone_rounded, phone, 'Phone'),
                      const SizedBox(height: 10),
                    ],
                    if (emailAddr.isNotEmpty)
                      _contactRow(Icons.email_outlined, emailAddr, 'Email'),

                    if (phone.isEmpty && emailAddr.isEmpty)
                      Text('No contact info available',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
                  ]),
                ),
                const SizedBox(height: 14),

                // Action buttons
                if (phone.isNotEmpty || emailAddr.isNotEmpty)
                  Row(children: [
                    if (phone.isNotEmpty)
                      Expanded(child: _actionBtn(
                        '📞', 'Call Now', const Color(0xFF22C55E),
                        () => _call(phone),
                      )),
                    if (phone.isNotEmpty && emailAddr.isNotEmpty)
                      const SizedBox(width: 12),
                    if (emailAddr.isNotEmpty)
                      Expanded(child: _actionBtn(
                        '✉️', 'Send Email', _accent,
                        () => _email(emailAddr),
                      )),
                  ]),

                const SizedBox(height: 14),

                // Directions button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _openInMaps,
                    icon: const Icon(Icons.directions_rounded, size: 20),
                    label: Text('Get Directions in Google Maps',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
    ]);
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: Colors.white38),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70))),
    ]);
  }

  Widget _contactRow(IconData icon, String value, String label) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: _accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 16, color: _accent),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      ])),
    ]);
  }

  Widget _actionBtn(String emoji, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  final Color color;
  const _PinTail({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}
