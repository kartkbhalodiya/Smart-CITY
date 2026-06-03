import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

enum AdminDashboardRole {
  superAdmin,
  cityAdmin,
  department,
}

class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminOverviewScreen(role: AdminDashboardRole.superAdmin);
  }
}

class CityAdminDashboardScreen extends StatelessWidget {
  const CityAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminOverviewScreen(role: AdminDashboardRole.cityAdmin);
  }
}

class DepartmentAdminDashboardScreen extends StatelessWidget {
  const DepartmentAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminOverviewScreen(role: AdminDashboardRole.department);
  }
}

class _AdminOverviewScreen extends StatefulWidget {
  final AdminDashboardRole role;

  const _AdminOverviewScreen({required this.role});

  @override
  State<_AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<_AdminOverviewScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);
  static const _primary = Color(0xFF2F80ED);

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _payload = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _endpoint {
    switch (widget.role) {
      case AdminDashboardRole.superAdmin:
        return ApiConfig.superAdminOverview;
      case AdminDashboardRole.cityAdmin:
        return ApiConfig.cityAdminOverview;
      case AdminDashboardRole.department:
        return ApiConfig.departmentAdminOverview;
    }
  }

  String get _fallbackTitle {
    switch (widget.role) {
      case AdminDashboardRole.superAdmin:
        return 'Main Admin';
      case AdminDashboardRole.cityAdmin:
        return 'City Admin';
      case AdminDashboardRole.department:
        return 'Department Admin';
    }
  }

  String get _roleLabel {
    switch (widget.role) {
      case AdminDashboardRole.superAdmin:
        return 'Super Admin';
      case AdminDashboardRole.cityAdmin:
        return 'City Admin';
      case AdminDashboardRole.department:
        return 'Department';
    }
  }

  Color get _roleAccent {
    switch (widget.role) {
      case AdminDashboardRole.superAdmin:
        return _primary;
      case AdminDashboardRole.cityAdmin:
        return const Color(0xFF0F766E);
      case AdminDashboardRole.department:
        return const Color(0xFF7C3AED);
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case AdminDashboardRole.superAdmin:
        return Icons.admin_panel_settings_outlined;
      case AdminDashboardRole.cityAdmin:
        return Icons.location_city_outlined;
      case AdminDashboardRole.department:
        return Icons.account_balance_outlined;
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final response = await ApiService.get(_endpoint);
    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        _payload = response;
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = response['message']?.toString() ??
          'Unable to load this admin dashboard.';
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _payload[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 34 + bottomInset),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _topBar(),
                    const SizedBox(height: 20),
                    if (_loading)
                      _loadingState()
                    else if (_error != null)
                      _errorState()
                    else ...[
                      _identityPanel(user),
                      const SizedBox(height: 24),
                      _sectionHeader(
                        icon: Icons.bar_chart_rounded,
                        title: 'Live Stats',
                        iconColor: _primary,
                      ),
                      const SizedBox(height: 14),
                      _statsGrid(),
                      const SizedBox(height: 28),
                      _sectionHeader(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Control Center',
                        iconColor: const Color(0xFF7C3AED),
                      ),
                      const SizedBox(height: 14),
                      _sectionGrid(),
                      const SizedBox(height: 28),
                      _sectionHeader(
                        icon: Icons.assignment_outlined,
                        title: 'Recent Complaints',
                        iconColor: const Color(0xFF7EA1D8),
                        trailing: _viewAllPill(
                          label: 'View All',
                          onTap: () => _openResource({
                            'route': 'complaints',
                            'title': 'Complaints',
                          }),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _complaintsList(),
                      const SizedBox(height: 28),
                      _sectionHeader(
                        icon: Icons.account_balance_outlined,
                        title: 'Departments',
                        iconColor: const Color(0xFF3478F6),
                        trailing: _viewAllPill(
                          label: 'View All',
                          onTap: () => _openResource({
                            'route': 'departments',
                            'title': 'Departments',
                          }),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _departmentsList(),
                      if (_list('city_admins').isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionHeader(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'City Admins',
                          iconColor: const Color(0xFF14B8A6),
                          trailing: _viewAllPill(
                            label: 'Manage',
                            onTap: () => _openResource({
                              'route': 'city_admins',
                              'title': 'City Admins',
                            }),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _cityAdminsList(),
                      ],
                    ],
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        final buttonSize = compact ? 40.0 : 44.0;
        final gap = compact ? 7.0 : 10.0;

        return SizedBox(
          height: 66,
          child: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: compact ? 106 : 130,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              _iconButton(
                icon: Icons.lock_reset_rounded,
                tooltip: 'Password',
                size: buttonSize,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.adminPassword),
              ),
              SizedBox(width: gap),
              _iconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                size: buttonSize,
                onTap: _load,
              ),
              SizedBox(width: gap),
              _iconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Logout',
                size: buttonSize,
                onTap: _logout,
                dark: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 44,
    bool dark = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: dark ? _ink : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? _ink : _line),
            ),
            child: Icon(
              icon,
              color: dark ? Colors.white : _ink,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityPanel(dynamic user) {
    final title = _payload['title']?.toString() ?? _fallbackTitle;
    final scope = _payload['scope']?.toString() ?? '';
    final name = _displayName(user);
    final email = (user?.email ?? '').toString();
    final accent = _roleAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(19),
                ),
                alignment: Alignment.center,
                child: Icon(_roleIcon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _displayStyle(size: 24, height: 1.05),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _roleChip(accent),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 14,
                        weight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email.isEmpty ? scope : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 12.2,
                        weight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (scope.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      scope,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 12,
                        weight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _summaryStrip(),
        ],
      ),
    );
  }

  Widget _summaryStrip() {
    final summary = _payload['summary'] is Map
        ? Map<String, dynamic>.from(_payload['summary'] as Map)
        : const <String, dynamic>{};
    final items = [
      _SummaryChipData(
        'Total',
        summary['total_complaints'],
        Icons.assignment_outlined,
        _primary,
      ),
      _SummaryChipData(
        'Pending',
        summary['pending_complaints'],
        Icons.pending_actions_rounded,
        const Color(0xFFF97316),
      ),
      _SummaryChipData(
        'Progress',
        summary['in_progress_complaints'],
        Icons.sync_rounded,
        const Color(0xFF7C3AED),
      ),
      _SummaryChipData(
        'Solved',
        summary['resolved_complaints'],
        Icons.task_alt_rounded,
        const Color(0xFF16A34A),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: compact
                    ? (constraints.maxWidth - 8) / 2
                    : (constraints.maxWidth - 24) / 4,
                child: _summaryChip(item),
              ),
          ],
        );
      },
    );
  }

  Widget _summaryChip(_SummaryChipData item) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: item.color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _countText(item.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 15,
                    weight: FontWeight.w900,
                    color: _ink,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 10,
                    weight: FontWeight.w800,
                    color: _muted,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Text(
        _roleLabel,
        style: _labelStyle(
          size: 10.5,
          weight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }

  Widget _statsGrid() {
    final stats = _list('stats');
    if (stats.isEmpty) {
      return _emptyBox('No stats found for this admin account.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.take(6).map((stat) {
            return SizedBox(
              width: itemWidth,
              child: _statCard(stat),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _statCard(Map<String, dynamic> stat) {
    final color = _colorFor(stat['color']);
    final value = stat['value']?.toString() ?? '0';
    final label = stat['label']?.toString() ?? 'Count';

    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _iconFor(stat['icon']?.toString()),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: _displayStyle(size: 24, height: 1.0),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionGrid() {
    final sections = _list('sections');
    if (sections.isEmpty) {
      return _emptyBox('No control sections available.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 560;
        if (!twoColumns) {
          return Column(
            children: [
              for (int i = 0; i < sections.length; i++) ...[
                _sectionTile(sections[i], compact: false),
                if (i != sections.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final section in sections)
              SizedBox(
                width: cardWidth,
                child: _sectionTile(section, compact: true),
              ),
          ],
        );
      },
    );
  }

  Widget _sectionTile(Map<String, dynamic> section, {required bool compact}) {
    final color = _colorFor(section['color']);
    final title = section['title']?.toString() ?? 'Section';
    final subtitle = section['subtitle']?.toString() ?? '';
    final count = section['count']?.toString() ?? '0';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openResource(section),
        child: Ink(
          height: compact ? 118 : null,
          padding: const EdgeInsets.all(15),
          decoration: _cardDecoration(radius: 20),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _tileIcon(_iconFor(section['icon']?.toString()), color),
                        const Spacer(),
                        _countPill(count),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 14,
                        weight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 11,
                        weight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _tileIcon(_iconFor(section['icon']?.toString()), color),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _labelStyle(
                              size: 14.5,
                              weight: FontWeight.w900,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _labelStyle(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _countPill(count),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tileIcon(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _countPill(String count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 38),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      alignment: Alignment.center,
      child: Text(
        count,
        style: _labelStyle(
          size: 13,
          weight: FontWeight.w900,
          color: _ink,
        ),
      ),
    );
  }

  void _openResource(Map<String, dynamic> section) {
    final raw = section['route']?.toString() ?? 'complaints';
    final title = section['title']?.toString() ?? 'Admin';
    if (raw == 'analytics' || raw == 'heatmap') {
      Navigator.pushNamed(context, AppRoutes.adminHeatmap);
      return;
    }
    var resource = raw;
    String? workStatus;
    switch (raw) {
      case 'city_admins':
        resource = 'city-admins';
        break;
      case 'pending':
        resource = 'problems';
        workStatus = 'pending';
        break;
      case 'progress':
        resource = 'problems';
        workStatus = 'in_progress';
        break;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.adminResource,
      arguments: {
        'resource': resource,
        'title': title,
        if (workStatus != null) 'workStatus': workStatus,
      },
    );
  }

  Widget _complaintsList() {
    final complaints = _list('complaints');
    if (complaints.isEmpty) {
      return _emptyBox('No recent complaints in this scope.');
    }

    return Column(
      children: [
        for (int i = 0; i < complaints.length; i++) ...[
          _complaintTile(complaints[i]),
          if (i != complaints.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _complaintTile(Map<String, dynamic> complaint) {
    final status = complaint['work_status']?.toString() ?? '';
    final statusLabel = complaint['work_status_display']?.toString() ??
        complaint['status_display']?.toString() ??
        status;
    final color = _statusColor(status);
    final id = int.tryParse(complaint['id']?.toString() ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: id == null
            ? null
            : () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminComplaintDetail,
                  arguments: {'complaintId': id},
                ),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: _cardDecoration(radius: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint['title']?.toString() ?? 'Complaint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 14.5,
                        weight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _complaintSubtitle(complaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _tinyPill(
                          complaint['complaint_number']?.toString() ?? 'New',
                          const Color(0xFF334155),
                        ),
                        _tinyPill(statusLabel, color),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _complaintSubtitle(Map<String, dynamic> complaint) {
    final type = complaint['complaint_type_display']?.toString() ??
        complaint['complaint_type']?.toString() ??
        'Complaint';
    final city = complaint['city']?.toString() ?? '';
    final date = _formatDate(complaint['created_at']);

    final parts = <String>[type];
    if (city.trim().isNotEmpty) parts.add(city.trim());
    if (date.isNotEmpty) parts.add(date);
    return parts.join(' - ');
  }

  Widget _departmentsList() {
    final departments = _list('departments');
    if (departments.isEmpty) {
      return _emptyBox('No departments found for this dashboard.');
    }

    return Column(
      children: [
        for (int i = 0; i < departments.length; i++) ...[
          _departmentTile(departments[i]),
          if (i != departments.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _departmentTile(Map<String, dynamic> department) {
    final type = department['department_type_display']?.toString() ??
        department['department_type']?.toString() ??
        'Department';
    final phone = department['phone']?.toString() ?? '';
    final city = department['city']?.toString() ?? '';
    final state = department['state']?.toString() ?? '';
    final subtitle = [
      type,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ].join(' - ');
    final id = int.tryParse(department['id']?.toString() ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: id == null
            ? null
            : () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminDepartmentDetail,
                  arguments: {'departmentId': id},
                ),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: _cardDecoration(radius: 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department['name']?.toString() ?? 'Department',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 14.5,
                        weight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: _tinyPill(
                    phone,
                    const Color(0xFF2563EB),
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cityAdminsList() {
    final admins = _list('city_admins');

    return Column(
      children: [
        for (int i = 0; i < admins.length; i++) ...[
          _cityAdminTile(admins[i]),
          if (i != admins.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _cityAdminTile(Map<String, dynamic> admin) {
    final active = admin['is_active'] == true;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(radius: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Color(0xFF0F766E),
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin['name']?.toString() ?? 'City Admin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 14.5,
                    weight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    admin['city']?.toString() ?? '',
                    admin['state']?.toString() ?? '',
                    admin['email']?.toString() ?? '',
                  ].where((item) => item.trim().isNotEmpty).join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 78),
            child: _tinyPill(
              active ? 'Active' : 'Off',
              active ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(
              size: 18,
              weight: FontWeight.w900,
              color: _text,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _viewAllPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F7),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: _labelStyle(
                  size: 12,
                  weight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: _text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return Column(
      children: [
        _skeleton(height: 118),
        const SizedBox(height: 24),
        _skeleton(height: 232),
        const SizedBox(height: 24),
        _skeleton(height: 170),
      ],
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Dashboard unavailable.',
            textAlign: TextAlign.center,
            style: _labelStyle(
              size: 14,
              weight: FontWeight.w800,
              color: _text,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _blackButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            onTap: _load,
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: _labelStyle(
          size: 13,
          weight: FontWeight.w700,
          color: _muted,
        ),
      ),
    );
  }

  Widget _skeleton({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.62,
          child: Container(
            margin: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A1A),
                Color(0xFF050505),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: _labelStyle(
                  size: 15,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _labelStyle(
          size: 10.5,
          weight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'assignment':
        return Icons.assignment_outlined;
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'sync':
        return Icons.sync_rounded;
      case 'check':
      case 'task_alt':
        return Icons.task_alt_rounded;
      case 'restart':
        return Icons.restart_alt_rounded;
      case 'today':
        return Icons.today_outlined;
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      case 'groups':
        return Icons.groups_outlined;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'assignment_ind':
        return Icons.assignment_ind_outlined;
      case 'category':
        return Icons.category_outlined;
      case 'map':
        return Icons.map_outlined;
      case 'location_city':
        return Icons.location_city_outlined;
      case 'analytics':
        return Icons.analytics_outlined;
      default:
        return Icons.grid_view_rounded;
    }
  }

  Color _colorFor(dynamic key) {
    switch (key?.toString()) {
      case 'green':
        return const Color(0xFF16A34A);
      case 'orange':
        return const Color(0xFFF97316);
      case 'purple':
        return const Color(0xFF7C3AED);
      case 'red':
        return const Color(0xFFDC2626);
      case 'teal':
        return const Color(0xFF0F766E);
      case 'blue':
      default:
        return _primary;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'solved':
        return const Color(0xFF16A34A);
      case 'process':
      case 'confirmed':
        return const Color(0xFF7C3AED);
      case 'reopened':
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'pending':
      default:
        return const Color(0xFFF97316);
    }
  }

  String _countText(dynamic value) {
    if (value == null) return '0';
    if (value is num) return value.toInt().toString();
    final parsed = int.tryParse(value.toString());
    return (parsed ?? 0).toString();
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _displayName(dynamic user) {
    final fullName = (user?.fullName ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
    final username = (user?.username ?? '').toString().trim();
    if (username.isNotEmpty) return username.split('@').first;
    return _fallbackTitle;
  }

  TextStyle _displayStyle({
    required double size,
    double height = 1.1,
    Color color = _ink,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: color,
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
      height: height,
      fontWeight: weight,
      letterSpacing: 0,
      color: color,
    );
  }
}

class _SummaryChipData {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;

  const _SummaryChipData(
    this.label,
    this.value,
    this.icon,
    this.color,
  );
}
