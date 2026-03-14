import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class DepartmentsListScreen extends StatefulWidget {
  const DepartmentsListScreen({super.key});
  @override
  State<DepartmentsListScreen> createState() => _DepartmentsListScreenState();
}

class _DepartmentsListScreenState extends State<DepartmentsListScreen> {
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  // Gradient map matching home page style
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

  static const _emojiMap = {
    'police': '🚓', 'traffic': '🚦', 'construction': '🏗️',
    'water': '🚰', 'electricity': '💡', 'garbage': '🗑️',
    'road': '🛣️', 'drainage': '🌊', 'illegal': '⚠️',
    'transportation': '🚌', 'cyber': '🛡️', 'other': '📋',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _fallbackDepts = [
    {'name': 'Police', 'department_type': 'police', 'department_type_display': 'Police'},
    {'name': 'Traffic', 'department_type': 'traffic', 'department_type_display': 'Traffic'},
    {'name': 'Construction', 'department_type': 'construction', 'department_type_display': 'Construction'},
    {'name': 'Water Supply', 'department_type': 'water', 'department_type_display': 'Water Supply'},
    {'name': 'Electricity', 'department_type': 'electricity', 'department_type_display': 'Electricity'},
    {'name': 'Garbage', 'department_type': 'garbage', 'department_type_display': 'Garbage'},
    {'name': 'Road / Pothole', 'department_type': 'road', 'department_type_display': 'Road'},
    {'name': 'Drainage', 'department_type': 'drainage', 'department_type_display': 'Drainage'},
    {'name': 'Illegal Activity', 'department_type': 'illegal', 'department_type_display': 'Illegal Activity'},
    {'name': 'Transportation', 'department_type': 'transportation', 'department_type_display': 'Transportation'},
    {'name': 'Cyber Crime', 'department_type': 'cyber', 'department_type_display': 'Cyber Crime'},
    {'name': 'Other', 'department_type': 'other', 'department_type_display': 'Other'},
  ];

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(ApiConfig.departments, includeAuth: false);
      if (mounted && res['success'] == true) {
        final list = (res['departments'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (list.isNotEmpty) {
          setState(() { _departments = list; _filtered = list; _loading = false; });
          return;
        }
      }
    } catch (_) {}
    final fallback = _fallbackDepts.map((e) => Map<String, dynamic>.from(e)).toList();
    if (mounted) setState(() { _departments = fallback; _filtered = fallback; _loading = false; });
  }

  void _search(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = _departments.where((d) =>
        (d['name'] ?? '').toString().toLowerCase().contains(query) ||
        (d['city'] ?? '').toString().toLowerCase().contains(query) ||
        (d['department_type_display'] ?? '').toString().toLowerCase().contains(query),
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        _topNav(),
        _searchBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E66F5)))
              : _filtered.isEmpty
                  ? Center(child: Text('No departments found',
                      style: GoogleFonts.inter(color: const Color(0xFF64748b))))
                  : RefreshIndicator(
                      color: const Color(0xFF1E66F5),
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _deptCard(_filtered[i]),
                      ),
                    ),
        ),
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
        Image.asset('assets/images/logo.png', height: 32),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Departments',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: const Color(0xFF0f172a))),
          Text('${_filtered.length} available',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
        ]),
      ]),
    );
  }

  Widget _searchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _search,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
          decoration: InputDecoration(
            hintText: 'Search departments...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748b), size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _deptCard(Map<String, dynamic> d) {
    final type = (d['department_type'] ?? 'other').toString();
    final emoji = _emojiMap[type] ?? '🏢';
    final grads = _gradients[type] ?? [const Color(0xFF89f7fe), const Color(0xFF66a6ff)];
    final name = (d['name'] ?? 'Department').toString();
    final typeDisplay = (d['department_type_display'] ?? type).toString();
    final city = (d['city'] ?? '').toString();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.departmentDetail, arguments: d),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Gradient emoji box — same as home page
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: grads),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: const Color(0xFF0f172a))),
          ),
          const SizedBox(height: 3),
          Text(typeDisplay,
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF1E66F5),
                  fontWeight: FontWeight.w500)),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF64748b)),
              const SizedBox(width: 2),
              Text(city,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748b))),
            ]),
          ],
        ]),
      ),
    );
  }
}
