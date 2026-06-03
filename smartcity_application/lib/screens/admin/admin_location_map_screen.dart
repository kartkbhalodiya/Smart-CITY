import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class AdminLocationMapScreen extends StatefulWidget {
  final String type;
  final int id;

  const AdminLocationMapScreen({
    super.key,
    required this.type,
    required this.id,
  });

  @override
  State<AdminLocationMapScreen> createState() => _AdminLocationMapScreenState();
}

class _AdminLocationMapScreenState extends State<AdminLocationMapScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);
  static const _primary = Color(0xFF2F80ED);

  bool _loading = true;
  String? _error;
  String _title = 'Location Map';
  String _subtitle = 'Admin location view';
  final List<_MapPin> _pins = [];
  final List<MapEntry<String, String>> _facts = [];

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

    if (widget.id <= 0) {
      setState(() {
        _error = 'Invalid map record.';
        _loading = false;
      });
      return;
    }

    final endpoint = switch (widget.type) {
      'department' => ApiConfig.adminDepartmentDetail(widget.id),
      'citizen' => ApiConfig.adminCitizenDetail(widget.id),
      _ => ApiConfig.complaintDetail(widget.id),
    };
    final response = await ApiService.get(endpoint);
    if (!mounted) return;

    if (response['success'] == false) {
      setState(() {
        _error = response['message']?.toString() ?? 'Unable to load map.';
        _loading = false;
      });
      return;
    }

    final pins = <_MapPin>[];
    final facts = <MapEntry<String, String>>[];
    var title = 'Location Map';
    var subtitle = 'Admin location view';

    switch (widget.type) {
      case 'department':
        final parsed = _parseDepartmentMap(response);
        title = parsed.title;
        subtitle = parsed.subtitle;
        pins.addAll(parsed.pins);
        facts.addAll(parsed.facts);
        break;
      case 'citizen':
        final parsed = _parseCitizenMap(response);
        title = parsed.title;
        subtitle = parsed.subtitle;
        pins.addAll(parsed.pins);
        facts.addAll(parsed.facts);
        break;
      default:
        final parsed = _parseComplaintMap(response);
        title = parsed.title;
        subtitle = parsed.subtitle;
        pins.addAll(parsed.pins);
        facts.addAll(parsed.facts);
    }

    setState(() {
      _title = title;
      _subtitle = subtitle;
      _pins
        ..clear()
        ..addAll(pins);
      _facts
        ..clear()
        ..addAll(facts);
      _loading = false;
    });
  }

  _ParsedMap _parseComplaintMap(Map<String, dynamic> response) {
    final raw = _asMap(response['complaint']) ?? response;
    final pins = <_MapPin>[];
    final complaintPoint = _pointFrom(raw);
    final complaintTitle = _textValue(raw['title'], fallback: 'Complaint');
    final complaintSubtitle = [
      _textValue(raw['complaint_number']),
      _textValue(raw['work_status_display'],
          fallback: _textValue(raw['work_status'])),
      _textValue(raw['city']),
    ].where((part) => part.isNotEmpty).join(' - ');

    if (complaintPoint != null) {
      pins.add(
        _MapPin(
          point: complaintPoint,
          title: complaintTitle,
          subtitle: complaintSubtitle,
          color: _statusColor(_textValue(raw['work_status'])),
          icon: Icons.location_on_rounded,
        ),
      );
    }

    final department = _asMap(raw['assigned_department']);
    if (department != null) {
      final departmentPoint = _pointFrom(department) ??
          _pointFrom({
            'latitude': raw['assigned_department_latitude'],
            'longitude': raw['assigned_department_longitude'],
          });
      if (departmentPoint != null) {
        pins.add(
          _MapPin(
            point: departmentPoint,
            title:
                _textValue(department['name'], fallback: 'Assigned Department'),
            subtitle: [
              _textValue(department['department_type_display']),
              _textValue(department['city']),
              _textValue(department['state']),
            ].where((part) => part.isNotEmpty).join(' - '),
            color: _primary,
            icon: Icons.account_balance_outlined,
            departmentId: _toInt(department['id']),
          ),
        );
      }
    }

    return _ParsedMap(
      title: complaintTitle,
      subtitle:
          complaintSubtitle.isEmpty ? 'Complaint location' : complaintSubtitle,
      pins: pins,
      facts: [
        MapEntry('Complaint No.', _textValue(raw['complaint_number'])),
        MapEntry('Status', _textValue(raw['work_status_display'])),
        MapEntry('City', _textValue(raw['city'])),
        MapEntry('Address', _textValue(raw['address'])),
      ],
    );
  }

  _ParsedMap _parseDepartmentMap(Map<String, dynamic> response) {
    final department = _asMap(response['department']) ?? const {};
    final mapData = _asMap(response['map']) ?? const {};
    final pins = <_MapPin>[];
    final departmentPoint =
        _pointFrom(_asMap(mapData['department']) ?? department);
    final title = _textValue(department['name'], fallback: 'Department');
    final subtitle = [
      _textValue(department['department_type_display']),
      _textValue(department['city']),
      _textValue(department['state']),
    ].where((part) => part.isNotEmpty).join(' - ');

    if (departmentPoint != null) {
      pins.add(
        _MapPin(
          point: departmentPoint,
          title: title,
          subtitle: subtitle,
          color: _primary,
          icon: Icons.account_balance_outlined,
        ),
      );
    }

    for (final item in _asList(mapData['complaints']).take(80)) {
      final point = _pointFrom(item);
      if (point == null) continue;
      pins.add(
        _MapPin(
          point: point,
          title: _textValue(item['title'], fallback: 'Complaint'),
          subtitle: [
            _textValue(item['complaint_number']),
            _textValue(item['status_display'],
                fallback: _textValue(item['status'])),
          ].where((part) => part.isNotEmpty).join(' - '),
          color: _statusColor(_textValue(item['status'])),
          icon: Icons.location_on_rounded,
          complaintId: _toInt(item['complaint_id'] ?? item['id']),
        ),
      );
    }

    return _ParsedMap(
      title: title,
      subtitle: subtitle.isEmpty ? 'Department service map' : subtitle,
      pins: pins,
      facts: [
        MapEntry('Type', _textValue(department['department_type_display'])),
        MapEntry('Phone', _textValue(department['phone'])),
        MapEntry('Email', _textValue(department['email'])),
        MapEntry('Address', _textValue(department['address'])),
      ],
    );
  }

  _ParsedMap _parseCitizenMap(Map<String, dynamic> response) {
    final citizen = _asMap(response['citizen']) ?? const {};
    final mapData = _asMap(response['map']) ?? const {};
    final pins = <_MapPin>[];
    final homePoint = _pointFrom(_asMap(mapData['home']) ?? citizen);
    final title = _textValue(citizen['name'], fallback: 'Citizen');
    final subtitle = [
      _textValue(citizen['email']),
      _textValue(citizen['city']),
      _textValue(citizen['state']),
    ].where((part) => part.isNotEmpty).join(' - ');

    if (homePoint != null) {
      pins.add(
        _MapPin(
          point: homePoint,
          title: title,
          subtitle: _textValue(citizen['address'], fallback: subtitle),
          color: const Color(0xFF16A34A),
          icon: Icons.home_outlined,
        ),
      );
    }

    for (final item in _asList(mapData['complaints']).take(80)) {
      final point = _pointFrom(item);
      if (point == null) continue;
      pins.add(
        _MapPin(
          point: point,
          title: _textValue(item['title'], fallback: 'Complaint'),
          subtitle: [
            _textValue(item['complaint_number']),
            _textValue(item['status_display'],
                fallback: _textValue(item['status'])),
          ].where((part) => part.isNotEmpty).join(' - '),
          color: _statusColor(_textValue(item['status'])),
          icon: Icons.location_on_rounded,
          complaintId: _toInt(item['complaint_id'] ?? item['id']),
        ),
      );
    }

    return _ParsedMap(
      title: title,
      subtitle: subtitle.isEmpty ? 'Citizen location map' : subtitle,
      pins: pins,
      facts: [
        MapEntry('Email', _textValue(citizen['email'])),
        MapEntry('Phone', _textValue(citizen['mobile_no'])),
        MapEntry('City', _textValue(citizen['city'])),
        MapEntry('Address', _textValue(citizen['address'])),
      ],
    );
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
                      _headerCard(),
                      const SizedBox(height: 16),
                      _mapCard(),
                      const SizedBox(height: 16),
                      _infoCard(),
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

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 24),
      child: Row(
        children: [
          _iconBox(Icons.map_outlined, _primary, size: 54, iconSize: 27),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _displayStyle(size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle.isEmpty ? 'Admin location view' : _subtitle,
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

  Widget _mapCard() {
    if (_pins.isEmpty) return _emptyBox('No map coordinates available.');
    final center = _center;
    final height = MediaQuery.sizeOf(context).height;
    final mapHeight = height < 720 ? 380.0 : 520.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(radius: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: mapHeight,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: _pins.length == 1 ? 14 : 11,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.janhelp.app',
              ),
              MarkerLayer(
                markers: [
                  for (final pin in _pins) _marker(pin),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _marker(_MapPin pin) {
    return Marker(
      point: pin.point,
      width: 46,
      height: 46,
      child: GestureDetector(
        onTap: () => _openPin(pin),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(pin.icon, color: pin.color, size: 32),
        ),
      ),
    );
  }

  void _openPin(_MapPin pin) {
    if (pin.complaintId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.adminComplaintDetail,
        arguments: {'complaintId': pin.complaintId},
      );
      return;
    }
    if (pin.departmentId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.adminDepartmentDetail,
        arguments: {'departmentId': pin.departmentId},
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(radius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pin.title, style: _displayStyle(size: 20)),
              const SizedBox(height: 8),
              Text(
                pin.subtitle.isEmpty ? 'Location marker' : pin.subtitle,
                style: _labelStyle(
                  size: 13,
                  weight: FontWeight.w700,
                  color: _muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard() {
    final rows = _facts
        .where((item) => item.value.trim().isNotEmpty)
        .toList(growable: false);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 20),
      child: Column(
        children: [
          for (final row in rows) _infoRow(row.key, row.value),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: _labelStyle(
                size: 11.5,
                weight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not available' : value.trim(),
              style: _labelStyle(
                size: 13,
                weight: FontWeight.w800,
                color: _text,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingState() {
    return Column(
      children: [
        Container(height: 126, decoration: _cardDecoration(radius: 24)),
        const SizedBox(height: 16),
        Container(height: 430, decoration: _cardDecoration(radius: 24)),
        const SizedBox(height: 16),
        Container(height: 160, decoration: _cardDecoration(radius: 20)),
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

  LatLng get _center {
    if (_pins.isEmpty) return const LatLng(20.5937, 78.9629);
    final lat = _pins.fold<double>(0, (sum, pin) => sum + pin.point.latitude) /
        _pins.length;
    final lng = _pins.fold<double>(0, (sum, pin) => sum + pin.point.longitude) /
        _pins.length;
    return LatLng(lat, lng);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  LatLng? _pointFrom(Map<String, dynamic> item) {
    final lat = _toDouble(item['latitude']);
    final lng = _toDouble(item['longitude']);
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _textValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
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

class _ParsedMap {
  final String title;
  final String subtitle;
  final List<_MapPin> pins;
  final List<MapEntry<String, String>> facts;

  const _ParsedMap({
    required this.title,
    required this.subtitle,
    required this.pins,
    required this.facts,
  });
}

class _MapPin {
  final LatLng point;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final int? complaintId;
  final int? departmentId;

  const _MapPin({
    required this.point,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.complaintId,
    this.departmentId,
  });
}
