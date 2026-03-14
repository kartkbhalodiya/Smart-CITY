import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0; // 0=dashboard, 1=submit, 2=my complaints
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<ComplaintProvider>(context, listen: false);
      if (p.stats == null) p.loadDashboardStats();
      if (p.complaints.isEmpty) p.loadComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        _topNav(),
        Expanded(child: RefreshIndicator(
          color: const Color(0xFF1E66F5),
          onRefresh: () => Provider.of<ComplaintProvider>(context, listen: false).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(children: [
              _tabNav(),
              if (_tab == 0) _dashboardTab(),
              if (_tab == 1) _submitTab(),
              if (_tab == 2) _myComplaintsTab(),
            ]),
          ),
        )),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _topNav() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final name = user?.fullName ?? 'User';
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
      child: Row(children: [
        Image.asset('assets/images/logo.png', height: 36),
        const Spacer(),
        _navIcon(Icons.search, () {}),
        const SizedBox(width: 8),
        _navIcon(Icons.notifications_outlined, () {}),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF1E66F5),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _navIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, size: 20, color: const Color(0xFF0f172a)),
      ),
    );
  }

  Widget _tabNav() {
    final tabs = ['Dashboard', 'Submit Complaint', 'My Complaints'];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(children: List.generate(3, (i) => Expanded(child: GestureDetector(
        onTap: () => setState(() { _tab = i; _navIndex = i == 2 ? 2 : i; }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: _tab == i ? const Color(0xFF1E66F5) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(tabs[i], textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _tab == i ? Colors.white : const Color(0xFF64748b))),
        ),
      )))),
    );
  }

  Widget _dashboardTab() {
    return Consumer<ComplaintProvider>(builder: (context, p, _) {
      final stats = p.stats;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stats grid
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
          children: [
            _statCard('📊', stats?.totalComplaints ?? 0, 'Total Complaints', const [Color(0xFF667eea), Color(0xFF764ba2)]),
            _statCard('⏳', stats?.pendingComplaints ?? 0, 'Pending', const [Color(0xFFf093fb), Color(0xFFf5576c)]),
            _statCard('🔄', stats?.inProgressComplaints ?? 0, 'In Progress', const [Color(0xFFfbc2eb), Color(0xFFa6c1ee)]),
            _statCard('✅', stats?.resolvedComplaints ?? 0, 'Solved', const [Color(0xFFa8edea), Color(0xFFfed6e3)]),
          ],
        ),
        const SizedBox(height: 24),
        _sectionHeader('Recent Complaints', () => setState(() => _tab = 2)),
        _complaintsList(p.complaints.take(3).toList()),
        const SizedBox(height: 24),
        _sectionHeader('Departments', () {}),
        _departmentsGrid(),
      ]);
    });
  }

  Widget _statCard(String emoji, int count, String label, List<Color> gradColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(height: 10),
        Text('$count', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        GestureDetector(onTap: onViewAll, child: Row(children: [
          Text('View All', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E66F5), fontWeight: FontWeight.w600)),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF1E66F5)),
        ])),
      ]),
    );
  }

  Widget _complaintsList(List complaints) {
    if (complaints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Center(child: Text('No complaints yet', style: GoogleFonts.inter(color: const Color(0xFF64748b)))),
      );
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(children: complaints.map((c) => _complaintItem(c)).toList()),
    );
  }

  Widget _complaintItem(complaint) {
    final statusColors = {
      'pending': const Color(0xFFfee2e2), 'confirmed': const Color(0xFFfed7aa),
      'process': const Color(0xFFfef3c7), 'solved': const Color(0xFFdcfce7), 'reopened': const Color(0xFFfce7f3),
    };
    final statusTextColors = {
      'pending': const Color(0xFF991b1b), 'confirmed': const Color(0xFF9a3412),
      'process': const Color(0xFF854d0e), 'solved': const Color(0xFF166534), 'reopened': const Color(0xFF831843),
    };
    final bg = statusColors[complaint.workStatus] ?? const Color(0xFFf1f5f9);
    final tc = statusTextColors[complaint.workStatus] ?? const Color(0xFF64748b);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.complaintDetail, arguments: {'complaintId': complaint.id}),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text('#${complaint.complaintNumber}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(complaint.complaintType, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
            Text(complaint.city ?? '', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Text(complaint.workStatus, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: tc)),
          ),
        ]),
      ),
    );
  }

  Widget _departmentsGrid() {
    final depts = [
      {'icon': '🚔', 'name': 'Police'}, {'icon': '🚦', 'name': 'Traffic'},
      {'icon': '🏗️', 'name': 'Construction'}, {'icon': '💧', 'name': 'Water Supply'},
      {'icon': '💡', 'name': 'Electricity'}, {'icon': '🗑️', 'name': 'Garbage'},
    ];
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)], [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)], [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)], [const Color(0xFF30cfd0), const Color(0xFF330867)],
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
      children: List.generate(depts.length, (i) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradients[i]), borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(depts[i]['icon']!, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(height: 10),
          Text(depts[i]['name']!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
        ]),
      )),
    );
  }

  Widget _submitTab() {
    final categories = [
      {'icon': '🚔', 'name': 'Police', 'key': 'police'}, {'icon': '🚦', 'name': 'Traffic', 'key': 'traffic'},
      {'icon': '🏗️', 'name': 'Construction', 'key': 'construction'}, {'icon': '💧', 'name': 'Water Supply', 'key': 'water'},
      {'icon': '💡', 'name': 'Electricity', 'key': 'electricity'}, {'icon': '🗑️', 'name': 'Garbage', 'key': 'garbage'},
      {'icon': '🚧', 'name': 'Road/Pothole', 'key': 'road'}, {'icon': '🌊', 'name': 'Drainage', 'key': 'drainage'},
      {'icon': '⚠️', 'name': 'Illegal Activity', 'key': 'illegal'}, {'icon': '🚌', 'name': 'Transportation', 'key': 'transportation'},
      {'icon': '🛡️', 'name': 'Cyber Crime', 'key': 'cyber'}, {'icon': '📋', 'name': 'Other', 'key': 'other'},
    ];
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)], [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)], [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)], [const Color(0xFF30cfd0), const Color(0xFF330867)],
      [const Color(0xFFa8edea), const Color(0xFFfed6e3)], [const Color(0xFFfbc2eb), const Color(0xFFa6c1ee)],
      [const Color(0xFFfdcbf1), const Color(0xFFe6dee9)], [const Color(0xFFa1c4fd), const Color(0xFFc2e9fb)],
      [const Color(0xFFd299c2), const Color(0xFFfef9d7)], [const Color(0xFF89f7fe), const Color(0xFF66a6ff)],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('What do you want to report?', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text('Choose a category to submit your complaint', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1,
        children: List.generate(categories.length, (i) => GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.submitComplaint, arguments: {'categoryKey': categories[i]['key'], 'categoryName': categories[i]['name']}),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.transparent, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(gradient: LinearGradient(colors: gradients[i]), borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(categories[i]['icon']!, style: const TextStyle(fontSize: 30))),
              ),
              const SizedBox(height: 10),
              Text(categories[i]['name']!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
            ]),
          ),
        )),
      ),
    ]);
  }

  Widget _myComplaintsTab() {
    return Consumer<ComplaintProvider>(builder: (context, p, _) {
      if (p.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E66F5)));
      if (p.complaints.isEmpty) {
        return Column(children: [
          const SizedBox(height: 60),
          const Icon(Icons.inbox_outlined, size: 64, color: Color(0xFFcbd5e1)),
          const SizedBox(height: 16),
          Text('No complaints found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
          const SizedBox(height: 8),
          Text("You haven't submitted any complaints yet", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
          const SizedBox(height: 16),
          GestureDetector(onTap: () => setState(() => _tab = 1), child: Text('Submit your first complaint', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E66F5), fontWeight: FontWeight.w600))),
        ]);
      }
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Column(children: p.complaints.map((c) => _complaintItem(c)).toList()),
      );
    });
  }

  Widget _bottomNav() {
    final items = [
      {'icon': Icons.home_outlined, 'label': 'Dashboard'},
      {'icon': Icons.add_circle_outline, 'label': 'Submit'},
      {'icon': Icons.checklist_outlined, 'label': 'Track'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];
    return Container(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, -2))]),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, top: 8, left: 16, right: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(4, (i) {
        final active = _navIndex == i;
        return GestureDetector(
          onTap: () {
            if (i == 0) setState(() { _navIndex = 0; _tab = 0; });
            else if (i == 1) setState(() { _navIndex = 1; _tab = 1; });
            else if (i == 2) { setState(() { _navIndex = 2; _tab = 2; }); Navigator.pushNamed(context, AppRoutes.trackComplaints); }
            else if (i == 3) Navigator.pushNamed(context, AppRoutes.profile);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: active ? const Color(0x1A1E66F5) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(items[i]['icon'] as IconData, size: 22, color: active ? const Color(0xFF1E66F5) : const Color(0xFF64748b)),
              const SizedBox(height: 4),
              Text(items[i]['label'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: active ? const Color(0xFF1E66F5) : const Color(0xFF64748b))),
            ]),
          ),
        );
      })),
    );
  }
}
