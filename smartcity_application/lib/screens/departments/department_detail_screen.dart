import 'dart:ui' as ui;
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
  static const _primary = Color(0xFF1E66F5);
  static const _bg = Color(0xFFF8FAFC);
  static const _textDark = Color(0xFF0f172a);
  static const _textMuted = Color(0xFF64748b);

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

  static const _gradients = {
    'police':         [Color(0xFF667eea), Color(0xFF764ba2)],
    'traffic':        [Color(0xFFf093fb), Color(0xFFf5576c)],
    'construction':   [Color(0xFF4facfe), Color(0xFF00f2fe)],
    'water':          [Color(0xFF43e97b), Color(0xFF38f9d7)],
    'electricity':    [Color(0xFFfa709a), Color(0xFFfee140)],
    'garbage':        [Color(0xFF30cfd0), Color(0xFF330867)],
    'road':           [Color(0xFFa8edea), Color(0xFFfed6e3)],
    'drainage':       [Color(0xFFfbc2eb), Color(0xFFa6c1ee)],
    'illegal':        [Color(0xFFfdcbf1), Color(0xFFe6dee9)],
    'transportation': [Color(0xFFa1c4fd), Color(0xFFc2e9fb)],
    'cyber':          [Color(0xFFd299c2), Color(0xFFfef9d7)],
    'other':          [Color(0xFF89f7fe), Color(0xFF66a6ff)],
  };

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() { _userLocation = LatLng(pos.latitude, pos.longitude); _locating = false; });
        if (_mapReady) _fitBounds();
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  LatLng get _deptLatLng {
    final lat = double.tryParse(widget.department['latitude']?.toString() ?? '') ?? 20.5937;
    final lng = double.tryParse(widget.department['longitude']?.toString() ?? '') ?? 78.9629;
    return LatLng(lat, lng);
  }

  void _fitBounds() {
    if (_userLocation == null) { _mapCtrl.move(_deptLatLng, 14); return; }
    final bounds = LatLngBounds.fromPoints([_userLocation!, _deptLatLng]);
    _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  void _onMapReady() {
    _mapReady = true;
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _fitBounds(); });
  }

  Future<void> _openDirections() async {
    final d = _deptLatLng;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${d.latitude},${d.longitude}&travelmode=driving');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _email(String addr) async {
    final uri = Uri.parse('mailto:$addr');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.department;
    final type = (d['department_type'] ?? 'other').toString();
    final emoji = _emojiMap[type] ?? '🏢';
    final grads = _gradients[type] ?? [const Color(0xFF89f7fe), const Color(0xFF66a6ff)];
    final name = (d['name'] ?? 'Department').toString();
    final typeDisplay = (d['department_type_display'] ?? type).toString();
    final city = (d['city'] ?? '').toString();
    final state = (d['state'] ?? '').toString();
    final address = (d['address'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final emailAddr = (d['email'] ?? '').toString();
    final sla = (d['sla_hours'] ?? '').toString();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(children: [

          // ── Top nav — same white style as home ──────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 8, right: 16, bottom: 12),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
                onPressed: () => Navigator.pop(context),
              ),
              // Gradient emoji box — same as home dept grid
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: grads),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(typeDisplay,
                    style: GoogleFonts.inter(fontSize: 12, color: _primary)),
              ])),
            ]),
          ),

          Expanded(child: SingleChildScrollView(child: Column(children: [

            // ── Map ──────────────────────────────────────────────────────
            SizedBox(
              height: 240,
              child: Stack(children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _deptLatLng,
                    initialZoom: 13,
                    onMapReady: _onMapReady,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.janhelp.app',
                    ),
                    if (_userLocation != null)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [_userLocation!, _deptLatLng],
                          color: _primary,
                          strokeWidth: 3,
                          isDotted: true,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      // Department pin
                      Marker(
                        point: _deptLatLng,
                        width: 52, height: 60,
                        child: Column(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: grads),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [BoxShadow(
                                  color: _primary.withOpacity(0.4), blurRadius: 10)],
                            ),
                            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
                          ),
                          CustomPaint(
                              size: const Size(12, 8),
                              painter: _PinTail(colors: grads)),
                        ]),
                      ),
                      // User pin
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 40, height: 40,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [BoxShadow(
                                  color: const Color(0xFF22C55E).withOpacity(0.4),
                                  blurRadius: 8)],
                            ),
                            child: const Icon(Icons.my_location_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                    ]),
                  ],
                ),

                // Locating badge
                if (_locating)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E))),
                        const SizedBox(width: 6),
                        Text('Locating you...',
                            style: GoogleFonts.inter(fontSize: 11, color: _textDark)),
                      ]),
                    ),
                  ),

                // Legend
                Positioned(
                  bottom: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _legendDot(const Color(0xFF22C55E), 'Your Location'),
                      const SizedBox(height: 3),
                      _legendDot(_primary, 'Department'),
                    ]),
                  ),
                ),

                // Directions button
                Positioned(
                  bottom: 10, right: 10,
                  child: GestureDetector(
                    onTap: _openDirections,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: _primary, borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8)]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.directions_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                        Text('Directions',
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

                // Department info card
                _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: grads),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
                      Text(typeDisplay,
                          style: GoogleFonts.inter(fontSize: 13, color: _primary, fontWeight: FontWeight.w600)),
                    ])),
                  ]),
                  if (city.isNotEmpty || state.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _divider(),
                    const SizedBox(height: 12),
                    _detailRow(Icons.location_city_rounded, 'City / State',
                        [city, state].where((s) => s.isNotEmpty).join(', ')),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _detailRow(Icons.location_on_outlined, 'Address', address),
                  ],
                  if (sla.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _detailRow(Icons.timer_outlined, 'Response SLA', '$sla hours'),
                  ],
                ])),
                const SizedBox(height: 14),

                // Contact card
                if (phone.isNotEmpty || emailAddr.isNotEmpty)
                  _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Contact Information',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                    const SizedBox(height: 14),
                    if (phone.isNotEmpty) ...[
                      _contactRow(Icons.phone_rounded, 'Phone Number', phone),
                      if (emailAddr.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _divider(),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (emailAddr.isNotEmpty)
                      _contactRow(Icons.email_outlined, 'Email Address', emailAddr),
                  ])),

                const SizedBox(height: 14),

                // Action buttons — same style as home page buttons
                if (phone.isNotEmpty || emailAddr.isNotEmpty)
                  Row(children: [
                    if (phone.isNotEmpty)
                      Expanded(child: _actionBtn(
                        icon: Icons.phone_rounded,
                        label: 'Call Now',
                        color: const Color(0xFF22C55E),
                        onTap: () => _call(phone),
                      )),
                    if (phone.isNotEmpty && emailAddr.isNotEmpty)
                      const SizedBox(width: 12),
                    if (emailAddr.isNotEmpty)
                      Expanded(child: _actionBtn(
                        icon: Icons.email_rounded,
                        label: 'Send Email',
                        color: _primary,
                        onTap: () => _email(emailAddr),
                      )),
                  ]),

                const SizedBox(height: 12),

                // Get Directions full width
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openDirections,
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: Text('Get Directions in Google Maps',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _primary,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFe2e8f0), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ]))),
        ]),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: child,
    );
  }

  Widget _divider() => Divider(color: Colors.black.withOpacity(0.06), height: 1);

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: _textMuted),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
      ])),
    ]);
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
            color: const Color(0x1A1E66F5), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _primary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
      ])),
    ]);
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textMuted)),
    ]);
  }
}

class _PinTail extends CustomPainter {
  final List<Color> colors;
  const _PinTail({required this.colors});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colors.first;
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
