import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';
import '../../l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';

class GuestDashboardScreen extends StatefulWidget {
  const GuestDashboardScreen({super.key});
  @override
  State<GuestDashboardScreen> createState() => _GuestDashboardScreenState();
}

class _GuestDashboardScreenState extends State<GuestDashboardScreen> {
  int _tab = 0;
  int _navIndex = 0;
  String? _selectedGuestCategory;

  int _total = 0, _pending = 0, _solved = 0, _depts = 0;
  bool _statsLoading = true;

  final _trackComplaintCtrl = TextEditingController();
  final _trackPhoneCtrl = TextEditingController();
  bool _trackLoading = false;
  String? _trackError;
  Map<String, dynamic>? _trackResult;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _trackComplaintCtrl.dispose();
    _trackPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final res = await ApiService.get(ApiConfig.guestStats, includeAuth: false);
      if (res['success'] == true) {
        setState(() {
          _total = res['total_complaints'] ?? 0;
          _pending = res['pending_complaints'] ?? 0;
          _solved = res['solved_complaints'] ?? 0;
          _depts = res['active_departments'] ?? 0;
        });
      }
    } catch (_) {}
    setState(() => _statsLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(children: [
        _topNav(),
        Expanded(child: RefreshIndicator(
          color: const Color(0xFFFF6B35),
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(children: [
              _tabNav(),
              if (_tab == 0) _homeTab(),
              if (_tab == 1) _submitTab(),
              if (_tab == 2) _trackTab(),
            ]),
          ),
        )),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _topNav() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/logo.png',
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        const Spacer(),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF1A1A1A),
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8F5A)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.login_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tabNav() {
    final tabs = [AppStrings.t(context, 'Home'), AppStrings.t(context, 'Submit'), AppStrings.t(context, 'Track')];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
      child: Row(
          children: List.generate(
              3,
              (i) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _tab = i;
                        _navIndex = i;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            color: _tab == i ? const Color(0xFFFF6B35) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(tabs[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _tab == i ? Colors.white : const Color(0xFF64748b))),
                      ),
                    ),
                  ))),
    );
  }

  Widget _homeTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _guestHeroCard(),
      const SizedBox(height: 20),
      // Live Stats Section
      Row(children: [
        Text(AppStrings.t(context, '📊 Live Stats'),
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
        const SizedBox(width: 8),
        if (_statsLoading)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35))),
      ]),
      const SizedBox(height: 12),
      _statsGrid(),
      const SizedBox(height: 0),

      // Hidden to keep guest dashboard visually aligned with user dashboard
      if (false) Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF3D3D3D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('🔐', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppStrings.t(context, 'Guest Mode'),
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 2),
              Text(AppStrings.t(context, 'Login to unlock tracking, profile\nand real-time updates.'),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFFAAAAAA), height: 1.4)),
            ]),
          ),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(AppStrings.t(context, 'Login'),
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 0),

      // Departments
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(AppStrings.t(context, '🚨 Emergency Contacts'),
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.departmentsList),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(AppStrings.t(context, 'View All'),
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B35))),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      _departmentsGridCompact(),
      const SizedBox(height: 24),

      // Recent Complaints Section
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(AppStrings.t(context, '📋 Recent Complaints'),
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
        GestureDetector(
          onTap: () => setState(() => _tab = 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(AppStrings.t(context, 'View All'),
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B35))),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      _recentComplaintsLocked(),
    ]);
  }

  Widget _guestHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.lock_outline_rounded, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(context, 'Guest Mode'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.t(context, 'Explore Dashboard'),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppStrings.t(context, 'Login for full complaint history'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _track() async {
    if (_trackComplaintCtrl.text.trim().isEmpty || _trackPhoneCtrl.text.trim().isEmpty) {
      setState(() => _trackError = AppStrings.t(context, 'Please enter both complaint ID and mobile number'));
      return;
    }
    setState(() { _trackLoading = true; _trackError = null; _trackResult = null; });
    try {
      final res = await ApiService.post(
        ApiConfig.trackGuest,
        {'complaint_number': _trackComplaintCtrl.text.trim(), 'phone': _trackPhoneCtrl.text.trim()},
        includeAuth: false,
      );
      setState(() {
        _trackLoading = false;
        if (res['success'] == true) {
          _trackResult = res['complaint'] as Map<String, dynamic>;
        } else {
          _trackError = res['message'] ?? AppStrings.t(context, 'Complaint not found');
        }
      });
    } catch (e) {
      setState(() {
        _trackLoading = false;
        _trackError = AppStrings.t(context, 'Something went wrong. Please try again.');
      });
    }
  }

  Widget _trackTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppStrings.t(context, 'Track Complaint'),
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text(AppStrings.t(context, 'Check the status of your reported issue'),
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
      const SizedBox(height: 20),
      
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(children: [
          _inputField(_trackComplaintCtrl, AppStrings.t(context, 'Complaint ID (e.g. COMP123)'), Icons.tag),
          const SizedBox(height: 12),
          _inputField(_trackPhoneCtrl, AppStrings.t(context, 'Mobile Number'), Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _trackLoading ? null : _track,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _trackLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(AppStrings.t(context, 'TRACK NOW'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          if (_trackError != null) ...[
            const SizedBox(height: 12),
            Text(_trackError!, style: GoogleFonts.inter(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
          ]
        ]),
      ),

      if (_trackResult != null) ...[
        const SizedBox(height: 24),
        Text(AppStrings.t(context, 'Complaint Details'),
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 12),
        _infoGrid(_trackResult!),
        const SizedBox(height: 24),
        Text(AppStrings.t(context, 'Progress Status'),
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 16),
        _timeline(_trackResult!['work_status'] as String, _trackResult!),
        const SizedBox(height: 24),
        _mapSection(_trackResult!),
        const SizedBox(height: 24),
        if (_trackResult!['assigned_department_phone'] != null)
          _connectDeptSection(_trackResult!),
        const SizedBox(height: 24),
        if (_trackResult!['work_status'] == 'solved')
          _reopenButton(),
        const SizedBox(height: 40),
      ],
    ]);
  }

  Widget _reopenButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(children: [
        const Text('🔄', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(AppStrings.t(context, 'Not satisfied with the resolution?'),
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF991B1B))),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _showReopenLoginDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppStrings.t(context, 'REOPEN COMPLAINT'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  void _showReopenLoginDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🔐 ', style: TextStyle(fontSize: 20)),
          Text(AppStrings.t(context, 'Login Required'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        content: Text(AppStrings.t(context, 'To reopen a complaint, you must be logged in to your account for verification and security purposes.'),
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t(context, 'Cancel'), style: GoogleFonts.inter(color: const Color(0xFF64748b), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppStrings.t(context, 'Login Now'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController c, String hint, IconData icon, {TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: c,
        keyboardType: type,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b)),
          prefixIcon: Icon(icon, color: const Color(0xFF64748b), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _infoGrid(Map<String, dynamic> c) {
    final items = [
      (AppStrings.t(context, 'Complaint ID'), '#${c['complaint_number']}'),
      (AppStrings.t(context, 'Category'), c['complaint_type'] ?? ''),
      (AppStrings.t(context, 'Assigned Dept'), c['assigned_department'] ?? AppStrings.t(context, 'Not Assigned Yet')),
      (AppStrings.t(context, 'Location'), '${c['city']}, ${c['pincode']}'),
      (AppStrings.t(context, 'Submitted On'), c['created_at'] ?? ''),
      (AppStrings.t(context, 'Contact Person'), c['contact_name'] ?? ''),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(item.$1, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b), fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Flexible(child: Text(item.$2, textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a)))),
          ]),
        )).toList(),
      ),
    );
  }

  Widget _timeline(String status, Map<String, dynamic> c) {
    final steps = [
      _TimelineStep(AppStrings.t(context, 'Submitted'), Icons.assignment_outlined, _isCompleted(status, 'pending'), _statusColor('pending'), c['created_at'] ?? ''),
      _TimelineStep(AppStrings.t(context, 'Confirmed'), Icons.check_circle_outline, _isCompleted(status, 'confirmed'), _statusColor('confirmed'), _isCompleted(status, 'confirmed') ? (c['updated_at'] ?? AppStrings.t(context, 'Confirmed')) : '-'),
      _TimelineStep(AppStrings.t(context, 'Processing'), Icons.autorenew, _isCompleted(status, 'process'), _statusColor('process'), _isCompleted(status, 'process') ? (c['updated_at'] ?? AppStrings.t(context, 'In Process')) : '-'),
      _TimelineStep(status == 'reopened' ? AppStrings.t(context, 'Reopened') : AppStrings.t(context, 'Solved'), status == 'reopened' ? Icons.refresh : Icons.verified_outlined, _isCompleted(status, 'solved'), _statusColor(status == 'reopened' ? 'reopened' : 'solved'), _isCompleted(status, 'solved') ? (c['updated_at'] ?? AppStrings.t(context, 'Done')) : '-'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: List.generate(steps.length, (i) {
          final s = steps[i];
          final isLast = i == steps.length - 1;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: s.completed ? s.color : Colors.white,
                  border: Border.all(color: s.completed ? Colors.transparent : const Color(0xFFE2E8F0), width: 2),
                  shape: BoxShape.circle,
                ),
                child: Icon(s.completed ? Icons.check : s.icon, size: 12, color: s.completed ? Colors.white : const Color(0xFF94a3b8)),
              ),
              if (!isLast) Container(width: 2, height: 40, color: s.completed ? s.color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
            ]),
            const SizedBox(width: 16),
            Expanded(child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: s.completed ? const Color(0xFF0f172a) : const Color(0xFF64748b))),
                const SizedBox(height: 2),
                Text(s.date, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94a3b8))),
              ]),
            )),
          ]);
        }),
      ),
    );
  }

  Widget _mapSection(Map<String, dynamic> c) {
    final cLat = (c['latitude'] ?? 0.0).toDouble();
    final cLng = (c['longitude'] ?? 0.0).toDouble();
    final dLat = (c['assigned_department_latitude'] ?? 0.0).toDouble();
    final dLng = (c['assigned_department_longitude'] ?? 0.0).toDouble();
    
    if (cLat == 0.0 && cLng == 0.0) return const SizedBox.shrink();
    
    final cPos = LatLng(cLat, cLng);
    final hasDept = dLat != 0.0 && dLng != 0.0;
    final dPos = hasDept ? LatLng(dLat, dLng) : null;
    
    // Calculate center for both or just complaint
    final center = hasDept 
        ? LatLng((cLat + dLat) / 2, (cLng + dLng) / 2)
        : cPos;
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.map_outlined, size: 20, color: Color(0xFF1E66F5)),
          const SizedBox(width: 8),
          Text(AppStrings.t(context, 'Location Tracking'),
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: Stack(children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center, 
                  initialZoom: hasDept ? 12 : 15,
                  minZoom: 5,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.janhelp.app',
                  ),
                  if (hasDept) PolylineLayer(polylines: [
                    Polyline(
                      points: [cPos, dPos!],
                      color: const Color(0xFF1E66F5).withValues(alpha: 0.6),
                      strokeWidth: 4,
                      isDotted: true,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: cPos,
                      width: 45, height: 45,
                      child: Column(children: [
                        const Icon(Icons.location_pin, color: Color(0xFFEF4444), size: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]),
                          child: Text(AppStrings.t(context, 'Issue'), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                    if (hasDept) Marker(
                      point: dPos!,
                      width: 45, height: 45,
                      child: Column(children: [
                        const Icon(Icons.business_rounded, color: Color(0xFF1E66F5), size: 30),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]),
                          child: Text(AppStrings.t(context, 'Dept'), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5))),
                        ),
                      ]),
                    ),
                  ]),
                ],
              ),
              
              // Zoom Buttons Overlay
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(children: [
                  _zoomBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                  const SizedBox(height: 8),
                  _zoomBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
        child: Icon(icon, size: 20, color: const Color(0xFF1E66F5)),
      ),
    );
  }

  Widget _connectDeptSection(Map<String, dynamic> c) {
    final deptName = c['assigned_department'] ?? AppStrings.t(context, 'Department');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E66F5).withValues(alpha: 0.08), const Color(0xFF1E66F5).withValues(alpha: 0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E66F5).withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF1E66F5).withValues(alpha: 0.1), blurRadius: 10)]),
          child: const Icon(Icons.business_rounded, color: Color(0xFF1E66F5), size: 30),
        ),
        const SizedBox(height: 12),
        Text(AppStrings.t(context, 'Connect with Assigned Department'),
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 4),
        Text('${AppStrings.t(context, 'Get in touch with')} $deptName ${AppStrings.t(context, 'for updates')}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${c['assigned_department_phone']}')),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
              label: Text(AppStrings.t(context, 'Call')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66F5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('mailto:${c['assigned_department_email']}')),
              icon: const Icon(Icons.email_rounded, size: 18),
              label: Text(AppStrings.t(context, 'Email')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E66F5),
                elevation: 0,
                side: const BorderSide(color: Color(0xFF1E66F5), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  bool _isCompleted(String current, String step) {
    const order = ['pending', 'confirmed', 'process', 'solved', 'reopened'];
    final ci = order.indexOf(current);
    final si = order.indexOf(step);
    if (step == 'solved') return current == 'solved' || current == 'reopened';
    return ci >= si && si != -1;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return const Color(0xFFEF4444);
      case 'confirmed': return const Color(0xFFF97316);
      case 'process': return const Color(0xFFEAB308);
      case 'solved': return const Color(0xFF22C55E);
      case 'reopened': return const Color(0xFF991B1B);
      default: return const Color(0xFF94A3B8);
    }
  }

  // ── Stats grid with blur overlay ──────────────────────────────────────────
  Widget _statsGrid() {
    final items = [
      {'emoji': '📊', 'label': AppStrings.t(context, 'Total Complaints'), 'count': _total, 'color': const Color(0xFFEEF2FF)},
      {'emoji': '⏳', 'label': AppStrings.t(context, 'Pending'), 'count': _pending, 'color': const Color(0xFFFFF1F2)},
      {'emoji': '✅', 'label': AppStrings.t(context, 'Solved'), 'count': _solved, 'color': const Color(0xFFF0FDF4)},
      {'emoji': '🏢', 'label': AppStrings.t(context, 'Departments'), 'count': _depts, 'color': const Color(0xFFEFF6FF)},
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: items.map((item) => _statCard(item)).toList(),
    );
  }

  Widget _statCard(Map item) {
    return Container(
      decoration: BoxDecoration(
        color: item['color'] as Color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
      ),
      child: Stack(
        children: [
          // Actual content (visible underneath blur)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Big emoji — no background, fills naturally
              Text(item['emoji'] as String, style: const TextStyle(fontSize: 36)),
              const Spacer(),
              Text('${item['count']}',
                  style: GoogleFonts.poppins(
                      fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFF0f172a))),
              Text(item['label'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748b), fontWeight: FontWeight.w500)),
            ]),
          ),

          // Blur + lock overlay for guest
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.55),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 20, color: Color(0xFFFF6B35)),
                      ),
                      const SizedBox(height: 6),
                      Text(AppStrings.t(context, 'Login to view'),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF6B35))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentComplaintsLocked() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_rounded, size: 32, color: Color(0xFFFF6B35)),
        ),
        const SizedBox(height: 16),
        Text(AppStrings.t(context, 'Login Required'),
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 8),
        Text(AppStrings.t(context, 'Please login to see your recent complaints\nand track their status in real-time.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF64748b), height: 1.5)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppStrings.t(context, 'LOGIN NOW'),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _departmentsGridCompact() {
    final depts = [
      {'emoji': '🚓', 'name': AppStrings.t(context, 'Police'), 'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': AppStrings.t(context, 'Traffic'), 'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': AppStrings.t(context, 'Construction'), 'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🚰', 'name': AppStrings.t(context, 'Water'), 'bg': const Color(0xFFF0FDF4)},
      {'emoji': '💡', 'name': AppStrings.t(context, 'Electric'), 'bg': const Color(0xFFFFF5E6)},
      {'emoji': '🗑️', 'name': AppStrings.t(context, 'Garbage'), 'bg': const Color(0xFFEFFDF7)},
      {'emoji': '🛣️', 'name': AppStrings.t(context, 'Roads'), 'bg': const Color(0xFFFFF4F8)},
    ];
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: depts.length,
          itemBuilder: (context, index) {
            final d = depts[index];
            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.departmentsList),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [d['bg'] as Color, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(d['emoji'] as String, style: const TextStyle(fontSize: 38)),
                    const SizedBox(height: 8),
                    Text(
                      d['name'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.departmentsList),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withValues(alpha: 0.1),
                  const Color(0xFFFF8F5A).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFFFF6B35)),
                const SizedBox(width: 8),
                Text(
                  AppStrings.t(context, 'View All Emergency Contacts'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFFF6B35)),
              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _submitTab() {
    final categories = [
      {'emoji': '🚓', 'name': AppStrings.t(context, 'Police'),          'key': 'police',         'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': AppStrings.t(context, 'Traffic'),         'key': 'traffic',        'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': AppStrings.t(context, 'Construction'),    'key': 'construction',   'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🚰', 'name': AppStrings.t(context, 'Water Supply'),    'key': 'water',          'bg': const Color(0xFFF0FDF4)},
      {'emoji': '💡', 'name': AppStrings.t(context, 'Electricity'),     'key': 'electricity',    'bg': const Color(0xFFFFFBEB)},
      {'emoji': '🗑️', 'name': AppStrings.t(context, 'Garbage'),         'key': 'garbage',        'bg': const Color(0xFFECFDF5)},
      {'emoji': '🛣️', 'name': AppStrings.t(context, 'Road / Pothole'),  'key': 'road',           'bg': const Color(0xFFFAF5FF)},
      {'emoji': '🌊', 'name': AppStrings.t(context, 'Drainage'),        'key': 'drainage',       'bg': const Color(0xFFEFF6FF)},
      {'emoji': '⚠️', 'name': AppStrings.t(context, 'Illegal Activity'),'key': 'illegal',        'bg': const Color(0xFFFFF1F2)},
      {'emoji': '🚌', 'name': AppStrings.t(context, 'Transportation'),  'key': 'transportation', 'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🛡️', 'name': AppStrings.t(context, 'Cyber Crime'),     'key': 'cyber',          'bg': const Color(0xFFF5F3FF)},
      {'emoji': '📋', 'name': AppStrings.t(context, 'Other'),           'key': 'other',          'bg': const Color(0xFFF8FAFC)},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _guestCategoryHeaderCard(categories),
      const SizedBox(height: 24),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: categories.map((c) {
          final bg = c['bg'] as Color;
          final isSelected = _selectedGuestCategory == c['key'];
          return GestureDetector(
            onTap: () => setState(() {
              if (isSelected) {
                _selectedGuestCategory = null;
              } else {
                _selectedGuestCategory = c['key'] as String;
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B35).withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFFEEEEEE),
                  width: isSelected ? 2 : 1.5,
                ),
                boxShadow: [BoxShadow(color: (isSelected ? const Color(0xFFFF6B35) : Colors.black).withValues(alpha: isSelected ? 0.18 : 0.05), blurRadius: isSelected ? 12 : 10, offset: const Offset(0, 3))],
              ),
                child: Column(children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c['emoji'] as String, style: const TextStyle(fontSize: 38)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(c['name'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: isSelected ? const Color(0xFFFF6B35) : const Color(0xFF1A1A1A))),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      _guestCategoryContinueButton(categories),
    ]);
  }

  Widget _guestCategoryHeaderCard(List<Map<String, dynamic>> categories) {
    final matchingCategories = _selectedGuestCategory != null
        ? categories.where((c) => c['key'] == _selectedGuestCategory).toList()
        : const <Map<String, dynamic>>[];
    final selectedCat =
        matchingCategories.isNotEmpty ? matchingCategories.first : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ðŸ“‹', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(context, 'Choose Category'),
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      selectedCat != null
                          ? '${selectedCat['emoji']} ${selectedCat['name']} ${AppStrings.t(context, 'selected')}'
                          : AppStrings.t(context, 'Select complaint type'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: selectedCat != null
                            ? const Color(0xFFFF6B35)
                            : Colors.white.withValues(alpha: 0.8),
                        fontWeight: selectedCat != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _selectedGuestCategory != null
                  ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedGuestCategory != null
                    ? const Color(0xFFFF6B35).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedGuestCategory != null
                      ? Icons.check_circle
                      : Icons.touch_app_outlined,
                  size: 18,
                  color: _selectedGuestCategory != null
                      ? const Color(0xFFFF6B35)
                      : Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedGuestCategory == null
                        ? AppStrings.t(context, 'Tap a category below to select')
                        : AppStrings.t(context, 'Ready to submit complaint!'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guestCategoryContinueButton(List<Map<String, dynamic>> categories) {
    final hasSelection = _selectedGuestCategory != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: hasSelection
            ? () {
                final selectedCat = categories.firstWhere(
                  (c) => c['key'] == _selectedGuestCategory,
                );
                Navigator.pushNamed(
                  context,
                  AppRoutes.submitComplaint,
                  arguments: {
                    'categoryKey': _selectedGuestCategory,
                    'categoryName': selectedCat['name'],
                  },
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          disabledBackgroundColor: const Color(0xFFE5E5E5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          AppStrings.t(context, 'Continue Complaint'),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: hasSelection ? Colors.white : const Color(0xFFAAAAAA),
          ),
        ),
      ),
    );
  }

  Widget _bottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': AppStrings.t(context, 'Home')},
      {'icon': Icons.add_circle_rounded, 'label': AppStrings.t(context, 'Submit')},
      {'icon': Icons.search_rounded, 'label': AppStrings.t(context, 'Track')},
      {'icon': Icons.person_outline_rounded, 'label': AppStrings.t(context, 'Profile')},
    ];
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 1))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom, top: 12, left: 16, right: 16),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(4, (i) {
            final active = _navIndex == i;
            return GestureDetector(
              onTap: () {
                if (i == 0) setState(() { _navIndex = 0; _tab = 0; });
                else if (i == 1) setState(() { _navIndex = 1; _tab = 1; });
                else if (i == 2) setState(() { _navIndex = 2; _tab = 2; });
                else Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: active ? const Color(0xFFFF6B35).withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    items[i]['icon'] as IconData,
                    color: active ? const Color(0xFFFF6B35) : const Color(0xFFBDBDBD),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(items[i]['label'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active ? const Color(0xFFFF6B35) : const Color(0xFF64748b))),
                ]),
              ),
            );
          })),
    );
  }
}

class _TimelineStep {
  final String label;
  final IconData icon;
  final bool completed;
  final Color color;
  final String date;
  const _TimelineStep(this.label, this.icon, this.completed, this.color, this.date);
}
