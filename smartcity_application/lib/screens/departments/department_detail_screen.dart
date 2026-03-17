import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_strings.dart';

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

  static const _bgMap = {
    'police':         Color(0xFFEEF2FF),
    'traffic':        Color(0xFFFFF7ED),
    'construction':   Color(0xFFF0F9FF),
    'water':          Color(0xFFF0FDF4),
    'electricity':    Color(0xFFFFFBEB),
    'garbage':        Color(0xFFECFDF5),
    'road':           Color(0xFFFAF5FF),
    'drainage':       Color(0xFFEFF6FF),
    'illegal':        Color(0xFFFFF1F2),
    'transportation': Color(0xFFF0F9FF),
    'cyber':          Color(0xFFF5F3FF),
    'other':          Color(0xFFF8FAFC),
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

  bool get _hasRealData {
    final d = widget.department;
    // Has real data if any meaningful field is present (id means it came from API)
    return d['id'] != null ||
        (d['address'] ?? '').toString().isNotEmpty ||
        (d['phone'] ?? '').toString().isNotEmpty ||
        (d['email'] ?? '').toString().isNotEmpty ||
        (d['assigned_admin'] ?? '').toString().isNotEmpty ||
        (d['city'] ?? '').toString().isNotEmpty;
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
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${d.latitude},${d.longitude}&travelmode=driving');
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?daddr=${d.latitude},${d.longitude}');
    
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to browser
      await launchUrl(googleMapsUrl);
    }
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
    final bg = _bgMap[type] ?? const Color(0xFFF8FAFC);
    final name = (d['name'] ?? AppStrings.t(context, 'Department')).toString();
    final typeDisplay = AppStrings.t(context, (d['department_type_display'] ?? type).toString());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(children: [
          _topNav(emoji, bg, name, typeDisplay),
          Expanded(
            child: _hasRealData
                ? _detailBody(d, emoji, grads, bg)
                : _emptyState(emoji, bg, name, typeDisplay),
          ),
        ]),
      ),
    );
  }

  // ── Top nav ──────────────────────────────────────────────────────────────
  Widget _topNav(String emoji, Color bg, String name, String typeDisplay) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 8, right: 16, bottom: 12),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        // Full emoji in pastel box — no gradient bg
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(typeDisplay,
              style: GoogleFonts.inter(fontSize: 12, color: _textMuted)),
        ])),
      ]),
    );
  }

  // ── Empty state — no department added by admin yet ────────────────────────
  Widget _emptyState(String emoji, Color bg, String name, String typeDisplay) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),
        // Big emoji with pastel bg circle
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 60))),
        ),
        // Shadow below emoji
        Container(
          width: 60, height: 6,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 28),
        Text(AppStrings.t(context, 'No Department Found'),
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: _textDark)),
        const SizedBox(height: 8),
        Text('${AppStrings.t(context, 'The')} $name ${AppStrings.t(context, 'department has not been')}\n${AppStrings.t(context, 'set up by the admin yet.')}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: _textMuted, height: 1.5)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(children: [
            _infoRow('📋', AppStrings.t(context, 'Category'), typeDisplay),
            const SizedBox(height: 14),
            Divider(color: Colors.black.withOpacity(0.06), height: 1),
            const SizedBox(height: 14),
            _infoRow('🔔', AppStrings.t(context, 'Status'), AppStrings.t(context, 'Not yet configured')),
            const SizedBox(height: 14),
            Divider(color: Colors.black.withOpacity(0.06), height: 1),
            const SizedBox(height: 14),
            _infoRow('💡', AppStrings.t(context, 'Tip'), AppStrings.t(context, 'Contact admin to add this department')),
          ]),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(children: [
            const Text('ℹ️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Text(
                AppStrings.t(context, 'Once the admin adds this department, you\'ll see full details, contact info, and location here.'),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1D4ED8), height: 1.5))),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(String emoji, String label, String value) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
      ])),
    ]);
  }

  // ── Full detail body ──────────────────────────────────────────────────────
  Widget _detailBody(Map<String, dynamic> d, String emoji, List<Color> grads, Color bg) {
    final name = (d['name'] ?? AppStrings.t(context, 'Department')).toString();
    final city = (d['city'] ?? '').toString();
    final state = (d['state'] ?? '').toString();
    final address = (d['address'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final emailAddr = (d['email'] ?? '').toString();
    final assignedAdmin = (d['assigned_admin'] ?? d['admin_name'] ?? '').toString();
    final sla = (d['sla_hours'] ?? '').toString();

    return SingleChildScrollView(
      child: Column(children: [

        // ── Map ────────────────────────────────────────────────────────────
        SizedBox(
          height: 220,
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
                          boxShadow: [BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 10)],
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
                      ),
                      CustomPaint(size: const Size(12, 8), painter: _PinTail(colors: grads)),
                    ]),
                  ),
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
                              color: const Color(0xFF22C55E).withOpacity(0.4), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                ]),
              ],
            ),
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
                    Text(AppStrings.t(context, 'Locating...'), style: GoogleFonts.inter(fontSize: 11, color: _textDark)),
                  ]),
                ),
              ),
            Positioned(
              bottom: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _legendDot(const Color(0xFF22C55E), AppStrings.t(context, 'You')),
                  const SizedBox(height: 3),
                  _legendDot(_primary, AppStrings.t(context, 'Department')),
                ]),
              ),
            ),
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
                    Text(AppStrings.t(context, 'Directions'),
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Department header card ──────────────────────────────────
            _card(child: Row(children: [
              // Full emoji in pastel bg — no gradient box
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 34))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
                if (city.isNotEmpty || state.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748b)),
                    const SizedBox(width: 3),
                    Flexible(child: Text(
                        [city, state].where((s) => s.isNotEmpty).join(', '),
                        style: GoogleFonts.inter(fontSize: 12, color: _textMuted))),
                  ]),
                ],
              ])),
            ])),
            const SizedBox(height: 14),

            // ── Department details card ─────────────────────────────────
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppStrings.t(context, 'Department Details'),
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
              const SizedBox(height: 14),
              if (assignedAdmin.isNotEmpty) ...[
                _detailRow('👤', AppStrings.t(context, 'Assigned Admin'), assignedAdmin),
                const SizedBox(height: 12),
                Divider(color: Colors.black.withOpacity(0.06), height: 1),
                const SizedBox(height: 12),
              ],
              if (address.isNotEmpty) ...[
                _detailRow('📍', AppStrings.t(context, 'Address'), address),
                const SizedBox(height: 12),
                Divider(color: Colors.black.withOpacity(0.06), height: 1),
                const SizedBox(height: 12),
              ],
              if (city.isNotEmpty || state.isNotEmpty)
                _detailRow('🏙️', AppStrings.t(context, 'City / State'),
                    [city, state].where((s) => s.isNotEmpty).join(', ')),
              if (sla.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.black.withOpacity(0.06), height: 1),
                const SizedBox(height: 12),
                _detailRow('⏱️', AppStrings.t(context, 'Response Time'), '$sla ${AppStrings.t(context, 'hours')}'),
              ],
            ])),
            const SizedBox(height: 14),

            // ── Contact card ────────────────────────────────────────────
            if (phone.isNotEmpty || emailAddr.isNotEmpty) ...[
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.t(context, 'Contact Information'),
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 14),
                if (phone.isNotEmpty) ...[
                  _contactRow(Icons.phone_rounded, AppStrings.t(context, 'Phone Number'), phone,
                      const Color(0xFF22C55E), const Color(0xFFDCFCE7)),
                  if (emailAddr.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(color: Colors.black.withOpacity(0.06), height: 1),
                    const SizedBox(height: 10),
                  ],
                ],
                if (emailAddr.isNotEmpty)
                  _contactRow(Icons.email_outlined, AppStrings.t(context, 'Email Address'), emailAddr,
                      _primary, const Color(0xFFEFF6FF)),
              ])),
              const SizedBox(height: 14),

              // ── Action buttons ──────────────────────────────────────
              Row(children: [
                if (phone.isNotEmpty)
                  Expanded(child: _actionBtn(
                    icon: Icons.phone_rounded,
                    label: AppStrings.t(context, 'Call Now'),
                    color: const Color(0xFF22C55E),
                    onTap: () => _call(phone),
                  )),
                if (phone.isNotEmpty && emailAddr.isNotEmpty)
                  const SizedBox(width: 12),
                if (emailAddr.isNotEmpty)
                  Expanded(child: _actionBtn(
                    icon: Icons.email_rounded,
                    label: AppStrings.t(context, 'Send Email'),
                    color: _primary,
                    onTap: () => _email(emailAddr),
                  )),
              ]),
              const SizedBox(height: 12),
            ],

            // ── Directions button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openDirections,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: Text(AppStrings.t(context, 'Get Directions'),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primary,
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFe2e8f0), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _detailRow(String emoji, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
      ])),
    ]);
  }

  Widget _contactRow(IconData icon, String label, String value, Color iconColor, Color iconBg) {
    return Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: iconColor),
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
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
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
