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
  int _tab = 0; // 0=home, 1=submit
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
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
      child: Row(children: [
        Image.asset('assets/images/logo.png', height: 36),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Guest Mode', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
          Text('Limited access', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E66F5), borderRadius: BorderRadius.circular(10)),
            child: Text('Login', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(children: List.generate(2, (i) => Expanded(child: GestureDetector(
        onTap: () => setState(() { _tab = i; _navIndex = i; }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: _tab == i ? const Color(0xFF1E66F5) : Colors.transparent,
              borderRadius: BorderRadius.circular(8)),
          child: Text(tabs[i], textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _tab == i ? Colors.white : const Color(0xFF64748b))),
        ),
      )))),
    );
  }

  Widget _homeTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Guest banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF154ec7)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome, Guest! 👋', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('You can submit complaints & view departments.\nLogin for full access.', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.85))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text('Login / Register', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5))),
              ),
            ),
          ])),
          const SizedBox(width: 12),
          const Icon(Icons.person_outline, size: 56, color: Colors.white24),
        ]),
      ),
      const SizedBox(height: 24),

      // Live stats
      Row(children: [
        Text('Live Stats', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(width: 8),
        if (_statsLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5))),
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
        children: [
          _statCard('📊', _total, 'Total Complaints', const [Color(0xFF667eea), Color(0xFF764ba2)]),
          _statCard('⏳', _pending, 'Pending', const [Color(0xFFf093fb), Color(0xFFf5576c)]),
          _statCard('✅', _solved, 'Solved', const [Color(0xFF43e97b), Color(0xFF38f9d7)]),
          _statCard('🏢', _depts, 'Departments', const [Color(0xFF4facfe), Color(0xFF00f2fe)]),
        ],
      ),
      const SizedBox(height: 24),

      // Departments section
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Departments', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      ]),
      const SizedBox(height: 12),
      _departmentsGrid(),
      const SizedBox(height: 24),

      // Locked features banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(children: [
          const Icon(Icons.lock_outline, size: 32, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text('Login to unlock full features', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
          const SizedBox(height: 4),
          Text('Track your complaints • View profile • Get updates', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b)), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _lockedFeature(Icons.checklist_outlined, 'Track'),
            const SizedBox(width: 16),
            _lockedFeature(Icons.person_outline, 'Profile'),
            const SizedBox(width: 16),
            _lockedFeature(Icons.notifications_outlined, 'Updates'),
          ]),
        ]),
      ),
    ]);
  }

  Widget _lockedFeature(IconData icon, String label) {
    return Column(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _statCard(String emoji, int count, String label, List<Color> gradColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(height: 10),
        Text('$count', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _departmentsGrid() {
    final depts = [
      {'icon': '🚔', 'name': 'Police', 'grad': [const Color(0xFF667eea), const Color(0xFF764ba2)]},
      {'icon': '🚦', 'name': 'Traffic', 'grad': [const Color(0xFFf093fb), const Color(0xFFf5576c)]},
      {'icon': '🏗️', 'name': 'Construction', 'grad': [const Color(0xFF4facfe), const Color(0xFF00f2fe)]},
      {'icon': '💧', 'name': 'Water Supply', 'grad': [const Color(0xFF43e97b), const Color(0xFF38f9d7)]},
      {'icon': '💡', 'name': 'Electricity', 'grad': [const Color(0xFFfa709a), const Color(0xFFfee140)]},
      {'icon': '🗑️', 'name': 'Garbage', 'grad': [const Color(0xFF30cfd0), const Color(0xFF330867)]},
    ];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.95,
      children: depts.map((d) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(gradient: LinearGradient(colors: d['grad'] as List<Color>), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(d['icon'] as String, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(height: 8),
          Text(d['name'] as String, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
        ]),
      )).toList(),
    );
  }

  Widget _submitTab() {
    final categories = [
      {'icon': '🚔', 'name': 'Police', 'key': 'police', 'grad': [const Color(0xFF667eea), const Color(0xFF764ba2)]},
      {'icon': '🚦', 'name': 'Traffic', 'key': 'traffic', 'grad': [const Color(0xFFf093fb), const Color(0xFFf5576c)]},
      {'icon': '🏗️', 'name': 'Construction', 'key': 'construction', 'grad': [const Color(0xFF4facfe), const Color(0xFF00f2fe)]},
      {'icon': '💧', 'name': 'Water Supply', 'key': 'water', 'grad': [const Color(0xFF43e97b), const Color(0xFF38f9d7)]},
      {'icon': '💡', 'name': 'Electricity', 'key': 'electricity', 'grad': [const Color(0xFFfa709a), const Color(0xFFfee140)]},
      {'icon': '🗑️', 'name': 'Garbage', 'key': 'garbage', 'grad': [const Color(0xFF30cfd0), const Color(0xFF330867)]},
      {'icon': '🚧', 'name': 'Road/Pothole', 'key': 'road', 'grad': [const Color(0xFFa8edea), const Color(0xFFfed6e3)]},
      {'icon': '🌊', 'name': 'Drainage', 'key': 'drainage', 'grad': [const Color(0xFFfbc2eb), const Color(0xFFa6c1ee)]},
      {'icon': '⚠️', 'name': 'Illegal Activity', 'key': 'illegal', 'grad': [const Color(0xFFfdcbf1), const Color(0xFFe6dee9)]},
      {'icon': '🚌', 'name': 'Transportation', 'key': 'transportation', 'grad': [const Color(0xFFa1c4fd), const Color(0xFFc2e9fb)]},
      {'icon': '🛡️', 'name': 'Cyber Crime', 'key': 'cyber', 'grad': [const Color(0xFFd299c2), const Color(0xFFfef9d7)]},
      {'icon': '📋', 'name': 'Other', 'key': 'other', 'grad': [const Color(0xFF89f7fe), const Color(0xFF66a6ff)]},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Submit a Complaint', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text('Choose a category to report an issue', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.1,
        children: categories.map((c) => GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.submitComplaint,
              arguments: {'categoryKey': c['key'], 'categoryName': c['name']}),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(gradient: LinearGradient(colors: c['grad'] as List<Color>), borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(c['icon'] as String, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(height: 10),
              Text(c['name'] as String, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
            ]),
          ),
        )).toList(),
      ),
    ]);
  }

  Widget _bottomNav() {
    final items = [
      {'icon': Icons.home_outlined, 'label': 'Home'},
      {'icon': Icons.add_circle_outline, 'label': 'Submit'},
      {'icon': Icons.login_outlined, 'label': 'Login'},
    ];
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, -2))]),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, top: 8, left: 16, right: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(3, (i) {
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
              Icon(items[i]['icon'] as IconData, size: 22,
                  color: active ? const Color(0xFF1E66F5) : const Color(0xFF64748b)),
              const SizedBox(height: 4),
              Text(items[i]['label'] as String,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                      color: active ? const Color(0xFF1E66F5) : const Color(0xFF64748b))),
            ]),
          ),
        );
      })),
    );
  }
}
