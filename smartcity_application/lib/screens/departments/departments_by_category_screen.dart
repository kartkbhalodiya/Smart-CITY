import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';
import '../../l10n/app_strings.dart';

class DepartmentsByCategoryScreen extends StatefulWidget {
  final String categoryKey;
  final String categoryName;
  final String categoryEmoji;
  final Color categoryBg;
  final String? categoryAsset;

  const DepartmentsByCategoryScreen({
    super.key,
    required this.categoryKey,
    required this.categoryName,
    required this.categoryEmoji,
    required this.categoryBg,
    this.categoryAsset,
  });

  @override
  State<DepartmentsByCategoryScreen> createState() =>
      _DepartmentsByCategoryScreenState();
}

class _DepartmentsByCategoryScreenState
    extends State<DepartmentsByCategoryScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _primary = Color(0xFF2F80ED);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);

  static const _categoryAssetMap = {
    'police': 'assets/images/cat_police.png',
    'traffic': 'assets/images/cat_traffic.png',
    'construction': 'assets/images/cat_construction.png',
    'water': 'assets/images/cat_waste_overflow.png',
    'electric': 'assets/images/cat_electric.png',
    'electricity': 'assets/images/cat_electric.png',
    'garbage': 'assets/images/cat_garbage.png',
    'road': 'assets/images/cat_roads.png',
    'roads': 'assets/images/cat_roads.png',
    'drainage': 'assets/images/cat_drainage.png',
    'illegal': 'assets/images/cat_illegal.png',
    'transport': 'assets/images/cat_transportation.png',
    'transportation': 'assets/images/cat_transportation.png',
    'cyber': 'assets/images/cat_cyber.png',
    'other': 'assets/images/cat_other.png',
  };

  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;

  String get _categoryAsset =>
      widget.categoryAsset ??
      _categoryAssetMap[widget.categoryKey] ??
      _categoryAssetMap['other']!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await ApiService.get(ApiConfig.departments, includeAuth: false);
      if (mounted && res['success'] == true) {
        final all = (res['departments'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        // Filter by category key
        final filtered = all
            .where((d) =>
                (d['department_type'] ?? '').toString() == widget.categoryKey)
            .toList();
        setState(() {
          _departments = filtered;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _departments = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: _topNav(),
          ),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _topNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: _cardDecoration(radius: 24),
      child: Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _line),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            _categoryAsset,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.corporate_fare_rounded,
              color: _primary,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              AppStrings.t(context, widget.categoryName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _loading
                  ? AppStrings.t(context, 'Loading...')
                  : '${_departments.length} ${AppStrings.t(context, _departments.length == 1 ? 'department' : 'departments')}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_departments.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        itemCount: _departments.length,
        itemBuilder: (_, i) => _deptCard(_departments[i]),
      ),
    );
  }

  Widget _emptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 46, 32, 32),
        child: Column(children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              _categoryAsset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.corporate_fare_rounded,
                color: _primary,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(AppStrings.t(context, 'No Departments Found'),
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 8),
          Text(
              '${AppStrings.t(context, 'No')} ${widget.categoryName} ${AppStrings.t(context, 'departments')}\n${AppStrings.t(context, 'have been added by the admin yet.')}',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(fontSize: 14, color: _muted, height: 1.45)),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      AppStrings.t(context,
                          'Once the admin adds departments for this category, they will appear here.'),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _muted, height: 1.45))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _deptCard(Map<String, dynamic> d) {
    final name = (d['name'] ?? AppStrings.t(context, 'Department')).toString();
    final city = (d['city'] ?? '').toString();
    final state = (d['state'] ?? '').toString();
    final address = (d['address'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final email = (d['email'] ?? '').toString();
    final assignedAdmin = (d['assigned_admin'] ?? '').toString();
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.departmentDetail,
        arguments: {
          ...d,
          'category_asset': _categoryAsset,
          'category_name': widget.categoryName,
        },
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: _cardDecoration(radius: 22),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(22),
            ),
            child: SizedBox(
              width: 86,
              height: 116,
              child: Image.asset(
                _categoryAsset,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  color: _primary.withValues(alpha: 0.09),
                  child: const Icon(
                    Icons.corporate_fare_rounded,
                    color: _primary,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),

          // Right content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _text)),
                    if (assignedAdmin.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 13, color: _muted),
                        const SizedBox(width: 4),
                        Flexible(
                            child: Text(assignedAdmin,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _muted))),
                      ]),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: _muted),
                        const SizedBox(width: 4),
                        Flexible(
                            child: Text(location,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _muted))),
                      ]),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.home_outlined,
                                size: 13, color: _muted),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontSize: 11, color: _muted))),
                          ]),
                    ],
                    const SizedBox(height: 8),
                    // Contact chips
                    Row(children: [
                      if (phone.isNotEmpty)
                        _chip(Icons.phone_rounded, phone,
                            const Color(0xFF22C55E), const Color(0xFFDCFCE7)),
                      if (phone.isNotEmpty && email.isNotEmpty)
                        const SizedBox(width: 6),
                      if (email.isNotEmpty)
                        Flexible(
                            child: _chip(Icons.email_outlined, email, _primary,
                                const Color(0xFFEFF7FF))),
                    ]),
                  ]),
            ),
          ),

          // Arrow
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _muted,
            ),
          ),
        ]),
      ),
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
    );
  }

  Widget _chip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
  }
}
