import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/routes.dart';

class GuestDashboardScreen extends StatefulWidget {
  const GuestDashboardScreen({super.key});

  @override
  State<GuestDashboardScreen> createState() => _GuestDashboardScreenState();
}

class _GuestDashboardScreenState extends State<GuestDashboardScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _line = Color(0xFFEEF2F6);

  bool _didPrecacheAssets = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheAssets) return;
    _didPrecacheAssets = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final asset in _assetPaths) {
        precacheImage(AssetImage(asset), context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: _bg,
        extendBody: true,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 18, 24, 108 + bottomInset),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        _topBar(),
                        const SizedBox(height: 22),
                        _heroBanner(),
                        const SizedBox(height: 26),
                        _sectionHeader(
                          icon: Icons.bar_chart_rounded,
                          iconColor: const Color(0xFF2F80ED),
                          title: 'Live Stats',
                        ),
                        const SizedBox(height: 14),
                        _statsGrid(),
                        const SizedBox(height: 28),
                        _sectionHeader(
                          icon: Icons.grid_view_rounded,
                          iconColor: const Color(0xFF3478F6),
                          title: 'Departments',
                          trailing: _viewAllPill(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.departmentsList,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _departmentsGrid(),
                        const SizedBox(height: 28),
                        _sectionHeader(
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFF3478F6),
                          title: 'Emergency Contacts',
                          trailing: _viewAllPill(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.departmentsList,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _emergencyContacts(),
                        const SizedBox(height: 28),
                        _sectionHeader(
                          icon: Icons.assignment_outlined,
                          iconColor: const Color(0xFF7EA1D8),
                          title: 'Recent Complaints',
                          trailing: _viewAllPill(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.guestTrack,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _historyBanner(),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            _bottomDock(bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 66,
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 130,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _heroBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 370;
        final contentWidth = width * (compact ? 0.46 : 0.39);

        return Container(
          height: compact ? 206 : 216,
          decoration: _cardDecoration(radius: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: Image.asset(
                    'assets/images/guest_dash_hero.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  top: compact ? 12 : 14,
                  right: compact ? 8 : 10,
                  bottom: compact ? 12 : 14,
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            color: Color(0xFF344054),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Guest Mode',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _labelStyle(
                                size: compact ? 8.2 : 9,
                                weight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 6 : 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Welcome to\nJanHelp',
                          style: _displayStyle(
                            size: compact ? 17.5 : 21,
                            height: 0.96,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 4),
                      Text(
                        'Smart city help, fast.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle(
                          size: compact ? 8.2 : 9.2,
                          weight: FontWeight.w500,
                          color: _text,
                        ),
                      ),
                      SizedBox(height: compact ? 7 : 9),
                      _heroButton(
                        label: 'Track Complaint',
                        dark: true,
                        icon: Icons.arrow_forward_rounded,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.guestTrack),
                      ),
                      SizedBox(height: compact ? 6 : 7),
                      _heroButton(
                        label: 'Login Now',
                        dark: false,
                        icon: Icons.lock_outline_rounded,
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroButton({
    required String label,
    required bool dark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 28,
        width: 112,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                color: dark ? _ink : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border:
                    dark ? null : Border.all(color: const Color(0xFFECEFF3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 9.4,
                        weight: FontWeight.w700,
                        color: dark ? Colors.white : _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(icon, size: 12, color: dark ? Colors.white : _ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle(size: 23),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _viewAllPill({required VoidCallback onTap}) {
    return _pillButton(
      label: 'View All',
      onTap: onTap,
      icon: null,
    );
  }

  Widget _pillButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F7),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: _labelStyle(
                  size: 13,
                  weight: FontWeight.w800,
                  color: _text,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 17, color: _text),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _departmentsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 760 ? 4 : 3;
        final ratio = width >= 760 ? 0.82 : 0.72;

        final visibleCategories = _categories.take(3).toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) =>
              _departmentCard(visibleCategories[index]),
        );
      },
    );
  }

  Widget _departmentCard(_ComplaintCategory category) {
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
            'isGuest': true,
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
                      ? _waterFallback()
                      : RepaintBoundary(
                          child: Image.asset(
                            category.asset!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            alignment: category.alignment,
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
                          color: const Color(0xFF5B6B86),
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

  Widget _waterFallback() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF7FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 12,
            bottom: 7,
            child: Icon(
              Icons.water_drop_rounded,
              size: 48,
              color: const Color(0xFF2F80ED).withValues(alpha: 0.18),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: Color(0xFF2F80ED),
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    const items = [
      _StatItem(
        icon: Icons.assignment_rounded,
        color: Color(0xFF2F80ED),
        label: 'Complaints',
      ),
      _StatItem(
        icon: Icons.hourglass_top_rounded,
        color: Color(0xFF3478F6),
        label: 'In Progress',
      ),
      _StatItem(
        icon: Icons.check_rounded,
        color: Color(0xFF2BC4B6),
        label: 'Resolved',
      ),
      _StatItem(
        icon: Icons.corporate_fare_rounded,
        color: Color(0xFF4D8DFF),
        label: 'Departments',
      ),
    ];

    return SizedBox(
      height: 104,
      child: Row(
        children: List.generate(items.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == items.length - 1 ? 0 : 4,
              ),
              child: _statCard(items[index]),
            ),
          );
        }),
      ),
    );
  }

  Widget _statCard(_StatItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withValues(alpha: 0.16)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                color: item.color,
                size: 12,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 17),
              ),
              const Spacer(),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle(
                  size: 9.2,
                  weight: FontWeight.w700,
                  color: _text,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Locked',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 8.6,
                    weight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emergencyContacts() {
    const contacts = [
      _EmergencyContact(
        title: 'Police Department',
        icon: Icons.local_police_rounded,
        color: Color(0xFF2F80ED),
        categoryKey: 'police',
        categoryName: 'Police Department',
        asset: 'assets/images/cat_police.png',
      ),
      _EmergencyContact(
        title: 'Traffic Department',
        icon: Icons.traffic_rounded,
        color: Color(0xFF3478F6),
        categoryKey: 'traffic',
        categoryName: 'Traffic Department',
        asset: 'assets/images/cat_traffic.png',
      ),
      _EmergencyContact(
        title: 'Water Supply',
        icon: Icons.water_drop_rounded,
        color: Color(0xFF2BC4B6),
        categoryKey: 'water',
        categoryName: 'Water Supply Department',
        asset: 'assets/images/cat_waste_overflow.png',
      ),
      _EmergencyContact(
        title: 'Electricity',
        icon: Icons.bolt_rounded,
        color: Color(0xFF4D8DFF),
        categoryKey: 'electricity',
        categoryName: 'Electricity Department',
        asset: 'assets/images/cat_electric.png',
      ),
      _EmergencyContact(
        title: 'Drainage',
        icon: Icons.water_damage_rounded,
        color: Color(0xFF7EA1D8),
        categoryKey: 'drainage',
        categoryName: 'Drainage Department',
        asset: 'assets/images/cat_drainage.png',
      ),
    ];

    return SizedBox(
      height: 116,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) => _emergencyCard(contacts[index]),
      ),
    );
  }

  Widget _emergencyCard(_EmergencyContact contact) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.departmentsByCategory,
          arguments: {
            'key': contact.categoryKey,
            'name': contact.categoryName,
            'asset': contact.asset,
            'bg': contact.color.withValues(alpha: 0.10),
          },
        ),
        child: Ink(
          width: 122,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: _cardDecoration(radius: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: contact.color.withValues(alpha: 0.16),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  contact.asset,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) =>
                      Icon(contact.icon, color: contact.color, size: 24),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                contact.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _labelStyle(
                    size: 12.2,
                    weight: FontWeight.w800,
                    color: _text,
                    height: 1.08),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyBanner() {
    return Container(
      height: 104,
      decoration: _cardDecoration(radius: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 370;
            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: Image.asset(
                    'assets/images/guest_dash_history.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    gaplessPlayback: true,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: compact ? 14 : 18),
                    child: SizedBox(
                      width: compact ? 132 : 148,
                      height: compact ? 44 : 48,
                      child: _blackButton(
                        label: 'Login Now',
                        icon: Icons.arrow_forward_rounded,
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _blackButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                      size: 14, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomDock(double bottomInset) {
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
                ),
                child: Row(
                  children: [
                    _dockItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      active: true,
                      onTap: () {},
                    ),
                    _dockItem(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Submit',
                      active: false,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.categorySelection,
                      ),
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
                          context, AppRoutes.login),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.categorySelection),
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
                  child: const Icon(Icons.add_rounded,
                      size: 32, color: Colors.white),
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

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
    );
  }

  TextStyle _displayStyle({
    required double size,
    double height = 0.98,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: _text,
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
    this.asset,
    this.alignment = Alignment.center,
  });

  final String key;
  final String title;
  final String subtitle;
  final String? asset;
  final Alignment alignment;
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

class _EmergencyContact {
  const _EmergencyContact({
    required this.title,
    required this.icon,
    required this.color,
    required this.categoryKey,
    required this.categoryName,
    required this.asset,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String categoryKey;
  final String categoryName;
  final String asset;
}

const _assetPaths = [
  'assets/images/guest_dash_hero.png',
  'assets/images/guest_dash_history.png',
  'assets/images/cat_police.png',
  'assets/images/cat_traffic.png',
  'assets/images/cat_construction.png',
  'assets/images/cat_waste_overflow.png',
  'assets/images/cat_electric.png',
  'assets/images/cat_garbage.png',
  'assets/images/cat_roads.png',
  'assets/images/cat_drainage.png',
  'assets/images/cat_illegal.png',
  'assets/images/cat_transportation.png',
  'assets/images/cat_cyber.png',
  'assets/images/cat_other.png',
];

const _categories = [
  _ComplaintCategory(
    key: 'police',
    title: 'Police',
    subtitle: 'Report incidents and safety issues',
    asset: 'assets/images/cat_police.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'traffic',
    title: 'Traffic',
    subtitle: 'Traffic signals, violations, parking',
    asset: 'assets/images/cat_traffic.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'construction',
    title: 'Construction',
    subtitle: 'Building, roads, maintenance',
    asset: 'assets/images/cat_construction.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'water',
    title: 'Water',
    subtitle: 'Water supply, leakage, shortages',
    asset: 'assets/images/cat_waste_overflow.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'electricity',
    title: 'Electric',
    subtitle: 'Power outages, wiring, faults',
    asset: 'assets/images/cat_electric.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'garbage',
    title: 'Garbage',
    subtitle: 'Waste collection, cleanliness',
    asset: 'assets/images/cat_garbage.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'road',
    title: 'Roads',
    subtitle: 'Potholes, repairs, street issues',
    asset: 'assets/images/cat_roads.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'drainage',
    title: 'Drainage',
    subtitle: 'Sewage overflow, blocked drains',
    asset: 'assets/images/cat_drainage.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'illegal',
    title: 'Illegal Activity',
    subtitle: 'Unsafe or suspicious activity',
    asset: 'assets/images/cat_illegal.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'transportation',
    title: 'Transport',
    subtitle: 'Bus services and transit issues',
    asset: 'assets/images/cat_transportation.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'cyber',
    title: 'Cyber Crime',
    subtitle: 'Digital fraud and online safety',
    asset: 'assets/images/cat_cyber.png',
    alignment: Alignment.center,
  ),
  _ComplaintCategory(
    key: 'other',
    title: 'Other',
    subtitle: 'Other complaint or civic request',
    asset: 'assets/images/cat_other.png',
    alignment: Alignment.center,
  ),
];
