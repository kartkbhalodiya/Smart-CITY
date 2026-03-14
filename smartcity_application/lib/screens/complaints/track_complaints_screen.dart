import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/complaint_provider.dart';
import '../../models/complaint.dart';

class TrackComplaintsScreen extends StatefulWidget {
  const TrackComplaintsScreen({super.key});
  @override
  State<TrackComplaintsScreen> createState() => _TrackComplaintsScreenState();
}

class _TrackComplaintsScreenState extends State<TrackComplaintsScreen> {
  String _filter = 'all';
  final _searchController = TextEditingController();
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<ComplaintProvider>(context, listen: false);
      if (p.complaints.isEmpty) p.loadComplaints();
    });
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        _header(),
        Expanded(child: Consumer<ComplaintProvider>(builder: (context, p, _) {
          if (p.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF2B6CF6)));
          if (p.error != null && p.complaints.isEmpty) {
            return Column(children: [
              _searchBar(),
              _filterTabs(),
              const SizedBox(height: 60),
              const Icon(Icons.wifi_off_outlined, size: 64, color: Color(0xFFcbd5e1)),
              const SizedBox(height: 16),
              Text('Could not load complaints', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1a202c))),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(p.error!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF718096)), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => p.loadComplaints(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF2B6CF6), borderRadius: BorderRadius.circular(12)),
                  child: Text('Retry', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]);
          }
          var complaints = p.complaints;
          if (_filter != 'all') complaints = complaints.where((c) => c.workStatus == _filter).toList();
          final q = _searchController.text.toLowerCase();
          if (q.isNotEmpty) complaints = complaints.where((c) => c.complaintNumber.toLowerCase().contains(q) || c.title.toLowerCase().contains(q)).toList();
          return Column(children: [
            _searchBar(),
            _filterTabs(),
            Expanded(child: complaints.isEmpty ? _emptyState() : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: complaints.length,
              itemBuilder: (_, i) => _complaintCard(complaints[i]),
            )),
          ]);
        })),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))]),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1a202c))),
        ),
        const SizedBox(width: 16),
        Text('Track Complaints', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1a202c))),
        const Spacer(),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.filter_list, size: 20, color: Color(0xFF1a202c))),
      ]),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: const Color(0xFFF1F4F9), borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1a202c)),
          decoration: InputDecoration(
            hintText: 'Search by complaint ID, title...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF718096)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF718096), size: 20),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _filterTabs() {
    final tabs = [('all', 'All'), ('pending', 'Pending'), ('confirmed', 'Confirmed'), ('process', 'In Progress'), ('solved', 'Completed')];
    return Container(
      height: 48, margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tabs.map((t) => GestureDetector(
          onTap: () => setState(() => _filter = t.$1),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _filter == t.$1 ? const Color(0xFF2B6CF6) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(t.$2, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _filter == t.$1 ? Colors.white : const Color(0xFF718096))),
          ),
        )).toList(),
      ),
    );
  }

  Widget _complaintCard(Complaint c) {
    final isExpanded = _expanded.contains(c.id);
    final statusConfig = _statusConfig(c.workStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(children: [
        // Compact header - always visible
        GestureDetector(
          onTap: () => setState(() { if (isExpanded) _expanded.remove(c.id); else _expanded.add(c.id); }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isExpanded ? const Color(0xFFF7F9FC) : Colors.white, borderRadius: isExpanded ? const BorderRadius.vertical(top: Radius.circular(16)) : BorderRadius.circular(16)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${c.complaintNumber}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF2B6CF6))),
                const SizedBox(height: 4),
                Text(c.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1a202c))),
              ])),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(gradient: LinearGradient(colors: statusConfig['gradient'] as List<Color>), borderRadius: BorderRadius.circular(20)),
                child: Text(statusConfig['label'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: isExpanded ? const Color(0xFF2B6CF6) : const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(16)),
                child: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: isExpanded ? Colors.white : const Color(0xFF718096)),
              ),
            ]),
          ),
        ),
        // Expandable content
        if (isExpanded) Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE8EDF3))), borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            _timeline(c.workStatus),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.tag, size: 16, color: Color(0xFF2B6CF6)),
              const SizedBox(width: 8),
              Text(c.complaintType, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF718096))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2B6CF6)),
              const SizedBox(width: 8),
              Text(c.createdAt.toString().split(' ')[0], style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF718096))),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.complaintDetail, arguments: {'complaintId': c.id}),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF2B6CF6), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.visibility_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('View Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _timeline(String status) {
    final steps = [
      {'label': 'Submitted', 'icon': Icons.send_outlined, 'statuses': ['pending', 'confirmed', 'process', 'solved', 'reopened']},
      {'label': 'Assigned', 'icon': Icons.person_outline, 'statuses': ['confirmed', 'process', 'solved', 'reopened']},
      {'label': 'In Progress', 'icon': Icons.autorenew, 'statuses': ['process', 'solved', 'reopened']},
      {'label': 'Resolved', 'icon': Icons.check_circle_outline, 'statuses': ['solved', 'reopened']},
      {'label': 'Reopened', 'icon': Icons.refresh, 'statuses': ['reopened']},
    ];
    final stepColors = [const Color(0xFFF59E0B), const Color(0xFFEA580C), const Color(0xFF2563EB), const Color(0xFF10B981), const Color(0xFFDC2626)];

    return Row(children: List.generate(steps.length, (i) {
      final active = (steps[i]['statuses'] as List<String>).contains(status);
      return Expanded(child: Column(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            gradient: active ? LinearGradient(colors: [stepColors[i].withOpacity(0.8), stepColors[i]]) : null,
            color: active ? null : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(17),
            boxShadow: active ? [BoxShadow(color: stepColors[i].withOpacity(0.3), blurRadius: 8)] : null,
          ),
          child: Icon(steps[i]['icon'] as IconData, size: 16, color: active ? Colors.white : const Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 6),
        Text(steps[i]['label'] as String, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 8, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF1a202c) : const Color(0xFF718096))),
      ]));
    }));
  }

  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'pending': return {'label': 'Submitted', 'gradient': [const Color(0xFFFCD34D), const Color(0xFFF59E0B)]};
      case 'confirmed': return {'label': 'Assigned', 'gradient': [const Color(0xFFFB923C), const Color(0xFFEA580C)]};
      case 'process': return {'label': 'In Progress', 'gradient': [const Color(0xFF60A5FA), const Color(0xFF2563EB)]};
      case 'solved': return {'label': 'Resolved', 'gradient': [const Color(0xFF34D399), const Color(0xFF10B981)]};
      case 'reopened': return {'label': 'Reopened', 'gradient': [const Color(0xFFF87171), const Color(0xFFDC2626)]};
      default: return {'label': status, 'gradient': [const Color(0xFF94a3b8), const Color(0xFF64748b)]};
    }
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.inbox_outlined, size: 64, color: Color(0xFFcbd5e1)),
      const SizedBox(height: 16),
      Text('No complaints found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1a202c))),
      const SizedBox(height: 8),
      Text("You haven't submitted any complaints yet", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF718096))),
    ]));
  }

  Widget _bottomNav() {
    final items = [
      {'icon': Icons.home_outlined, 'label': 'Dashboard', 'route': AppRoutes.dashboard},
      {'icon': Icons.add_circle_outline, 'label': 'Submit', 'route': AppRoutes.categorySelection},
      {'icon': Icons.checklist_outlined, 'label': 'Track', 'route': AppRoutes.trackComplaints},
      {'icon': Icons.person_outline, 'label': 'Profile', 'route': AppRoutes.profile},
    ];
    return Container(
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, -2))]),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, top: 8, left: 16, right: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(4, (i) {
        final active = i == 2;
        return GestureDetector(
          onTap: () { if (!active) Navigator.pushReplacementNamed(context, items[i]['route'] as String); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: active ? const Color(0xFFE3F2FD) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(items[i]['icon'] as IconData, size: 20, color: active ? const Color(0xFF2B6CF6) : const Color(0xFF718096)),
              const SizedBox(height: 2),
              Text(items[i]['label'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: active ? const Color(0xFF2B6CF6) : const Color(0xFF718096))),
            ]),
          ),
        );
      })),
    );
  }
}
