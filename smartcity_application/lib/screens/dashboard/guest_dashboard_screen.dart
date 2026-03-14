import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStats();
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
    final tabs = ['Home', 'Submit Complaint'];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(
          children: List.generate(
              2,
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

  // ── Departments grid — 3D emoji, no background box ─────────────────────
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
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: depts
          .map((d) => Container(
                decoration: BoxDecoration(
                  color: d['bg'] as Color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
                  ],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // Full-size emoji, no container/background
                  Text(d['emoji'] as String, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 6),
                  Text(d['name'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0f172a))),
                ]),
              ))
          .toList(),
    );
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

  // ── Submit tab ─────────────────────────────────────────────────────────────
  Widget _submitTab() {
    final categories = [
      {'emoji': '🚓', 'name': 'Police', 'key': 'police', 'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': 'Traffic', 'key': 'traffic', 'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': 'Construction', 'key': 'construction', 'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🚰', 'name': 'Water Supply', 'key': 'water', 'bg': const Color(0xFFF0FDF4)},
      {'emoji': '💡', 'name': 'Electricity', 'key': 'electricity', 'bg': const Color(0xFFFFFBEB)},
      {'emoji': '🗑️', 'name': 'Garbage', 'key': 'garbage', 'bg': const Color(0xFFECFDF5)},
      {'emoji': '🛣️', 'name': 'Road/Pothole', 'key': 'road', 'bg': const Color(0xFFFAF5FF)},
      {'emoji': '🌊', 'name': 'Drainage', 'key': 'drainage', 'bg': const Color(0xFFEFF6FF)},
      {'emoji': '⚠️', 'name': 'Illegal Activity', 'key': 'illegal', 'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🚌', 'name': 'Transportation', 'key': 'transportation', 'bg': const Color(0xFFFFF1F2)},
      {'emoji': '🛡️', 'name': 'Cyber Crime', 'key': 'cyber', 'bg': const Color(0xFFF5F3FF)},
      {'emoji': '📋', 'name': 'Other', 'key': 'other', 'bg': const Color(0xFFF8FAFC)},
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
        childAspectRatio: 1.05,
        children: categories
            .map((c) => GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.submitComplaint,
                      arguments: {'categoryKey': c['key'], 'categoryName': c['name']}),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c['bg'] as Color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
                      ],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      // Full emoji, no background box
                      Text(c['emoji'] as String, style: const TextStyle(fontSize: 42)),
                      const SizedBox(height: 10),
                      Text(c['name'] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0f172a))),
                    ]),
                  ),
                ))
            .toList(),
      ),
    ]);
  }

  Widget _bottomNav() {
    final items = [
      {'emoji': '🏠', 'label': 'Home'},
      {'emoji': '📝', 'label': 'Submit'},
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
          children: List.generate(3, (i) {
            final active = _navIndex == i;
            return GestureDetector(
              onTap: () {
                if (i == 0) setState(() { _navIndex = 0; _tab = 0; });
                else if (i == 1) setState(() { _navIndex = 1; _tab = 1; });
                else Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
