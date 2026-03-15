import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class GuestDashboardScreen extends StatefulWidget {
  const GuestDashboardScreen({super.key});
  @override
  State<GuestDashboardScreen> createState() => _GuestDashboardScreenState();
}

class _GuestDashboardScreenState extends State<GuestDashboardScreen> {
  int _tab = 0;
  int _navIndex = 0;

  int _total = 0, _pending = 0, _solved = 0, _depts = 0;
  bool _statsLoading = true;

  final _trackComplaintCtrl = TextEditingController();
  final _trackPhoneCtrl = TextEditingController();
  bool _trackLoading = false;
  String? _trackError;
  Map<String, dynamic>? _trackResult;

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        _topNav(),
        Expanded(child: RefreshIndicator(
          color: const Color(0xFF1E66F5),
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
      child: Row(children: [
        Image.asset('assets/images/logo.png', height: 36),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Guest Mode',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
          Text('Limited access',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1E66F5), borderRadius: BorderRadius.circular(10)),
            child: Text('Login',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _tabNav() {
    final tabs = ['Home', 'Submit', 'Track'];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: _tab == i ? const Color(0xFF1E66F5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(tabs[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _tab == i ? Colors.white : const Color(0xFF64748b))),
                      ),
                    ),
                  ))),
    );
  }

  Widget _homeTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Welcome banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF154ec7)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome, Guest! 👋',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Submit complaints & view departments.\nLogin for full access.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.85))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration:
                    BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text('Login / Register',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E66F5))),
              ),
            ),
          ])),
          const SizedBox(width: 12),
          const Text('🔐', style: TextStyle(fontSize: 52)),
        ]),
      ),
      const SizedBox(height: 24),

      // Live Stats — hidden with blur + lock
      Row(children: [
        Text('Live Stats',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(width: 8),
        if (_statsLoading)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5))),
      ]),
      const SizedBox(height: 12),
      _statsGrid(),
      const SizedBox(height: 24),

      // Departments
      Text('Departments',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 12),
      _departmentsGrid(),
      const SizedBox(height: 24),

      // Locked features
      _lockedBanner(),
    ]);
  }

  Future<void> _track() async {
    if (_trackComplaintCtrl.text.trim().isEmpty || _trackPhoneCtrl.text.trim().isEmpty) {
      setState(() => _trackError = 'Please enter both complaint ID and mobile number');
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
          _trackError = res['message'] ?? 'Complaint not found';
        }
      });
    } catch (e) {
      setState(() {
        _trackLoading = false;
        _trackError = 'Something went wrong. Please try again.';
      });
    }
  }

  Widget _trackTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Track Complaint',
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text('Check the status of your reported issue',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
      const SizedBox(height: 20),
      
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(children: [
          _inputField(_trackComplaintCtrl, 'Complaint ID (e.g. COMP123)', Icons.tag),
          const SizedBox(height: 12),
          _inputField(_trackPhoneCtrl, 'Mobile Number', Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _trackLoading ? null : _track,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66F5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _trackLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('TRACK NOW', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
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
        Text('Complaint Details',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 12),
        _infoGrid(_trackResult!),
        const SizedBox(height: 24),
        Text('Progress Status',
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
        Text('Not satisfied with the resolution?',
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
            child: Text('REOPEN COMPLAINT', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
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
          Text('Login Required', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        content: Text('To reopen a complaint, you must be logged in to your account for verification and security purposes.',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748b), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E66F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Login Now', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
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
      ('Complaint ID', '#${c['complaint_number']}'),
      ('Category', c['complaint_type'] ?? ''),
      ('Assigned Dept', c['assigned_department'] ?? 'Not Assigned Yet'),
      ('Location', '${c['city']}, ${c['pincode']}'),
      ('Submitted On', c['created_at'] ?? ''),
      ('Contact Person', c['contact_name'] ?? ''),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
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
      _TimelineStep('Submitted', Icons.assignment_outlined, _isCompleted(status, 'pending'), _statusColor('pending'), c['created_at'] ?? ''),
      _TimelineStep('Confirmed', Icons.check_circle_outline, _isCompleted(status, 'confirmed'), _statusColor('confirmed'), _isCompleted(status, 'confirmed') ? (c['updated_at'] ?? 'Confirmed') : '-'),
      _TimelineStep('Processing', Icons.autorenew, _isCompleted(status, 'process'), _statusColor('process'), _isCompleted(status, 'process') ? (c['updated_at'] ?? 'In Process') : '-'),
      _TimelineStep(status == 'reopened' ? 'Reopened' : 'Solved', status == 'reopened' ? Icons.refresh : Icons.verified_outlined, _isCompleted(status, 'solved'), _statusColor(status == 'reopened' ? 'reopened' : 'solved'), _isCompleted(status, 'solved') ? (c['updated_at'] ?? 'Done') : '-'),
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
              if (!isLast) Container(width: 2, height: 40, color: s.completed ? s.color.withOpacity(0.3) : const Color(0xFFE2E8F0)),
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
          Text('Location Tracking',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: hasDept ? 13 : 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.janhelp.app',
                ),
                if (hasDept) PolylineLayer(polylines: [
                  Polyline(
                    points: [cPos, dPos!],
                    color: const Color(0xFF1E66F5).withOpacity(0.5),
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
                        child: Text('Complaint', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700)),
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
                        child: Text('Dept', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5))),
                      ),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _connectDeptSection(Map<String, dynamic> c) {
    final deptName = c['assigned_department'] ?? 'Department';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E66F5).withOpacity(0.08), const Color(0xFF1E66F5).withOpacity(0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E66F5).withOpacity(0.15), width: 1.5),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF1E66F5).withOpacity(0.1), blurRadius: 10)]),
          child: const Icon(Icons.business_rounded, color: Color(0xFF1E66F5), size: 30),
        ),
        const SizedBox(height: 12),
        Text('Connect with Assigned Department',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 4),
        Text('Get in touch with $deptName for updates',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${c['assigned_department_phone']}')),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
              label: const Text('Call'),
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
              label: const Text('Email'),
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
      {'emoji': '📊', 'label': 'Total Complaints', 'count': _total, 'color': const Color(0xFFEEF2FF)},
      {'emoji': '⏳', 'label': 'Pending', 'count': _pending, 'color': const Color(0xFFFFF1F2)},
      {'emoji': '✅', 'label': 'Solved', 'count': _solved, 'color': const Color(0xFFF0FDF4)},
      {'emoji': '🏢', 'label': 'Departments', 'count': _depts, 'color': const Color(0xFFEFF6FF)},
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
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
                  color: Colors.white.withOpacity(0.55),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E66F5).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 20, color: Color(0xFF1E66F5)),
                      ),
                      const SizedBox(height: 6),
                      Text('Login to view',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E66F5))),
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

  // ── Departments grid — show only 3, with View All ──────────────────────
  Widget _departmentsGrid() {
    final depts = [
      {'emoji': '🚓', 'name': 'Police', 'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': 'Traffic', 'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': 'Construction', 'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🚰', 'name': 'Water Supply', 'bg': const Color(0xFFF0FDF4)},
      {'emoji': '💡', 'name': 'Electricity', 'bg': const Color(0xFFFFFBEB)},
      {'emoji': '🗑️', 'name': 'Garbage', 'bg': const Color(0xFFF0FDF4)},
      {'emoji': '🛣️', 'name': 'Road', 'bg': const Color(0xFFFAF5FF)},
      {'emoji': '🌊', 'name': 'Drainage', 'bg': const Color(0xFFEFF6FF)},
      {'emoji': '🚌', 'name': 'Transport', 'bg': const Color(0xFFFFF1F2)},
    ];
    final preview = depts.take(3).toList();
    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: preview.map((d) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.departmentsList),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: d['bg'] as Color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(d['emoji'] as String, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 6),
                Text(d['name'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: const Color(0xFF0f172a))),
              ]),
            ),
          ),
        ))).toList(),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.departmentsList),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1E66F5).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E66F5).withOpacity(0.25)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('View All Departments',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E66F5))),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1E66F5)),
          ]),
        ),
      ),
    ]);
  }

  Widget _lockedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        const Text('🔒', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Login to unlock full features',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 4),
        Text('Track complaints • View profile • Get updates',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b)),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _lockedFeature('📋', 'Track'),
          const SizedBox(width: 20),
          _lockedFeature('👤', 'Profile'),
          const SizedBox(width: 20),
          _lockedFeature('🔔', 'Updates'),
        ]),
      ]),
    );
  }

  Widget _lockedFeature(String emoji, String label) {
    return Column(children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _submitTab() {
    final categories = [
      {'emoji': '🚓', 'name': 'Police',          'key': 'police',         'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': 'Traffic',         'key': 'traffic',        'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': 'Construction',    'key': 'construction',   'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🚰', 'name': 'Water Supply',    'key': 'water',          'bg': const Color(0xFFF0FDF4)},
      {'emoji': '💡', 'name': 'Electricity',     'key': 'electricity',    'bg': const Color(0xFFFFFBEB)},
      {'emoji': '🗑️', 'name': 'Garbage',         'key': 'garbage',        'bg': const Color(0xFFECFDF5)},
      {'emoji': '🛣️', 'name': 'Road / Pothole',  'key': 'road',           'bg': const Color(0xFFFAF5FF)},
      {'emoji': '🌊', 'name': 'Drainage',        'key': 'drainage',       'bg': const Color(0xFFEFF6FF)},
      {'emoji': '⚠️', 'name': 'Illegal Activity','key': 'illegal',        'bg': const Color(0xFFFFF1F2)},
      {'emoji': '🚌', 'name': 'Transportation',  'key': 'transportation', 'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🛡️', 'name': 'Cyber Crime',     'key': 'cyber',          'bg': const Color(0xFFF5F3FF)},
      {'emoji': '📋', 'name': 'Other',           'key': 'other',          'bg': const Color(0xFFF8FAFC)},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Submit a Complaint',
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text('Choose a category to report an issue',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
        children: categories.map((c) {
          final bg = c['bg'] as Color;
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.submitComplaint,
                arguments: {'categoryKey': c['key'], 'categoryName': c['name']}),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c['emoji'] as String, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 6),
                      Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ]),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Center(
                      child: Text(c['name'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: const Color(0xFF0f172a))),
                    ),
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _bottomNav() {
    final items = [
      {'emoji': '🏠', 'label': 'Home'},
      {'emoji': '📝', 'label': 'Submit'},
      {'emoji': '🔍', 'label': 'Track'},
      {'emoji': '🔑', 'label': 'Login'},
    ];
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, -2))]),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom, top: 8, left: 16, right: 16),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: active ? const Color(0x1A1E66F5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(items[i]['emoji'] as String,
                      style: TextStyle(fontSize: active ? 24 : 22)),
                  const SizedBox(height: 3),
                  Text(items[i]['label'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active ? const Color(0xFF1E66F5) : const Color(0xFF64748b))),
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
