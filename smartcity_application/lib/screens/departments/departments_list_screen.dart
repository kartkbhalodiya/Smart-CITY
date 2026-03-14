import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/routes.dart';

class DepartmentsListScreen extends StatelessWidget {
  const DepartmentsListScreen({super.key});

  static const _categories = [
    {'key': 'police',         'name': 'Police',          'emoji': '🚓', 'bg': Color(0xFFEEF2FF)},
    {'key': 'traffic',        'name': 'Traffic',         'emoji': '🚦', 'bg': Color(0xFFFFF7ED)},
    {'key': 'construction',   'name': 'Construction',    'emoji': '🏗️', 'bg': Color(0xFFF0F9FF)},
    {'key': 'water',          'name': 'Water Supply',    'emoji': '🚰', 'bg': Color(0xFFF0FDF4)},
    {'key': 'electricity',    'name': 'Electricity',     'emoji': '💡', 'bg': Color(0xFFFFFBEB)},
    {'key': 'garbage',        'name': 'Garbage',         'emoji': '🗑️', 'bg': Color(0xFFECFDF5)},
    {'key': 'road',           'name': 'Road / Pothole',  'emoji': '🛣️', 'bg': Color(0xFFFAF5FF)},
    {'key': 'drainage',       'name': 'Drainage',        'emoji': '🌊', 'bg': Color(0xFFEFF6FF)},
    {'key': 'illegal',        'name': 'Illegal Activity','emoji': '⚠️', 'bg': Color(0xFFFFF1F2)},
    {'key': 'transportation', 'name': 'Transportation',  'emoji': '🚌', 'bg': Color(0xFFF0F9FF)},
    {'key': 'cyber',          'name': 'Cyber Crime',     'emoji': '🛡️', 'bg': Color(0xFFF5F3FF)},
    {'key': 'other',          'name': 'Other',           'emoji': '📋', 'bg': Color(0xFFF8FAFC)},
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
              Text('Departments',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: const Color(0xFF0f172a))),
              Text('Select a category',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
            ]),
          ]),
        ),

        // Grid
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
            itemBuilder: (_, i) => _categoryCard(context, _categories[i]),
          ),
        ),
      ]),
    );
  }

  Widget _categoryCard(BuildContext context, Map<String, Object> cat) {
    final bg = cat['bg'] as Color;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.departmentsByCategory,
        arguments: {'key': cat['key'], 'name': cat['name'], 'emoji': cat['emoji'], 'bg': bg},
      ),
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
                Text(cat['emoji'] as String, style: const TextStyle(fontSize: 48)),
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
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(cat['name'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: const Color(0xFF0f172a))),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('View departments',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF1E66F5),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF1E66F5)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
