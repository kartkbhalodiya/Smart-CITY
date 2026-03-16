import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 0.5;

    // Draw subtle grid pattern like real maps
    for (int i = 0; i < size.width; i += 30) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }
    for (int i = 0; i < size.height; i += 30) {
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2B6CF6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapLoadingOverlay extends StatefulWidget {
  @override
  State<_MapLoadingOverlay> createState() => _MapLoadingOverlayState();
}

class _MapLoadingOverlayState extends State<_MapLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        color: const Color(0xFFE8F0FE).withOpacity(0.92),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _pulse.value,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E66F5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E66F5).withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: _pulse.value,
                child: Text(
                  AppStrings.t(context, 'Loading map…'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E66F5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserTrackComplaintDetail extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const UserTrackComplaintDetail({Key? key, required this.complaint}) : super(key: key);

  @override
  State<UserTrackComplaintDetail> createState() => _UserTrackComplaintDetailState();
}

class _UserTrackComplaintDetailState extends State<UserTrackComplaintDetail> {
  bool _showReopenDialog = false;
  final _reopenReasonController = TextEditingController();
  final _ratingController = TextEditingController();
  final _commentController = TextEditingController();
  String? _selectedProofPath;
  int _selectedRating = 0;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmittingRating = false;
  bool _isSubmittingReopen = false;
  final MapController _mapController = MapController();
  double _currentZoom = 13.0;
  bool _mapLoaded = false;

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    
    // Debug print to check if complaint data is received
    print('UserTrackComplaintDetail - Complaint data received: $complaint');
    
    final isSolved = complaint['work_status'] == 'solved';
    final canReopen = complaint['can_reopen'] == true || _canReopenComplaint(complaint);
    final hasRating = complaint['citizen_rating'] != null;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          complaint.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(AppStrings.t(context, 'No complaint data available'), style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildMapAppBar(complaint),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildComplaintTitleCard(complaint),
                            if (complaint['assigned_department'] != null)
                              _buildDepartmentDetailsCard(complaint['assigned_department']),
                            _buildStatusTimeline(complaint),
                            _buildComplaintDetailsCard(complaint),
                            _buildPersonalDetailsCard(complaint),
                            if (isSolved && !hasRating)
                              _buildRatingSection(complaint),
                            if (hasRating)
                              _buildExistingRatingCard(complaint),
                            if (canReopen)
                              _buildReopenSection(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          // Reopen Dialog — centered modal
          if (_showReopenDialog)
            GestureDetector(
              onTap: () => setState(() => _showReopenDialog = false),
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: _buildReopenDialog(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapAppBar(Map<String, dynamic> complaint) {
    final lat = (complaint['latitude'] ?? 0.0) is double
        ? complaint['latitude'] ?? 0.0
        : double.tryParse(complaint['latitude'].toString()) ?? 0.0;
    final lng = (complaint['longitude'] ?? 0.0) is double
        ? complaint['longitude'] ?? 0.0
        : double.tryParse(complaint['longitude'].toString()) ?? 0.0;

    final dept = complaint['assigned_department'];
    final deptLat = dept != null
        ? ((dept['latitude'] ?? 0.0) is double
            ? dept['latitude'] ?? 0.0
            : double.tryParse(dept['latitude'].toString()) ?? 0.0)
        : 0.0;
    final deptLng = dept != null
        ? ((dept['longitude'] ?? 0.0) is double
            ? dept['longitude'] ?? 0.0
            : double.tryParse(dept['longitude'].toString()) ?? 0.0)
        : 0.0;

    final hasComplaintCoords = lat != 0.0 && lng != 0.0;
    final hasDeptCoords = deptLat != 0.0 && deptLng != 0.0;

    // Build points list for bounds fitting
    final points = <LatLng>[
      if (hasComplaintCoords) LatLng(lat, lng),
      if (hasDeptCoords) LatLng(deptLat, deptLng),
    ];

    // Fallback center if no coords
    final center = points.isNotEmpty
        ? LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
            points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
          )
        : const LatLng(20.5937, 78.9629);

    final distance = hasDeptCoords && hasComplaintCoords
        ? _calculateDistance(lat, lng, deptLat, deptLng)
        : 0.0;

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: points.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(80),
                      maxZoom: 14,
                    )
                  : null,
              initialCenter: points.length == 1 ? points.first : center,
              initialZoom: points.length == 1 ? 14 : 13,
              onMapReady: () {
                _currentZoom = points.length == 1 ? 14.0 : 13.0;
                if (points.length > 1) {
                  Future.microtask(() {
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(80),
                        maxZoom: 14,
                      ),
                    );
                    _currentZoom = _mapController.camera.zoom;
                  });
                }
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted) setState(() => _mapLoaded = true);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.janhelp.app',
              ),
              // Road line complaint → department (white border + blue fill)
              if (hasComplaintCoords && hasDeptCoords)
                PolylineLayer(polylines: [
                  // White border (road casing)
                  Polyline(
                    points: [LatLng(lat, lng), LatLng(deptLat, deptLng)],
                    color: Colors.white,
                    strokeWidth: 7.0,
                  ),
                  // Blue road fill
                  Polyline(
                    points: [LatLng(lat, lng), LatLng(deptLat, deptLng)],
                    color: const Color(0xFF1E66F5),
                    strokeWidth: 4.0,
                  ),
                ]),
              MarkerLayer(markers: [
                // Complaint marker (red)
                if (hasComplaintCoords)
                  Marker(
                    point: LatLng(lat, lng),
                    width: 44,
                    height: 52,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                          ),
                          child: const Icon(Icons.report, color: Colors.white, size: 12),
                        ),
                        const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 28),
                      ],
                    ),
                  ),
                // Department marker (blue)
                if (hasDeptCoords)
                  Marker(
                    point: LatLng(deptLat, deptLng),
                    width: 44,
                    height: 52,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E66F5),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                          ),
                          child: const Icon(Icons.business, color: Colors.white, size: 12),
                        ),
                        const Icon(Icons.location_on, color: Color(0xFF1E66F5), size: 28),
                      ],
                    ),
                  ),
              ]),
            ],
          ),

          // Loading overlay
          if (!_mapLoaded)
            Positioned.fill(
              child: _MapLoadingOverlay(),
            ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF374151), size: 20),
                ),
              ),
            ),
          ),

          // Zoom + direct navigation buttons (right side)
          Positioned(
            top: 60,
            right: 10,
            child: Column(
              children: [
                // Zoom In
                _mapBtn(
                  icon: Icons.add,
                  onTap: () {
                    _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  },
                ),
                const SizedBox(height: 6),
                // Zoom Out
                _mapBtn(
                  icon: Icons.remove,
                  onTap: () {
                    _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  },
                ),
                const SizedBox(height: 10),
                // Go to Complaint
                if (hasComplaintCoords)
                  _mapBtn(
                    icon: Icons.report,
                    color: const Color(0xFFEF4444),
                    tooltip: AppStrings.t(context, 'Complaint'),
                    onTap: () => _mapController.move(LatLng(lat, lng), 15),
                  ),
                if (hasComplaintCoords) const SizedBox(height: 6),
                // Go to Department
                if (hasDeptCoords)
                  _mapBtn(
                    icon: Icons.business,
                    color: const Color(0xFF1E66F5),
                    tooltip: AppStrings.t(context, 'Department'),
                    onTap: () => _mapController.move(LatLng(deptLat, deptLng), 15),
                  ),
                if (hasDeptCoords && hasComplaintCoords) const SizedBox(height: 6),
                // Fit both
                if (hasComplaintCoords && hasDeptCoords)
                  _mapBtn(
                    icon: Icons.fit_screen,
                    tooltip: AppStrings.t(context, 'Fit both'),
                    onTap: () {
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(points),
                          padding: const EdgeInsets.all(80),
                          maxZoom: 14,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Legend + distance bottom bar
          Positioned(
            bottom: 10, left: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  _legendDot(const Color(0xFFEF4444), AppStrings.t(context, 'Complaint')),
                  const SizedBox(width: 12),
                  if (hasDeptCoords) _legendDot(const Color(0xFF1E66F5), AppStrings.t(context, 'Department')),
                  const Spacer(),
                  if (distance > 0)
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E66F5)),
                    ),
                  if (hasDeptCoords) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _getDirections(deptLat, deptLng),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E66F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(AppStrings.t(context, 'Directions'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
    ]);
  }

  Widget _mapBtn({required IconData icon, required VoidCallback onTap, Color? color, String? tooltip}) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
          ),
          child: Icon(icon, size: 18, color: color != null ? Colors.white : const Color(0xFF374151)),
        ),
      ),
    );
  }
  
  Widget _buildComplaintTitleCard(Map<String, dynamic> complaint) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.report_problem,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint['title']?.isNotEmpty == true
                          ? complaint['title'].toString().toUpperCase()
                          : AppStrings.t(context, 'Complaint Details').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subcategory Section
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${complaint['complaint_type']?.toString().toUpperCase() ?? AppStrings.t(context, 'General').toUpperCase()} ${AppStrings.t(context, 'Complaint').toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${complaint['city'] ?? AppStrings.t(context, 'Unknown')}, ${complaint['state'] ?? AppStrings.t(context, 'Unknown')}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildStatusBadge(complaint['work_status'] ?? 'unknown'),
                  const SizedBox(height: 8),
                  Text(
                    '#${complaint['complaint_number'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMapSection(Map<String, dynamic> complaint) {
    final lat = complaint['latitude'] ?? 0.0;
    final lng = complaint['longitude'] ?? 0.0;
    final deptLat = complaint['assigned_department']?['latitude'] ?? 0.0;
    final deptLng = complaint['assigned_department']?['longitude'] ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B6CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.map,
                    color: Color(0xFF2B6CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Interactive Map'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'Tap and drag to explore locations'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                // Map Controls
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openMap(lat != 0.0 ? lat : 28.6139, lng != 0.0 ? lng : 77.2090),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showFullScreenMap(complaint),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B6CF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Interactive Map View
          Container(
            height: 300,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Interactive Map Background
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE0F2FE),
                          Color(0xFFBAE6FD),
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _MapPatternPainter(),
                      child: Stack(
                        children: [
                          // Draggable Complaint Location Marker
                          Positioned(
                            top: 100,
                            left: 150,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                // Allow dragging the marker (for demo purposes)
                                setState(() {});
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      AppStrings.t(context, 'Complaint Location'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(
                                    Icons.location_on,
                                    color: Color(0xFFEF4444),
                                    size: 36,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Department Location Marker
                          if (deptLat != 0.0 && deptLng != 0.0)
                            Positioned(
                              top: 140,
                              right: 100,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      AppStrings.t(context, 'Department'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(
                                    Icons.business,
                                    color: Color(0xFF10B981),
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          // Interactive Roads/Streets
                          Positioned(
                            top: 120,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 170,
                            child: Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(1, 0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Zoom Controls
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _zoomIn,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Color(0xFF374151),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _zoomOut,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      color: Color(0xFF374151),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Location Info Overlay
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_city,
                                        size: 18,
                                        color: Color(0xFF6B7280),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${complaint['city'] ?? '-'}, ${complaint['state'] ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (lat != 0.0 && lng != 0.0) ...[
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.gps_fixed,
                                          size: 16,
                                          color: Color(0xFF6B7280),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${AppStrings.t(context, 'Lat')}: ${lat.toStringAsFixed(4)}, ${AppStrings.t(context, 'Lng')}: ${lng.toStringAsFixed(4)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.gps_off,
                                          size: 16,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppStrings.t(context, 'GPS coordinates not available'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _openMap(lat != 0.0 ? lat : 28.6139, lng != 0.0 ? lng : 77.2090),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2B6CF6),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.open_in_new,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  AppStrings.t(context, 'Open in Maps'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _getDirections(lat, lng),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.directions,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  AppStrings.t(context, 'Directions'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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





  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'confirmed':
        color = Colors.blue;
        text = 'Confirmed';
        break;
      case 'process':
        color = Colors.purple;
        text = 'In Progress';
        break;
      case 'solved':
        color = Colors.green;
        text = 'Solved';
        break;
      case 'reopened':
        color = Colors.red;
        text = 'Reopened';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        AppStrings.t(context, text),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'process': return 'In Progress';
      case 'solved': return 'Solved';
      case 'reopened': return 'Reopened';
      default: return status;
    }
  }

  void _openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _makeCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _sendEmail(String email) async {
    final url = 'mailto:$email';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Widget _buildStatusTimeline(Map<String, dynamic> complaint) {
    final status = complaint['work_status'] ?? 'pending';
    final createdAt = complaint['created_at'] ?? '';
    
    // Dynamic steps based on status
    List<Map<String, dynamic>> steps = [
      {
        'key': 'pending',
        'title': AppStrings.t(context, 'Submitted'),
        'subtitle': AppStrings.t(context, 'Complaint received'),
        'icon': Icons.assignment_turned_in,
        'color': const Color(0xFFEAB308),
        'time': _formatDateTime(createdAt),
      },
    ];
    
    // Add steps based on current status
    if (status == 'rejected') {
      steps.add({
        'key': 'rejected',
        'title': AppStrings.t(context, 'Rejected'),
        'subtitle': AppStrings.t(context, 'Complaint rejected'),
        'icon': Icons.cancel,
        'color': const Color(0xFFEF4444),
        'time': _getStatusTime(status, 'rejected'),
      });
    } else {
      steps.addAll([
        {
          'key': 'confirmed',
          'title': AppStrings.t(context, 'Confirmed'),
          'subtitle': AppStrings.t(context, 'Under review'),
          'icon': Icons.verified,
          'color': const Color(0xFF3B82F6),
          'time': _getStatusTime(status, 'confirmed'),
        },
        {
          'key': 'process',
          'title': AppStrings.t(context, 'In Progress'),
          'subtitle': AppStrings.t(context, 'Being resolved'),
          'icon': Icons.engineering,
          'color': const Color(0xFF8B5CF6),
          'time': _getStatusTime(status, 'process'),
        },
        {
          'key': 'solved',
          'title': AppStrings.t(context, 'Resolved'),
          'subtitle': AppStrings.t(context, 'Complaint solved'),
          'icon': Icons.check_circle,
          'color': const Color(0xFF10B981),
          'time': _getStatusTime(status, 'solved'),
        },
      ]);
    }
    
    // Add reopened step if status is reopened
    if (status == 'reopened') {
      steps.add({
        'key': 'reopened',
        'title': AppStrings.t(context, 'Reopened'),
        'subtitle': AppStrings.t(context, 'Complaint reopened for review'),
        'icon': Icons.refresh,
        'color': const Color(0xFFFF6B35),
        'time': _getStatusTime(status, 'reopened'),
      });
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.timeline,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Progress Timeline'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'Track your complaint status'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isCompleted = _isStepCompleted(step['key'] as String, status);
              final isActive = step['key'] == status;
              final isLast = index == steps.length - 1;
              
              return _buildTimelineStep(
                step: step,
                isCompleted: isCompleted,
                isActive: isActive,
                isLast: isLast,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimelineStep({
    required Map<String, dynamic> step,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    final color = step['color'] as Color;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted || isActive ? color : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted || isActive ? color : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: Icon(
                  step['icon'] as IconData,
                  color: isCompleted || isActive ? Colors.white : Colors.grey[600],
                  size: 16,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: isCompleted ? color : Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCompleted || isActive
                            ? const Color(0xFF1F2937)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (step['time'] != null && step['time'] != '')
                      Text(
                        step['time'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isCompleted || isActive
                              ? color
                              : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  step['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted || isActive
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintDetailsCard(Map<String, dynamic> complaint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Complaint Details'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'Complete information'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailItem(
              icon: Icons.title,
              label: AppStrings.t(context, 'Title'),
              value: complaint['title'] ?? AppStrings.t(context, 'No title'),
              color: const Color(0xFF3B82F6),
            ),
            _buildDetailItem(
              icon: Icons.category,
              label: AppStrings.t(context, 'Category'),
              value: complaint['complaint_type'] ?? AppStrings.t(context, 'Unknown'),
              color: const Color(0xFF8B5CF6),
            ),
            _buildDetailItem(
              icon: Icons.description,
              label: AppStrings.t(context, 'Description'),
              value: complaint['description'] ?? AppStrings.t(context, 'No description'),
              color: const Color(0xFF10B981),
              isLongText: true,
            ),
            _buildDetailItem(
              icon: Icons.location_on,
              label: AppStrings.t(context, 'Address'),
              value: complaint['address'] ?? AppStrings.t(context, 'No address'),
              color: const Color(0xFFEF4444),
              isLongText: true,
            ),
            _buildDetailItem(
              icon: Icons.access_time,
              label: AppStrings.t(context, 'Submitted'),
              value: _formatDateTime(complaint['created_at'] ?? ''),
              color: const Color(0xFFEAB308),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsCard(Map<String, dynamic> complaint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Personal Information'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'Complainant details'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailItem(
              icon: Icons.person_outline,
              label: AppStrings.t(context, 'Name'),
              value: complaint['user_name'] ?? AppStrings.t(context, 'Anonymous'),
              color: const Color(0xFF8B5CF6),
            ),
            _buildDetailItem(
              icon: Icons.email,
              label: AppStrings.t(context, 'Email'),
              value: complaint['user_email'] ?? AppStrings.t(context, 'Not provided'),
              color: const Color(0xFF3B82F6),
            ),
            _buildDetailItem(
              icon: Icons.phone,
              label: AppStrings.t(context, 'Mobile'),
              value: complaint['user_phone'] ?? AppStrings.t(context, 'Not provided'),
              color: const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentDetailsCard(Map<String, dynamic> department) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Assigned Department'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'Contact information'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailItem(
              icon: Icons.business_center,
              label: AppStrings.t(context, 'Department'),
              value: department['name'] ?? AppStrings.t(context, 'Not assigned'),
              color: const Color(0xFF10B981),
            ),
            _buildDetailItem(
              icon: Icons.email,
              label: AppStrings.t(context, 'Email'),
              value: department['email'] ?? AppStrings.t(context, 'Not provided'),
              color: const Color(0xFF3B82F6),
            ),
            _buildDetailItem(
              icon: Icons.phone,
              label: AppStrings.t(context, 'Mobile'),
              value: department['phone'] ?? AppStrings.t(context, 'Not provided'),
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(department['phone'] ?? ''),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(AppStrings.t(context, 'Call')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendEmail(department['email'] ?? ''),
                    icon: const Icon(Icons.email, size: 18),
                    label: Text(AppStrings.t(context, 'Email')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isLongText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: isLongText ? null : 1,
                  overflow: isLongText ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRatingSection(Map<String, dynamic> complaint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Color(0xFFEAB308),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Rate This Resolution'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'Help us improve our service'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Summary of complaint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t(context, 'Complaint Summary:'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint['title'] ?? AppStrings.t(context, 'No title'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    complaint['complaint_type'] ?? AppStrings.t(context, 'Unknown type'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              AppStrings.t(context, 'How satisfied are you with the resolution?'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            
            // Star Rating
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAB308).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRating = index + 1),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            index < _selectedRating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFEAB308),
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedRating > 0 ? _getRatingText(_selectedRating) : AppStrings.t(context, 'Tap stars to rate'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedRating > 0 ? const Color(0xFFEAB308) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Comment Section
            Text(
              AppStrings.t(context, 'Additional Comments (Optional):'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppStrings.t(context, 'Share your experience or suggestions...'),
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedRating > 0 && !_isSubmittingRating
                    ? () => _submitRating(complaint)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmittingRating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        AppStrings.t(context, 'Submit Rating'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getRatingText(int rating) {
    switch (rating) {
      case 1: return AppStrings.t(context, 'Poor');
      case 2: return AppStrings.t(context, 'Fair');
      case 3: return AppStrings.t(context, 'Good');
      case 4: return AppStrings.t(context, 'Very Good');
      case 5: return AppStrings.t(context, 'Excellent');
      default: return '';
    }
  }

  Widget _buildExistingRatingCard(Map<String, dynamic> complaint) {
    final rating = complaint['citizen_rating'] ?? 0;
    final feedback = complaint['citizen_feedback'] ?? '';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Your Rating'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        AppStrings.t(context, 'Thank you for your feedback'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                    size: 28,
                  );
                }),
                const SizedBox(width: 12),
                Text(
                  '$rating/5 ${AppStrings.t(context, 'Stars')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            if (feedback.isNotEmpty) ...[ 
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(context, 'Your Comment:'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feedback,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReopenSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _showReopenDialog = true),
          icon: const Icon(Icons.refresh, size: 20),
          label: Text(
            AppStrings.t(context, 'Reopen Complaint'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReopenDialog() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.t(context, 'Reopen Complaint'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                IconButton(
                  onPressed: () => setState(() => _showReopenDialog = false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Text(
                '${AppStrings.t(context, 'Complaint ID')} #${widget.complaint['complaint_number'] ?? AppStrings.t(context, 'Unknown')}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(height: 20),
            Text(AppStrings.t(context, 'Reason for reopening:'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: TextField(
                controller: _reopenReasonController,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: AppStrings.t(context, 'Describe the issue in detail...'),
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(AppStrings.t(context, 'Attach Photo Proof (Optional):'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF9FAFB),
                ),
                child: _selectedProofPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            Image.file(File(_selectedProofPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                            Positioned(
                              top: 8, right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedProofPath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate, size: 36, color: Color(0xFF9CA3AF)),
                          const SizedBox(height: 8),
                          Text(AppStrings.t(context, 'Tap to add photo'), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(AppStrings.t(context, 'JPG, PNG up to 10MB'), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showReopenDialog = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppStrings.t(context, 'Cancel'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _reopenReasonController.text.trim().isNotEmpty && !_isSubmittingReopen
                      ? _submitReopen
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmittingReopen
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(AppStrings.t(context, 'Submit Request'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Generate direction arrows along the route
  List<Marker> _generateDirectionArrows(double startLat, double startLng, double endLat, double endLng) {
    List<Marker> arrows = [];
    
    // Get route points
    List<LatLng> routePoints = _generateRoutePoints(startLat, startLng, endLat, endLng);
    
    // Add direction arrows between route points
    for (int i = 0; i < routePoints.length - 1; i++) {
      LatLng current = routePoints[i];
      LatLng next = routePoints[i + 1];
      
      // Calculate midpoint
      double midLat = (current.latitude + next.latitude) / 2;
      double midLng = (current.longitude + next.longitude) / 2;
      
      // Calculate rotation angle
      double angle = math.atan2(
        next.longitude - current.longitude,
        next.latitude - current.latitude,
      ) * 180 / math.pi;
      
      arrows.add(
        Marker(
          point: LatLng(midLat, midLng),
          width: 30,
          height: 30,
          child: Transform.rotate(
            angle: angle * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      );
    }
    
    return arrows;
  }
  List<LatLng> _generateRoutePoints(double startLat, double startLng, double endLat, double endLng) {
    List<LatLng> routePoints = [];
    
    // Start point
    routePoints.add(LatLng(startLat, startLng));
    
    // Calculate intermediate points to simulate road routing
    double latDiff = endLat - startLat;
    double lngDiff = endLng - startLng;
    
    // Add waypoints to simulate realistic road routing
    // First turn - horizontal movement
    if (latDiff.abs() > 0.001 || lngDiff.abs() > 0.001) {
      routePoints.add(LatLng(startLat + (latDiff * 0.3), startLng + (lngDiff * 0.7)));
      
      // Second turn - vertical movement
      routePoints.add(LatLng(startLat + (latDiff * 0.7), startLng + (lngDiff * 0.9)));
      
      // Third turn - final approach
      routePoints.add(LatLng(endLat - (latDiff * 0.1), endLng));
    }
    
    // End point
    routePoints.add(LatLng(endLat, endLng));
    
    return routePoints;
  }
  
  // Generate road connection lines
  List<Polyline> _generateRoadConnections(double startLat, double startLng, double endLat, double endLng) {
    List<Polyline> roadLines = [];
    
    // Horizontal road lines (streets)
    for (int i = 0; i < 3; i++) {
      double lat = startLat + ((endLat - startLat) * (i + 1) / 4);
      roadLines.add(
        Polyline(
          points: [
            LatLng(lat, startLng - 0.002),
            LatLng(lat, endLng + 0.002),
          ],
          color: Colors.white.withOpacity(0.8),
          strokeWidth: 3.0,
          isDotted: false,
        ),
      );
    }
    
    // Vertical road lines (avenues)
    for (int i = 0; i < 3; i++) {
      double lng = startLng + ((endLng - startLng) * (i + 1) / 4);
      roadLines.add(
        Polyline(
          points: [
            LatLng(startLat - 0.002, lng),
            LatLng(endLat + 0.002, lng),
          ],
          color: Colors.white.withOpacity(0.8),
          strokeWidth: 3.0,
          isDotted: false,
        ),
      );
    }
    
    return roadLines;
  }
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLng = _degreesToRadians(lng2 - lng1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  bool _canReopenComplaint(Map<String, dynamic> complaint) {
    if (complaint['work_status'] != 'solved') return false;
    
    final solvedDate = DateTime.tryParse(complaint['solved_at'] ?? '');
    if (solvedDate == null) return false;
    
    final daysSinceSolved = DateTime.now().difference(solvedDate).inDays;
    return daysSinceSolved <= 7;
  }

  bool _isStepCompleted(String stepKey, String currentStatus) {
    // Handle rejected status
    if (currentStatus == 'rejected') {
      return stepKey == 'pending' || stepKey == 'rejected';
    }
    
    // Handle reopened status
    if (currentStatus == 'reopened') {
      return stepKey == 'pending' || stepKey == 'confirmed' || 
             stepKey == 'process' || stepKey == 'solved' || stepKey == 'reopened';
    }
    
    // Normal flow
    const statusOrder = ['pending', 'confirmed', 'process', 'solved'];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final stepIndex = statusOrder.indexOf(stepKey);
    return currentIndex >= stepIndex && stepIndex != -1;
  }

  String _formatDateTime(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _getStatusTime(String currentStatus, String stepStatus) {
    // This would normally come from API with actual timestamps
    if (_isStepCompleted(stepStatus, currentStatus)) {
      return AppStrings.t(context, 'Completed');
    }
    return '';
  }

  void _zoomIn() {
    // Implement zoom in functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.t(context, 'Zoom In - Map zoomed in')),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _zoomOut() {
    // Implement zoom out functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.t(context, 'Zoom Out - Map zoomed out')),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF2B6CF6),
      ),
    );
  }

  void _getDirections(double lat, double lng) async {
    final url = lat != 0.0 && lng != 0.0
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
        : 'https://www.google.com/maps/dir/?api=1&destination=28.6139,77.2090';
    
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.t(context, 'Could not open directions')),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showFullScreenMap(Map<String, dynamic> complaint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenMapView(complaint: complaint),
      ),
    );
  }

  void _shareComplaint(Map<String, dynamic> complaint) {
    // Implement share functionality
    print('Share complaint: ${complaint['complaint_number']}');
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedProofPath = image.path;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _submitRating(Map<String, dynamic> complaint) async {
    setState(() => _isSubmittingRating = true);
    
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      // Update complaint data
      complaint['citizen_rating'] = _selectedRating;
      complaint['citizen_feedback'] = _commentController.text;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.t(context, 'Rating submitted successfully!')),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.t(context, 'Failed to submit rating. Please try again.')),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
      }
    }
  }

  Future<void> _submitReopen() async {
    setState(() => _isSubmittingReopen = true);
    
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.t(context, 'Reopen request submitted successfully!')),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() => _showReopenDialog = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.t(context, 'Failed to submit reopen request. Please try again.')),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReopen = false);
      }
    }
  }

  @override
  void dispose() {
    _reopenReasonController.dispose();
    _ratingController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}

// Full Screen Map View
class _FullScreenMapView extends StatefulWidget {
  final Map<String, dynamic> complaint;
  
  const _FullScreenMapView({required this.complaint});
  
  @override
  State<_FullScreenMapView> createState() => _FullScreenMapViewState();
}

class _FullScreenMapViewState extends State<_FullScreenMapView> {
  double _zoomLevel = 1.0;
  
  @override
  Widget build(BuildContext context) {
    final lat = widget.complaint['latitude'] ?? 0.0;
    final lng = widget.complaint['longitude'] ?? 0.0;
    final deptLat = widget.complaint['assigned_department']?['latitude'] ?? 0.0;
    final deptLng = widget.complaint['assigned_department']?['longitude'] ?? 0.0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          AppStrings.t(context, 'Interactive Map View'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _openExternalMap(lat, lng),
            icon: const Icon(Icons.open_in_new),
            tooltip: AppStrings.t(context, 'Open in External Map'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full Screen Interactive Map
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE0F2FE),
                  Color(0xFFBAE6FD),
                ],
              ),
            ),
            child: Transform.scale(
              scale: _zoomLevel,
              child: CustomPaint(
                painter: _MapPatternPainter(),
                child: Stack(
                  children: [
                    // Complaint Location Marker
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.4,
                      left: MediaQuery.of(context).size.width * 0.4,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              AppStrings.t(context, 'Complaint Location'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFFEF4444),
                            size: 48,
                          ),
                        ],
                      ),
                    ),
                    // Department Location Marker
                    if (deptLat != 0.0 && deptLng != 0.0)
                      Positioned(
                        top: MediaQuery.of(context).size.height * 0.3,
                        right: MediaQuery.of(context).size.width * 0.3,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                AppStrings.t(context, 'Department'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Icon(
                              Icons.business,
                              color: Color(0xFF10B981),
                              size: 40,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Zoom Controls
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    setState(() {
                      _zoomLevel = (_zoomLevel * 1.2).clamp(0.5, 3.0);
                    });
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    setState(() {
                      _zoomLevel = (_zoomLevel / 1.2).clamp(0.5, 3.0);
                    });
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Color(0xFF374151)),
                ),
              ],
            ),
          ),
          // Location Info
          Positioned(
            bottom: 20,
            left: 20,
            right: 100,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.complaint['title']?.isNotEmpty == true
                        ? widget.complaint['title']
                        : AppStrings.t(context, 'Complaint Details'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_city,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${widget.complaint['city'] ?? '-'}, ${widget.complaint['state'] ?? '-'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (lat != 0.0 && lng != 0.0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _openExternalMap(double lat, double lng) async {
    final url = lat != 0.0 && lng != 0.0
        ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
        : 'https://www.google.com/maps/search/?api=1&query=28.6139,77.2090';
    
    if (await canLaunch(url)) {
      await launch(url);
    }
  }
}