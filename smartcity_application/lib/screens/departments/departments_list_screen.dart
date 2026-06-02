import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/routes.dart';
import '../../l10n/app_strings.dart';

class DepartmentsListScreen extends StatelessWidget {
  const DepartmentsListScreen({super.key});
  static const _primary = Color(0xFF2F80ED);
  static const _bg = Color(0xFFF7F8FA);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);

  static const _assetMap = {
    'police': 'assets/images/cat_police.png',
    'traffic': 'assets/images/cat_traffic.png',
    'construction': 'assets/images/cat_construction.png',
    'water': 'assets/images/cat_waste_overflow.png',
    'electricity': 'assets/images/cat_electric.png',
    'garbage': 'assets/images/cat_garbage.png',
    'road': 'assets/images/cat_roads.png',
    'drainage': 'assets/images/cat_drainage.png',
    'illegal': 'assets/images/cat_illegal.png',
    'transportation': 'assets/images/cat_transportation.png',
    'cyber': 'assets/images/cat_cyber.png',
    'other': 'assets/images/cat_other.png',
  };

  static const _categories = [
    {'key': 'police', 'name': 'Police', 'bg': Color(0xFFEEF2FF)},
    {
      'key': 'traffic',
      'name': 'Traffic',
      'bg': Color(0xFFFFF7ED)
    },
    {
      'key': 'construction',
      'name': 'Construction',
      'bg': Color(0xFFF0F9FF)
    },
    {
      'key': 'water',
      'name': 'Water Supply',
      'bg': Color(0xFFF0FDF4)
    },
    {
      'key': 'electricity',
      'name': 'Electricity',
      'bg': Color(0xFFFFFBEB)
    },
    {
      'key': 'garbage',
      'name': 'Garbage',
      'bg': Color(0xFFECFDF5)
    },
    {
      'key': 'road',
      'name': 'Road / Pothole',
      'bg': Color(0xFFFAF5FF)
    },
    {
      'key': 'drainage',
      'name': 'Drainage',
      'bg': Color(0xFFEFF6FF)
    },
    {
      'key': 'illegal',
      'name': 'Illegal Activity',
      'bg': Color(0xFFFFF1F2)
    },
    {
      'key': 'transportation',
      'name': 'Transportation',
      'bg': Color(0xFFF0F9FF)
    },
    {
      'key': 'cyber',
      'name': 'Cyber Crime',
      'bg': Color(0xFFF5F3FF)
    },
    {'key': 'other', 'name': 'Other', 'bg': Color(0xFFF8FAFC)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Top nav
        Container(
          color: _bg,
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 8,
              right: 16,
              bottom: 12),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _text),
              onPressed: () => Navigator.pop(context),
            ),
            Image.asset('assets/images/logo.png', height: 32),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppStrings.t(context, 'Departments'),
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
              Text(AppStrings.t(context, 'Select a category'),
                  style: GoogleFonts.inter(fontSize: 11, color: _muted)),
            ]),
          ]),
        ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: _categories.length,
            itemBuilder: (_, i) => _categoryCard(context, _categories[i]),
          ),
        ),
      ]),
    );
  }

  Widget _categoryCard(BuildContext context, Map<String, Object> cat) {
    final bg = cat['bg'] as Color;
    final key = cat['key'] as String;
    final asset = _assetMap[key] ?? _assetMap['other']!;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.departmentsByCategory,
        arguments: {
          'key': key,
          'name': AppStrings.t(context, cat['name'] as String),
          'bg': bg,
          'asset': asset,
        },
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
        ),
        child: Column(children: [
          // Top visual half
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                child: Image.asset(
                  asset,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    color: bg,
                    child: const Icon(
                      Icons.corporate_fare_rounded,
                      color: _primary,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom white half
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppStrings.t(context, cat['name'] as String),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _text)),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(AppStrings.t(context, 'View departments'),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _primary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 12, color: _primary),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}
