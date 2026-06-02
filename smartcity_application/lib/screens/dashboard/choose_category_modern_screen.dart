import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_bottom_nav.dart';

class ChooseCategoryModernScreen extends StatelessWidget {
  const ChooseCategoryModernScreen({super.key});

  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);

  @override
  Widget build(BuildContext context) {
    final isGuest = !context.watch<AuthProvider>().isAuthenticated;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      extendBody: isGuest,
      bottomNavigationBar: isGuest ? null : const AppBottomNav(currentIndex: 1),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    18,
                    24,
                    isGuest ? 112 + bottomInset : 28,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _topBar(context, isGuest),
                      const SizedBox(height: 22),
                      _introCard(),
                      const SizedBox(height: 24),
                      _sectionHeader(),
                      const SizedBox(height: 14),
                      _categoryGrid(context, isGuest),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          if (isGuest) _guestBottomDock(context, bottomInset),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, bool isGuest) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_rounded,
            background: Colors.white,
            foreground: _ink,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Image.asset(
            'assets/images/logo.png',
            width: 118,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          _iconButton(
            icon: isGuest ? Icons.login_rounded : Icons.home_rounded,
            background: isGuest ? _ink : Colors.white,
            foreground: isGuest ? Colors.white : _ink,
            onTap: () => Navigator.pushNamedAndRemoveUntil(
              context,
              isGuest ? AppRoutes.login : AppRoutes.userDashboard,
              (_) => false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: _cardDecoration(radius: 24),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2F80ED).withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.add_task_rounded,
              color: Color(0xFF2F80ED),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit Complaint',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle(size: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the department that matches your issue.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: _muted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF3478F6).withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: Color(0xFF3478F6),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Departments',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle(size: 22),
          ),
        ),
      ],
    );
  }

  Widget _categoryGrid(BuildContext context, bool isGuest) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 760 ? 4 : 3;
        final ratio = width >= 760 ? 0.82 : 0.72;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            return _categoryCard(context, _categories[index], isGuest);
          },
        );
      },
    );
  }

  Widget _categoryCard(
    BuildContext context,
    _ComplaintCategory category,
    bool isGuest,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.submitComplaint,
          arguments: {
            'categoryKey': category.key,
            'categoryName': category.title,
            'isGuest': isGuest,
          },
        ),
        child: Ink(
          decoration: _cardDecoration(radius: 22),
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: category.asset == null
                      ? _fallbackVisual(category)
                      : RepaintBoundary(
                          child: Image.asset(
                            category.asset!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 7, 7, 9),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _titleStyle(size: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _labelStyle(
                          size: 9.8,
                          weight: FontWeight.w500,
                          color: _muted,
                          height: 1.14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackVisual(_ComplaintCategory category) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.08),
      ),
      child: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: category.color.withValues(alpha: 0.16)),
          ),
          child: Icon(category.icon, color: category.color, size: 32),
        ),
      ),
    );
  }

  Widget _guestBottomDock(BuildContext context, double bottomInset) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + bottomInset,
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    _dockItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      active: false,
                      onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.guestDashboard,
                        (_) => false,
                      ),
                    ),
                    _dockItem(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Submit',
                      active: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 72),
                    _dockItem(
                      icon: Icons.search_rounded,
                      label: 'Track',
                      active: false,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.guestTrack),
                    ),
                    _dockItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      active: false,
                      onTap: () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.login,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF5BC7FF),
                      Color(0xFF2BC4B6),
                      Color(0xFF4D8DFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 5,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dockItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 60,
            height: 48,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF3F5F8) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: active ? _ink : const Color(0xFF667085),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: active ? _ink : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Icon(icon, color: foreground, size: 24),
        ),
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

  TextStyle _titleStyle({required double size}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: _text,
    );
  }

  TextStyle _labelStyle({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0,
      height: height,
      color: color,
    );
  }
}

class _ComplaintCategory {
  const _ComplaintCategory({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.asset,
  });

  final String key;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String? asset;
}

const _categories = [
  _ComplaintCategory(
    key: 'police',
    title: 'Police',
    subtitle: 'Report safety issues',
    color: Color(0xFF2F80ED),
    icon: Icons.local_police_rounded,
    asset: 'assets/images/cat_police.png',
  ),
  _ComplaintCategory(
    key: 'traffic',
    title: 'Traffic',
    subtitle: 'Signals, parking, roads',
    color: Color(0xFFF59E0B),
    icon: Icons.traffic_rounded,
    asset: 'assets/images/cat_traffic.png',
  ),
  _ComplaintCategory(
    key: 'construction',
    title: 'Construction',
    subtitle: 'Building and repair issues',
    color: Color(0xFF64748B),
    icon: Icons.construction_rounded,
    asset: 'assets/images/cat_construction.png',
  ),
  _ComplaintCategory(
    key: 'water',
    title: 'Water',
    subtitle: 'Leakage and shortages',
    color: Color(0xFF2F80ED),
    icon: Icons.water_drop_rounded,
    asset: 'assets/images/cat_waste_overflow.png',
  ),
  _ComplaintCategory(
    key: 'electricity',
    title: 'Electric',
    subtitle: 'Power and wiring faults',
    color: Color(0xFFF59E0B),
    icon: Icons.bolt_rounded,
    asset: 'assets/images/cat_electric.png',
  ),
  _ComplaintCategory(
    key: 'garbage',
    title: 'Garbage',
    subtitle: 'Waste collection issues',
    color: Color(0xFF22C55E),
    icon: Icons.delete_rounded,
    asset: 'assets/images/cat_garbage.png',
  ),
  _ComplaintCategory(
    key: 'road',
    title: 'Roads',
    subtitle: 'Potholes and street issues',
    color: Color(0xFF4D8DFF),
    icon: Icons.add_road_rounded,
    asset: 'assets/images/cat_roads.png',
  ),
  _ComplaintCategory(
    key: 'drainage',
    title: 'Drainage',
    subtitle: 'Blocked drains and sewage',
    color: Color(0xFF0EA5E9),
    icon: Icons.water_damage_rounded,
    asset: 'assets/images/cat_drainage.png',
  ),
  _ComplaintCategory(
    key: 'illegal',
    title: 'Illegal Activity',
    subtitle: 'Unsafe activity reports',
    color: Color(0xFFEF4444),
    icon: Icons.warning_amber_rounded,
    asset: 'assets/images/cat_illegal.png',
  ),
  _ComplaintCategory(
    key: 'transportation',
    title: 'Transport',
    subtitle: 'Bus and transit issues',
    color: Color(0xFF8B5CF6),
    icon: Icons.directions_bus_rounded,
    asset: 'assets/images/cat_transportation.png',
  ),
  _ComplaintCategory(
    key: 'cyber',
    title: 'Cyber Crime',
    subtitle: 'Digital fraud and safety',
    color: Color(0xFF6366F1),
    icon: Icons.security_rounded,
    asset: 'assets/images/cat_cyber.png',
  ),
  _ComplaintCategory(
    key: 'other',
    title: 'Other',
    subtitle: 'Other civic request',
    color: Color(0xFF64748B),
    icon: Icons.assignment_outlined,
    asset: 'assets/images/cat_other.png',
  ),
];
