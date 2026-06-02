import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../models/complaint.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../widgets/app_bottom_nav.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);
  static const _primary = Color(0xFF2F80ED);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ComplaintProvider>();
      provider.loadDashboardStats();
      provider.loadComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final user = context.watch<AuthProvider>().user;

    return Consumer<ComplaintProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: _bg,
          extendBody: true,
          bottomNavigationBar: const AppBottomNav(currentIndex: 0),
          body: RefreshIndicator(
            color: _primary,
            onRefresh: provider.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 18, 24, 110 + bottomInset),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        _topBar(user, provider),
                        const SizedBox(height: 20),
                        _userIntro(user),
                        const SizedBox(height: 26),
                        _sectionHeader(
                          icon: Icons.bar_chart_rounded,
                          iconColor: _primary,
                          title: 'Live Stats',
                        ),
                        const SizedBox(height: 14),
                        _statsGrid(provider),
                        const SizedBox(height: 28),
                        _sectionHeader(
                          icon: Icons.grid_view_rounded,
                          iconColor: const Color(0xFF3478F6),
                          title: 'Departments',
                          trailing: _pillButton(
                            label: 'View All',
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
                          trailing: _pillButton(
                            label: 'View All',
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
                          trailing: _pillButton(
                            label: 'Track',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.userTrack,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _recentComplaints(provider),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(dynamic user, ComplaintProvider provider) {
    final pendingCount = provider.complaints
        .where((complaint) => complaint.workStatus.toLowerCase() != 'solved')
        .length;

    return SizedBox(
      height: 66,
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 130,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          _iconButton(
            icon: Icons.notifications_outlined,
            badge: pendingCount > 0 ? pendingCount : null,
            onTap: () => _showNotificationSheet(provider),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(user),
                style: _labelStyle(
                  size: 14,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(icon, color: _ink, size: 22)),
              if (badge != null)
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: _labelStyle(
                        size: 9,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userIntro(dynamic user) {
    final name = _displayName(user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _displayStyle(size: 29, height: 1.04),
        ),
        const SizedBox(height: 7),
        Text(
          'Manage your complaints and city services.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _labelStyle(
            size: 13.2,
            weight: FontWeight.w600,
            color: _muted,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'Submit Complaint',
                icon: Icons.add_rounded,
                dark: true,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.categorySelection,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                label: 'Track',
                icon: Icons.search_rounded,
                dark: false,
                onTap: () => Navigator.pushNamed(context, AppRoutes.userTrack),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool dark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: dark ? _ink : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: dark ? null : Border.all(color: _line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: dark ? Colors.white : _ink, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 13,
                    weight: FontWeight.w800,
                    color: dark ? Colors.white : _ink,
                  ),
                ),
              ),
            ],
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

  Widget _pillButton({
    required String label,
    required VoidCallback onTap,
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
          child: Center(
            child: Text(
              label,
              style: _labelStyle(
                size: 13,
                weight: FontWeight.w800,
                color: _text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsGrid(ComplaintProvider provider) {
    final complaints = provider.complaints;
    final stats = provider.stats;
    final total = stats?.totalComplaints ?? complaints.length;
    final pending = stats?.pendingComplaints ??
        complaints.where((c) => c.workStatus == 'pending').length;
    final progress = stats?.inProgressComplaints ??
        complaints.where((c) => c.workStatus == 'in_progress').length;
    final resolved = stats?.resolvedComplaints ??
        complaints.where((c) => c.workStatus == 'solved').length;

    final items = [
      _StatItem(
        icon: Icons.assignment_rounded,
        color: _primary,
        label: 'Total',
        value: total,
      ),
      _StatItem(
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFEAB308),
        label: 'Pending',
        value: pending,
      ),
      _StatItem(
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF4D8DFF),
        label: 'Progress',
        value: progress,
      ),
      _StatItem(
        icon: Icons.check_rounded,
        color: const Color(0xFF2BC4B6),
        label: 'Solved',
        value: resolved,
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
              child: _statCard(items[index], provider.isLoading),
            ),
          );
        }),
      ),
    );
  }

  Widget _statCard(_StatItem item, bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withValues(alpha: 0.16)),
      ),
      child: Column(
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
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: item.color,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${item.value}',
                style: _displayStyle(size: 22, height: 1),
              ),
            ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(
              size: 9.4,
              weight: FontWeight.w800,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _departmentsGrid() {
    final visible = _departments.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 760 ? 4 : 3;
        final ratio = width >= 760 ? 0.82 : 0.72;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) => _departmentCard(visible[index]),
        );
      },
    );
  }

  Widget _departmentCard(_DepartmentShortcut item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.submitComplaint,
          arguments: {
            'categoryKey': item.key,
            'categoryName': item.title,
            'isGuest': false,
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
                  child: Image.asset(
                    item.asset,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Container(
                      color: item.color.withValues(alpha: 0.10),
                      child: Icon(item.icon, color: item.color, size: 34),
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
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _titleStyle(size: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _labelStyle(
                          size: 9.7,
                          weight: FontWeight.w500,
                          color: _muted,
                          height: 1.12,
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
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentComplaints(ComplaintProvider provider) {
    if (provider.isLoading && provider.complaints.isEmpty) {
      return _emptyCard(
        icon: Icons.sync_rounded,
        title: 'Loading complaints',
        subtitle: 'Getting your latest complaint status.',
      );
    }

    if (provider.error != null && provider.complaints.isEmpty) {
      return _emptyCard(
        icon: Icons.error_outline_rounded,
        title: 'Could not load complaints',
        subtitle: provider.error!,
      );
    }

    final complaints = provider.complaints.take(3).toList();
    if (complaints.isEmpty) {
      return _emptyCard(
        icon: Icons.assignment_outlined,
        title: 'No recent complaints',
        subtitle: 'Submit your first complaint to track it here.',
        actionLabel: 'Submit Complaint',
        onAction: () =>
            Navigator.pushNamed(context, AppRoutes.categorySelection),
      );
    }

    return Column(
      children: complaints.map(_complaintCard).toList(),
    );
  }

  Widget _complaintCard(Complaint complaint) {
    final statusColor = _statusColor(complaint.workStatus);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.complaintDetail,
            arguments: {'complaintId': complaint.id},
          ),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(radius: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    _categoryAssetFor(complaint.complaintType),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: _primary.withValues(alpha: 0.10),
                      child: const Icon(
                        Icons.category_rounded,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle(
                          size: 14.2,
                          weight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${complaint.complaintNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle(
                          size: 11.2,
                          weight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              complaint.workStatusDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _labelStyle(
                                size: 11.3,
                                weight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF98A2B3),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _primary, size: 25),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _titleStyle(size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: _labelStyle(
              size: 12.5,
              weight: FontWeight.w600,
              color: _muted,
              height: 1.28,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: 168,
              child: _actionButton(
                label: actionLabel,
                icon: Icons.add_rounded,
                dark: true,
                onTap: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showNotificationSheet(ComplaintProvider provider) {
    final pending = provider.complaints
        .where((complaint) => complaint.workStatus.toLowerCase() != 'solved')
        .take(4)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E7EC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('Updates', style: _titleStyle(size: 20)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _ink),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (pending.isEmpty)
              _emptyCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'No pending updates',
                subtitle: 'Solved complaints and new updates will appear here.',
              )
            else
              ...pending.map((complaint) => _complaintCard(complaint)),
          ],
        ),
      ),
    );
  }

  String _displayName(dynamic user) {
    try {
      final fullName = user?.fullName?.toString().trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
      final firstName = user?.firstName?.toString().trim() ?? '';
      if (firstName.isNotEmpty) return firstName;
    } catch (_) {
      return 'User';
    }
    return 'User';
  }

  String _initials(dynamic user) {
    final name = _displayName(user);
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    final first = parts.first[0].toUpperCase();
    final second = parts.length > 1 ? parts.last[0].toUpperCase() : '';
    return '$first$second';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'solved':
      case 'resolved':
        return const Color(0xFF22C55E);
      case 'process':
      case 'in_progress':
        return _primary;
      case 'reopened':
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFEAB308);
    }
  }

  String _categoryAssetFor(String key) {
    switch (key.toLowerCase()) {
      case 'police':
        return 'assets/images/cat_police.png';
      case 'traffic':
        return 'assets/images/cat_traffic.png';
      case 'construction':
        return 'assets/images/cat_construction.png';
      case 'water':
      case 'water supply':
        return 'assets/images/cat_waste_overflow.png';
      case 'electric':
      case 'electricity':
        return 'assets/images/cat_electric.png';
      case 'garbage':
        return 'assets/images/cat_garbage.png';
      case 'road':
      case 'roads':
      case 'pothole':
        return 'assets/images/cat_roads.png';
      case 'drainage':
        return 'assets/images/cat_drainage.png';
      case 'illegal':
      case 'illegal activity':
        return 'assets/images/cat_illegal.png';
      case 'transport':
      case 'transportation':
        return 'assets/images/cat_transportation.png';
      case 'cyber':
      case 'cyber crime':
        return 'assets/images/cat_cyber.png';
      default:
        return 'assets/images/cat_other.png';
    }
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

  static TextStyle _labelStyle({
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

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;
}

class _DepartmentShortcut {
  const _DepartmentShortcut({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.icon,
    required this.color,
  });

  final String key;
  final String title;
  final String subtitle;
  final String asset;
  final IconData icon;
  final Color color;
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

const _departments = [
  _DepartmentShortcut(
    key: 'police',
    title: 'Police',
    subtitle: 'Safety and incidents',
    asset: 'assets/images/cat_police.png',
    icon: Icons.local_police_rounded,
    color: Color(0xFF2F80ED),
  ),
  _DepartmentShortcut(
    key: 'traffic',
    title: 'Traffic',
    subtitle: 'Signals and parking',
    asset: 'assets/images/cat_traffic.png',
    icon: Icons.traffic_rounded,
    color: Color(0xFF3478F6),
  ),
  _DepartmentShortcut(
    key: 'water',
    title: 'Water',
    subtitle: 'Leakage and supply',
    asset: 'assets/images/cat_waste_overflow.png',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF2BC4B6),
  ),
  _DepartmentShortcut(
    key: 'electricity',
    title: 'Electric',
    subtitle: 'Power and street lights',
    asset: 'assets/images/cat_electric.png',
    icon: Icons.bolt_rounded,
    color: Color(0xFF4D8DFF),
  ),
  _DepartmentShortcut(
    key: 'garbage',
    title: 'Garbage',
    subtitle: 'Waste and cleanliness',
    asset: 'assets/images/cat_garbage.png',
    icon: Icons.delete_rounded,
    color: Color(0xFF2BC4B6),
  ),
  _DepartmentShortcut(
    key: 'road',
    title: 'Roads',
    subtitle: 'Potholes and repairs',
    asset: 'assets/images/cat_roads.png',
    icon: Icons.add_road_rounded,
    color: Color(0xFF4D8DFF),
  ),
];
