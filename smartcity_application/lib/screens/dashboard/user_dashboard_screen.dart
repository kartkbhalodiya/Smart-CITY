import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../models/complaint.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});
  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _tab = 0;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComplaintProvider>().loadDashboardStats();
      context.read<ComplaintProvider>().loadComplaints();
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
          onRefresh: () => context.read<ComplaintProvider>().refresh(),
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
    final user = context.watch<AuthProvider>().user;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
      child: Row(children: [
        Image.asset('assets/images/logo.png', height: 36),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user?.fullName ?? 'User',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
          Text('Welcome back!',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1E66F5), borderRadius: BorderRadius.circular(10)),
            child: Text('Profile',
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
    final stats = context.watch<ComplaintProvider>().stats;
    final isLoading = context.watch<ComplaintProvider>().isLoading;
    
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
            Text('Dashboard Overview 📊',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Track your complaints and view city statistics.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.85))),
          ])),
          const SizedBox(width: 12),
          const Text('✨', style: TextStyle(fontSize: 52)),
        ]),
      ),
      const SizedBox(height: 24),

      // Live Stats — real data without blur
      Row(children: [
        Text('Live Stats',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(width: 8),
        if (isLoading)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5))),
      ]),
      const SizedBox(height: 12),
      _statsGrid(stats, isLoading),
      const SizedBox(height: 24),

      // Departments
      Text('Departments',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 12),
      _departmentsGrid(),
    ]);
  }

  Widget _trackTab() {
    final complaints = context.watch<ComplaintProvider>().complaints;
    final isLoading = context.watch<ComplaintProvider>().isLoading;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('My Complaints',
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text('Track the status of your reported issues',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
      const SizedBox(height: 20),
      
      if (isLoading)
        const Center(child: CircularProgressIndicator(color: Color(0xFF1E66F5)))
      else if (complaints.isEmpty)
        _emptyState()
      else
        _complaintsList(complaints),
    ]);
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(children: [
        const Text('📝', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        Text('No complaints yet',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(height: 8),
        Text('Submit your first complaint to get started',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => setState(() { _tab = 1; _navIndex = 1; }),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E66F5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Submit Complaint',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _complaintsList(List<Complaint> complaints) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final complaint = complaints[index];
        return _complaintCard(complaint);
      },
    );
  }

  Widget _complaintCard(Complaint complaint) {
    final statusColor = _getStatusColor(complaint.workStatus);
    final statusText = _getStatusText(complaint.workStatus);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.complaintDetail,
            arguments: {'complaintId': complaint.id},
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusText,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
                const Spacer(),
                Text('#${complaint.complaintNumber}',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
              ]),
              const SizedBox(height: 12),
              Text(complaint.complaintType,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
              const SizedBox(height: 4),
              Text(complaint.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 16, color: const Color(0xFF64748b)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${complaint.city}, ${complaint.pincode}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time, size: 16, color: const Color(0xFF64748b)),
                const SizedBox(width: 4),
                Text(_formatDate(complaint.createdAt.toIso8601String()),
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFEF4444);
      case 'confirmed': return const Color(0xFFF97316);
      case 'process': return const Color(0xFFEAB308);
      case 'solved': return const Color(0xFF22C55E);
      case 'reopened': return const Color(0xFF991B1B);
      default: return const Color(0xFF94A3B8);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'process': return 'In Progress';
      case 'solved': return 'Solved';
      case 'reopened': return 'Reopened';
      default: return 'Unknown';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _statsGrid(dynamic stats, bool isLoading) {
    final items = [
      {'emoji': '📊', 'label': 'Total Complaints', 'count': stats?.totalComplaints ?? 0, 'color': const Color(0xFFEEF2FF)},
      {'emoji': '⏳', 'label': 'Pending', 'count': stats?.pendingComplaints ?? 0, 'color': const Color(0xFFFFF1F2)},
      {'emoji': '✅', 'label': 'Solved', 'count': stats?.resolvedComplaints ?? 0, 'color': const Color(0xFFF0FDF4)},
      {'emoji': '🔄', 'label': 'In Progress', 'count': stats?.inProgressComplaints ?? 0, 'color': const Color(0xFFEFF6FF)},
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: items.map((item) => _statCard(item, isLoading)).toList(),
    );
  }

  Widget _statCard(Map item, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['emoji'] as String, style: const TextStyle(fontSize: 36)),
        const Spacer(),
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5)),
          )
        else
          Text('${item['count']}',
              style: GoogleFonts.poppins(
                  fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFF0f172a))),
        Text(item['label'] as String,
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF64748b), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _departmentsGrid() {
    final depts = [
      {'emoji': '🚓', 'name': 'Police', 'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': 'Traffic', 'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': 'Construction', 'bg': const Color(0xFFF0F9FF)},
    ];
    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: depts.map((d) => Expanded(child: Padding(
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
      {'emoji': '👤', 'label': 'Profile'},
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
                else Navigator.pushNamed(context, AppRoutes.profile);
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