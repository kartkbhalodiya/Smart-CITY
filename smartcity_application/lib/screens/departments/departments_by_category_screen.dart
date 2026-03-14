import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class DepartmentsByCategoryScreen extends StatefulWidget {
  final String categoryKey;
  final String categoryName;
  final String categoryEmoji;
  final Color categoryBg;

  const DepartmentsByCategoryScreen({
    super.key,
    required this.categoryKey,
    required this.categoryName,
    required this.categoryEmoji,
    required this.categoryBg,
  });

  @override
  State<DepartmentsByCategoryScreen> createState() => _DepartmentsByCategoryScreenState();
}

class _DepartmentsByCategoryScreenState extends State<DepartmentsByCategoryScreen> {
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(ApiConfig.departments, includeAuth: false);
      if (mounted && res['success'] == true) {
        final all = (res['departments'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        // Filter by category key
        final filtered = all.where((d) =>
            (d['department_type'] ?? '').toString() == widget.categoryKey).toList();
        setState(() { _departments = filtered; _loading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() { _departments = []; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        _topNav(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _topNav() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 8, right: 16, bottom: 12),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0f172a)),
          onPressed: () => Navigator.pop(context),
        ),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: widget.categoryBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(widget.categoryEmoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.categoryName,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: const Color(0xFF0f172a))),
          Text(_loading ? 'Loading...' : '${_departments.length} department${_departments.length == 1 ? '' : 's'}',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
        ]),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E66F5)));
    }

    if (_departments.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFF1E66F5),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _departments.length,
        itemBuilder: (_, i) => _deptCard(_departments[i]),
      ),
    );
  }

  Widget _emptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const SizedBox(height: 60),
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(color: widget.categoryBg, shape: BoxShape.circle),
            child: Center(child: Text(widget.categoryEmoji, style: const TextStyle(fontSize: 54))),
          ),
          Container(
            width: 55, height: 5,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.07),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 28),
          Text('No Departments Found',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
          const SizedBox(height: 8),
          Text('No ${widget.categoryName} departments\nhave been added by the admin yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFF64748b), height: 1.5)),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(children: [
              const Text('ℹ️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                  'Once the admin adds departments for this category, they will appear here.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF1D4ED8), height: 1.5))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _deptCard(Map<String, dynamic> d) {
    final name = (d['name'] ?? 'Department').toString();
    final city = (d['city'] ?? '').toString();
    final state = (d['state'] ?? '').toString();
    final address = (d['address'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final email = (d['email'] ?? '').toString();
    final assignedAdmin = (d['assigned_admin'] ?? '').toString();
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.departmentDetail, arguments: d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          // Left pastel emoji panel
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              color: widget.categoryBg,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(widget.categoryEmoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 4),
              Container(
                width: 28, height: 3,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ]),
          ),

          // Right content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: const Color(0xFF0f172a))),
                if (assignedAdmin.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748b)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(assignedAdmin,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b)))),
                  ]),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748b)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(location,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b)))),
                  ]),
                ],
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.home_outlined, size: 13, color: Color(0xFF64748b)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(address,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)))),
                  ]),
                ],
                const SizedBox(height: 8),
                // Contact chips
                Row(children: [
                  if (phone.isNotEmpty)
                    _chip(Icons.phone_rounded, phone, const Color(0xFF22C55E), const Color(0xFFDCFCE7)),
                  if (phone.isNotEmpty && email.isNotEmpty) const SizedBox(width: 6),
                  if (email.isNotEmpty)
                    Flexible(child: _chip(Icons.email_outlined, email, const Color(0xFF1E66F5), const Color(0xFFEFF6FF))),
                ]),
              ]),
            ),
          ),

          // Arrow
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
  }
}
