import 'package:flutter/material.dart';
import '../config/routes.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    this.currentIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(Icons.home_rounded, 'Home', AppRoutes.modernHome),
      _NavItem(Icons.add_circle_outline_rounded, 'Submit',
          AppRoutes.categorySelection),
      _NavItem(Icons.chat_bubble_outline_rounded, 'AI', AppRoutes.aiChat),
      _NavItem(Icons.search_rounded, 'Track', AppRoutes.userTrack),
      _NavItem(Icons.person_outline_rounded, 'Profile', AppRoutes.profile),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 76,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFEEF2F6)),
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onNavTap(context, index, item.route),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 60,
                        height: 50,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFF3F5F8)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 23,
                              color: selected
                                  ? const Color(0xFF0B1020)
                                  : const Color(0xFF667085),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? const Color(0xFF0B1020)
                                    : const Color(0xFF667085),
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void _onNavTap(BuildContext context, int index, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == route) return;

    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) => route.settings.name == AppRoutes.modernHome,
      );
    } else {
      Navigator.pushNamed(context, route);
    }
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}
