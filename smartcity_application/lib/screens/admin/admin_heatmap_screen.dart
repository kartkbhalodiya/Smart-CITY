import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class AdminHeatmapScreen extends StatefulWidget {
  const AdminHeatmapScreen({super.key});

  @override
  State<AdminHeatmapScreen> createState() => _AdminHeatmapScreenState();
}

class _AdminHeatmapScreenState extends State<AdminHeatmapScreen> {
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

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final response = await ApiService.get(ApiConfig.adminHeatmap);
    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        _payload = response;
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = response['message']?.toString() ?? 'Unable to load heatmap.';
      _loading = false;
    });
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
                    const SizedBox(height: 18),
                    if (_loading)
                      _loadingState()
                    else if (_error != null)
                      _messageBox(_error!)
                    else ...[
                      _heroCard(),
                      const SizedBox(height: 18),
                      _statsGrid(),
                      const SizedBox(height: 22),
                      _mapCard(),
                      const SizedBox(height: 22),
                      _sectionTitle(
                          'Recent Map Complaints', Icons.assignment_outlined),
                      const SizedBox(height: 10),
                      _complaintRows(),
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
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Image.asset('assets/images/logo.png',
              width: 118, fit: BoxFit.contain),
          const Spacer(),
          _iconButton(
            icon: Icons.refresh_rounded,
            onTap: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    final summary = _payload['summary'] is Map
        ? Map<String, dynamic>.from(_payload['summary'] as Map)
        : const <String, dynamic>{};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 24),
      child: Row(
        children: [
          _iconBox(Icons.map_outlined, _primary, size: 56, iconSize: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Heatmap', style: _displayStyle(size: 23)),
                const SizedBox(height: 6),
                Text(
                  '${summary['total_points'] ?? 0} live map points across complaints and departments',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final stats = _list('stats');
    if (stats.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      itemCount: stats.length > 6 ? 6 : stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.95,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        final color = _colorFor(stat['color']?.toString() ?? '');
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(radius: 18),
          child: Row(
            children: [
              _iconBox(
                _iconFor(stat['icon']?.toString() ?? ''),
                color,
                size: 38,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stat['value']?.toString() ?? '0',
                      style: _displayStyle(size: 19, height: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat['label']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 11,
                        weight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mapCard() {
    final complaintPoints = _list('complaints');
    final departmentPoints = _list('departments');
    final centerMap = _payload['center'] is Map
        ? Map<String, dynamic>.from(_payload['center'] as Map)
        : const <String, dynamic>{};
    final center = LatLng(
      _toDouble(centerMap['latitude']) ?? 20.5937,
      _toDouble(centerMap['longitude']) ?? 78.9629,
    );

    final markers = <Marker>[];
    for (final department in departmentPoints) {
      final point = _pointFrom(department);
      final id = int.tryParse(department['department_id']?.toString() ?? '');
      if (point == null) continue;
      markers.add(_marker(
        point,
        const Color(0xFF2563EB),
        Icons.account_balance,
        onTap: id == null
            ? null
            : () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminDepartmentDetail,
                  arguments: {'departmentId': id},
                ),
      ));
    }
    for (final complaint in complaintPoints) {
      final point = _pointFrom(complaint);
      final id = int.tryParse(complaint['complaint_id']?.toString() ?? '');
      if (point == null) continue;
      markers.add(_marker(
        point,
        _statusColor(complaint['status']?.toString() ?? ''),
        Icons.location_on,
        onTap: id == null
            ? null
            : () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminComplaintDetail,
                  arguments: {'complaintId': id},
                ),
      ));
    }

    if (markers.isEmpty) return _emptyBox('No map points found.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Live Map', Icons.map_outlined),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 390,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 11),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.janhelp.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _legend(Icons.account_balance, const Color(0xFF2563EB), 'Dept'),
            const SizedBox(width: 10),
            _legend(Icons.location_on, const Color(0xFFF97316), 'Complaint'),
          ],
        ),
      ],
    );
  }

  Widget _complaintRows() {
    final complaints = _list('complaints');
    if (complaints.isEmpty) return _emptyBox('No complaints found.');
    return Column(
      children: [
        for (int i = 0; i < complaints.take(18).length; i++) ...[
          _complaintTile(complaints[i]),
          if (i != complaints.take(18).length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _complaintTile(Map<String, dynamic> item) {
    final id = int.tryParse(item['complaint_id']?.toString() ?? '');
    final status = item['status']?.toString() ?? '';
    final color = _statusColor(status);
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
            children: [
              _iconBox(Icons.location_on, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? 'Complaint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 14,
                        weight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        item['complaint_number']?.toString() ?? '',
                        item['subtitle']?.toString() ?? '',
                      ].where((v) => v.trim().isNotEmpty).join(' - '),
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
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Marker _marker(
    LatLng point,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: color, size: 38),
      ),
    );
  }

  Widget _legend(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            style: _labelStyle(size: 11, weight: FontWeight.w900, color: _text),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, _primary, size: 34, iconSize: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: _labelStyle(size: 18, weight: FontWeight.w900, color: _text),
          ),
        ),
      ],
    );
  }

  Widget _loadingState() {
    return Column(
      children: [
        Container(height: 135, decoration: _cardDecoration(radius: 24)),
        const SizedBox(height: 12),
        Container(height: 120, decoration: _cardDecoration(radius: 20)),
        const SizedBox(height: 12),
        Container(height: 390, decoration: _cardDecoration(radius: 24)),
      ],
    );
  }

  Widget _messageBox(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: _muted, size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: _labelStyle(size: 14, weight: FontWeight.w800, color: _text),
          ),
          const SizedBox(height: 12),
          _smallButton('Retry', Icons.refresh_rounded, _load),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _labelStyle(size: 13, weight: FontWeight.w800, color: _muted),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
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
            child: Icon(icon, color: _ink, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _smallButton(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: _labelStyle(
                  size: 12.5,
                  weight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 42,
    double iconSize = 21,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  LatLng? _pointFrom(Map<String, dynamic> item) {
    final lat = _toDouble(item['latitude']);
    final lng = _toDouble(item['longitude']);
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null;
    return LatLng(lat, lng);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'pending':
        return Icons.pending_outlined;
      case 'sync':
        return Icons.sync_rounded;
      case 'check':
        return Icons.check_circle_outline_rounded;
      case 'restart':
        return Icons.restart_alt_rounded;
      case 'block':
        return Icons.block_rounded;
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _colorFor(String key) {
    switch (key) {
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

  TextStyle _displayStyle({
    required double size,
    double height = 1.08,
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
