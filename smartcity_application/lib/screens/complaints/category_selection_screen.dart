import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/routes.dart';
import '../../l10n/app_strings.dart';

class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({super.key});

  static const _categories = [
    {'emoji': '🚓', 'name': 'Police',          'key': 'police',         'bg': Color(0xFFEEF2FF)},
    {'emoji': '🚦', 'name': 'Traffic',         'key': 'traffic',        'bg': Color(0xFFFFF7ED)},
    {'emoji': '🏗️', 'name': 'Construction',    'key': 'construction',   'bg': Color(0xFFF0F9FF)},
    {'emoji': '🚰', 'name': 'Water Supply',    'key': 'water',          'bg': Color(0xFFF0FDF4)},
    {'emoji': '💡', 'name': 'Electricity',     'key': 'electricity',    'bg': Color(0xFFFFFBEB)},
    {'emoji': '🗑️', 'name': 'Garbage',         'key': 'garbage',        'bg': Color(0xFFECFDF5)},
    {'emoji': '🛣️', 'name': 'Road / Pothole',  'key': 'road',           'bg': Color(0xFFFAF5FF)},
    {'emoji': '🌊', 'name': 'Drainage',        'key': 'drainage',       'bg': Color(0xFFEFF6FF)},
    {'emoji': '⚠️', 'name': 'Illegal Activity','key': 'illegal',        'bg': Color(0xFFFFF1F2)},
    {'emoji': '🚌', 'name': 'Transportation',  'key': 'transportation', 'bg': Color(0xFFF0F9FF)},
    {'emoji': '🛡️', 'name': 'Cyber Crime',     'key': 'cyber',          'bg': Color(0xFFF5F3FF)},
    {'emoji': '📋', 'name': 'Other',           'key': 'other',          'bg': Color(0xFFF8FAFC)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        // Top nav
        Container(
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
              Text(AppStrings.t(context, 'Submit Complaint'),
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: const Color(0xFF0f172a))),
              Text(AppStrings.t(context, 'Choose a category'),
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
            ]),
          ]),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: _categories.length,
            itemBuilder: (_, i) => _card(context, _categories[i]),
          ),
        ),
      ]),
    );
  }

  Widget _card(BuildContext context, Map<String, Object> c) {
    final bg = c['bg'] as Color;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.submitComplaint,
          arguments: {'categoryKey': c['key'], 'categoryName': AppStrings.t(context, c['name'] as String)}),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          // Top pastel half — full emoji, no box
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
          // Bottom white half — name
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Center(
                child: Text(AppStrings.t(context, c['name'] as String),
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
  }
}
