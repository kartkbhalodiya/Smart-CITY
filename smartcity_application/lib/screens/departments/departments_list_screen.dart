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

  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _accent = Color(0xFF1E66F5);

  // emoji map by department_type
  static const _emojiMap = {
    'police': '🚓', 'traffic': '🚦', 'construction': '🏗️',
    'water': '🚰', 'electricity': '💡', 'garbage': '🗑️',
    'road': '🛣️', 'drainage': '🌊', 'illegal': '⚠️',
    'transportation': '🚌', 'cyber': '🛡️', 'other': '📋',
  };

  static const _bgMap = {
    'police': Color(0xFF1E3A5F), 'traffic': Color(0xFF3B2A1A),
    'construction': Color(0xFF1A2E3B), 'water': Color(0xFF0F2E1E),
    'electricity': Color(0xFF2E2A0F), 'garbage': Color(0xFF0F2E1E),
    'road': Color(0xFF1E1A3B), 'drainage': Color(0xFF0F1E3B),
    'illegal': Color(0xFF3B1A1A), 'transportation': Color(0xFF2E1A1A),
    'cyber': Color(0xFF1A1A3B), 'other': Color(0xFF1A2A2A),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(ApiConfig.departments, includeAuth: false);
    if (mounted && res['success'] == true) {
      final list = (res['departments'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() { _departments = list; _filtered = list; });
    }
    setState(() => _loading = false);
  }

  void _search(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = _departments.where((d) {
        return (d['name'] ?? '').toString().toLowerCase().contains(query) ||
            (d['city'] ?? '').toString().toLowerCase().contains(query) ||
            (d['department_type_display'] ?? '').toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _topBar(),
        _searchBar(),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : _filtered.isEmpty
                ? Center(child: Text('No departments found',
                    style: GoogleFonts.inter(color: Colors.white54)))
                : RefreshIndicator(
                    color: _accent,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _deptCard(_filtered[i]),
                    ),
                  )),
      ]),
    );
  }

  Widget _topBar() {
    return Container(
      color: _card,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8, left: 8, right: 16, bottom: 14),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('All Departments',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('${_filtered.length} departments',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
        ]),
      ]),
    );
  }

  Widget _searchBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
            color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _search,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search by name, city, type...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
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
    final cardBg = _bgMap[type] ?? const Color(0xFF1A2A2A);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.departmentDetail, arguments: d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Emoji icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['name'] ?? 'Department',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 3),
              Text(d['department_type_display'] ?? type,
                  style: GoogleFonts.inter(fontSize: 12, color: _accent)),
              const SizedBox(height: 4),
              if ((d['city'] ?? '').toString().isNotEmpty)
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.white38),
                  const SizedBox(width: 3),
                  Text('${d['city']}, ${d['state'] ?? ''}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                ]),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ]),
        ),
      ),
    );
  }
}
