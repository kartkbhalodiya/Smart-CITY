import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class AdminResourceScreen extends StatefulWidget {
  final String resource;
  final String title;
  final String? workStatus;

  const AdminResourceScreen({
    super.key,
    required this.resource,
    required this.title,
    this.workStatus,
  });

  @override
  State<AdminResourceScreen> createState() => _AdminResourceScreenState();
}

class _AdminResourceScreenState extends State<AdminResourceScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);
  static const _primary = Color(0xFF2F80ED);

  final _searchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _title = '';
  String _role = '';
  bool _canCreate = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _fields = [];

  String get _resource => widget.resource.trim().toLowerCase();

  bool get _canEdit {
    if (_resource == 'departments') {
      return _role == 'superadmin' || _role == 'city_admin';
    }
    if ({
      'city-admins',
      'categories',
      'states',
      'cities',
    }.contains(_resource)) {
      return _role == 'superadmin';
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final query = _searchController.text.trim();
    final params = <String>[];
    if (query.isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(query)}');
    }
    final workStatus = widget.workStatus?.trim();
    if (workStatus != null && workStatus.isNotEmpty) {
      params.add('work_status=${Uri.encodeQueryComponent(workStatus)}');
    }
    final baseUrl = ApiConfig.adminResource(_resource);
    final url = params.isEmpty ? baseUrl : '$baseUrl?${params.join('&')}';
    final response = await ApiService.get(url);
    if (!mounted) return;

    if (response['success'] == true) {
      final rawItems = response['items'];
      final rawFields = response['fields'];
      setState(() {
        _title = response['title']?.toString() ?? widget.title;
        _role = response['role']?.toString() ?? '';
        _canCreate = response['can_create'] == true;
        _items = rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : [];
        _fields = rawFields is List
            ? rawFields
                .whereType<Map>()
                .map((field) => Map<String, dynamic>.from(field))
                .toList()
            : [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = response['message']?.toString() ?? 'Unable to load $_title.';
      _loading = false;
    });
  }

  Future<void> _save(
      Map<String, dynamic> body, Map<String, dynamic>? item) async {
    setState(() => _saving = true);
    final id = int.tryParse(item?['id']?.toString() ?? '');
    final response = id == null
        ? await ApiService.post(ApiConfig.adminResource(_resource), body)
        : await ApiService.put(
            ApiConfig.adminResourceDetail(_resource, id), body);
    if (!mounted) return;
    setState(() => _saving = false);

    if (response['success'] == true) {
      Navigator.pop(context);
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Saved')),
      );
      await _load();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message']?.toString() ?? 'Save failed')),
    );
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_singularTitle()}'),
        content: const Text('This action cannot be undone for unused records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final response =
        await ApiService.delete(ApiConfig.adminResourceDetail(_resource, id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message']?.toString() ?? 'Done')),
    );
    if (response['success'] == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _canCreate && !_loading
          ? FloatingActionButton.extended(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              elevation: 0,
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            )
          : null,
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
                padding: EdgeInsets.fromLTRB(24, 18, 24, 38 + bottomInset),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _topBar(),
                    const SizedBox(height: 18),
                    _titleBlock(),
                    const SizedBox(height: 16),
                    _searchField(),
                    const SizedBox(height: 18),
                    if (_loading)
                      _loadingState()
                    else if (_error != null)
                      _errorState()
                    else if (_items.isEmpty)
                      _emptyState()
                    else
                      ..._items.expand(
                        (item) => [
                          _resourceTile(item),
                          const SizedBox(height: 10),
                        ],
                      ),
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
          Image.asset(
            'assets/images/logo.png',
            width: 118,
            fit: BoxFit.contain,
          ),
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

  Widget _titleBlock() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _displayStyle(size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                '${_items.length} record${_items.length == 1 ? '' : 's'} in this scope',
                style: _labelStyle(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        if (_canCreate)
          _smallActionButton(
            label: 'New',
            icon: Icons.add_rounded,
            onTap: () => _openEditor(null),
          ),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      height: 56,
      decoration: _cardDecoration(radius: 18),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _load(),
        style: _labelStyle(
          size: 15,
          weight: FontWeight.w700,
          color: _text,
        ),
        decoration: InputDecoration(
          hintText: 'Search $_title',
          hintStyle: _labelStyle(
            size: 14,
            weight: FontWeight.w600,
            color: const Color(0xFFA3A7B4),
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF8B90A0)),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _load();
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }

  Widget _resourceTile(Map<String, dynamic> item) {
    if (_isComplaintResource()) {
      return _complaintTile(item);
    }
    if (_resource == 'departments') {
      return _departmentTile(item);
    }
    if (_resource == 'city-admins') {
      return _cityAdminTile(item);
    }
    if (_resource == 'citizens') {
      return _citizenTile(item);
    }
    if (_resource == 'analytics' || _resource == 'heatmap') {
      return _genericTile(
        item,
        Icons.analytics_outlined,
        item['name']?.toString() ?? 'Metric',
        item['subtitle']?.toString() ?? '',
        item['count']?.toString() ?? '0',
        editable: false,
      );
    }
    if (_resource == 'categories') {
      return _genericTile(
        item,
        Icons.category_outlined,
        item['name']?.toString() ?? 'Category',
        item['key']?.toString() ?? '',
        item['is_active'] == true ? 'Active' : 'Off',
      );
    }
    if (_resource == 'states') {
      return _genericTile(
        item,
        Icons.map_outlined,
        item['name']?.toString() ?? 'State',
        '${item['city_count'] ?? 0} cities',
        item['code']?.toString() ?? '',
      );
    }
    if (_resource == 'cities') {
      return _genericTile(
        item,
        Icons.location_city_outlined,
        item['name']?.toString() ?? 'City',
        item['state']?.toString() ?? '',
        item['code']?.toString() ?? '',
      );
    }
    return _genericTile(item, Icons.grid_view_rounded, 'Record', '', '');
  }

  Widget _complaintTile(Map<String, dynamic> item) {
    final status = item['work_status']?.toString() ?? '';
    final color = _statusColor(status);
    final id = int.tryParse(item['id']?.toString() ?? '');
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
              _iconBox(Icons.assignment_outlined, color),
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
                        size: 14.5,
                        weight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        item['complaint_type_display']?.toString() ?? '',
                        item['city']?.toString() ?? '',
                        _formatDate(item['created_at']),
                      ].where((text) => text.trim().isNotEmpty).join(' - '),
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
                        _pill(item['complaint_number']?.toString() ?? 'New',
                            _ink),
                        _pill(item['work_status_display']?.toString() ?? status,
                            color),
                      ],
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

  Widget _departmentTile(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '');
    return _managementTile(
      item: item,
      icon: Icons.account_balance_outlined,
      color: _primary,
      title: item['name']?.toString() ?? 'Department',
      subtitle: [
        item['department_type_display']?.toString() ?? '',
        item['city']?.toString() ?? '',
        item['state']?.toString() ?? '',
      ].where((text) => text.trim().isNotEmpty).join(' - '),
      badge: item['is_active'] == true ? 'Active' : 'Off',
      editable: _canEdit,
      onTap: id == null
          ? null
          : () => Navigator.pushNamed(
                context,
                AppRoutes.adminDepartmentDetail,
                arguments: {'departmentId': id},
              ),
    );
  }

  Widget _cityAdminTile(Map<String, dynamic> item) {
    return _managementTile(
      item: item,
      icon: Icons.admin_panel_settings_outlined,
      color: const Color(0xFF0F766E),
      title: item['name']?.toString() ?? 'City Admin',
      subtitle: [
        item['city']?.toString() ?? '',
        item['state']?.toString() ?? '',
        item['email']?.toString() ?? '',
      ].where((text) => text.trim().isNotEmpty).join(' - '),
      badge: item['is_active'] == true ? 'Active' : 'Off',
      editable: _canEdit,
    );
  }

  Widget _citizenTile(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '');
    return _genericTile(
      item,
      Icons.person_outline_rounded,
      item['name']?.toString() ?? 'Citizen',
      [
        item['city']?.toString() ?? '',
        item['mobile_no']?.toString() ?? '',
        item['email']?.toString() ?? '',
      ].where((text) => text.trim().isNotEmpty).join(' - '),
      item['state']?.toString() ?? '',
      editable: false,
      onTap: id == null
          ? null
          : () => Navigator.pushNamed(
                context,
                AppRoutes.adminCitizenDetail,
                arguments: {'citizenId': id},
              ),
    );
  }

  Widget _genericTile(
    Map<String, dynamic> item,
    IconData icon,
    String title,
    String subtitle,
    String badge, {
    bool editable = true,
    VoidCallback? onTap,
  }) {
    return _managementTile(
      item: item,
      icon: icon,
      color: const Color(0xFF7C3AED),
      title: title,
      subtitle: subtitle,
      badge: badge,
      editable: editable && _canEdit,
      onTap: onTap,
    );
  }

  Widget _managementTile({
    required Map<String, dynamic> item,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String badge,
    bool editable = true,
    VoidCallback? onTap,
  }) {
    final effectiveTap = onTap ?? (editable ? () => _openEditor(item) : null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: effectiveTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: _cardDecoration(radius: 20),
          child: Row(
            children: [
              _iconBox(icon, color),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 5),
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
              const SizedBox(width: 10),
              if (badge.isNotEmpty) _pill(badge, color),
              if (editable && onTap != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF64748B), size: 19),
                  onPressed: () => _openEditor(item),
                ),
              ],
              if (effectiveTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(Map<String, dynamic>? item) {
    if (!_canEdit && item != null) return;
    if (_fields.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    final values = <String, dynamic>{};
    final controllers = <String, TextEditingController>{};

    for (final field in _fields) {
      final key = field['key']?.toString() ?? '';
      if (key.isEmpty) continue;
      final initial = _initialValue(key, field, item);
      values[key] = initial;
      final type = field['type']?.toString() ?? 'text';
      if (type != 'bool' && type != 'select') {
        controllers[key] =
            TextEditingController(text: initial?.toString() ?? '');
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8DEE8),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          item == null
                              ? 'Add ${_singularTitle()}'
                              : 'Edit ${_singularTitle()}',
                          style: _displayStyle(size: 25),
                        ),
                        const SizedBox(height: 16),
                        ..._fields.map((field) {
                          final key = field['key']?.toString() ?? '';
                          final type = field['type']?.toString() ?? 'text';
                          if (type == 'bool') {
                            return _boolField(field, values, setModalState);
                          }
                          if (type == 'select') {
                            return _selectField(field, values, setModalState);
                          }
                          return _textField(field, controllers[key]!);
                        }),
                        const SizedBox(height: 14),
                        _blackButton(
                          label: _saving ? 'Saving...' : 'Save',
                          icon: Icons.check_rounded,
                          onTap: _saving
                              ? null
                              : () {
                                  if (formKey.currentState?.validate() !=
                                      true) {
                                    return;
                                  }
                                  final body = <String, dynamic>{};
                                  for (final field in _fields) {
                                    final key = field['key']?.toString() ?? '';
                                    final type =
                                        field['type']?.toString() ?? 'text';
                                    if (type == 'bool') {
                                      body[key] = values[key] == true ||
                                          values[key]?.toString() == 'true';
                                    } else if (type == 'select') {
                                      body[key] = values[key];
                                    } else {
                                      body[key] = controllers[key]?.text.trim();
                                    }
                                  }
                                  _save(body, item);
                                },
                        ),
                        if (item != null && _canEdit) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _delete(item);
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete or deactivate'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  Widget _textField(
      Map<String, dynamic> field, TextEditingController controller) {
    final label = field['label']?.toString() ?? '';
    final required = field['required'] == true;
    final type = field['type']?.toString() ?? 'text';
    final maxLines = type == 'textarea' ? 3 : 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        obscureText: type == 'password',
        keyboardType: type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : type == 'email'
                ? TextInputType.emailAddress
                : type == 'phone'
                    ? TextInputType.phone
                    : TextInputType.text,
        validator: (value) {
          if (required && (value ?? '').trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        style: _labelStyle(size: 15, weight: FontWeight.w800, color: _text),
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _selectField(
    Map<String, dynamic> field,
    Map<String, dynamic> values,
    StateSetter setModalState,
  ) {
    final key = field['key']?.toString() ?? '';
    final label = field['label']?.toString() ?? '';
    final options =
        field['options'] is List ? field['options'] as List : const [];
    final selected = values[key]?.toString();
    final allowedValues = options
        .whereType<Map>()
        .map((option) => (option['value'] ?? option['id'])?.toString())
        .whereType<String>()
        .toSet();
    final value =
        selected != null && allowedValues.contains(selected) ? selected : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        validator: (next) {
          if (field['required'] == true && (next == null || next.isEmpty)) {
            return '$label is required';
          }
          return null;
        },
        items: options.whereType<Map>().map((option) {
          final optionValue = (option['value'] ?? option['id']).toString();
          final optionLabel = option['label']?.toString() ?? optionValue;
          return DropdownMenuItem<String>(
            value: optionValue,
            child: Text(
              optionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (next) => setModalState(() => values[key] = next),
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _boolField(
    Map<String, dynamic> field,
    Map<String, dynamic> values,
    StateSetter setModalState,
  ) {
    final key = field['key']?.toString() ?? '';
    final current = values[key] == true || values[key]?.toString() == 'true';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: _cardDecoration(radius: 18),
        child: SwitchListTile(
          value: current,
          onChanged: (next) => setModalState(() => values[key] = next),
          title: Text(
            field['label']?.toString() ?? key,
            style: _labelStyle(size: 14, weight: FontWeight.w800, color: _text),
          ),
          activeThumbColor: _ink,
        ),
      ),
    );
  }

  dynamic _initialValue(
    String key,
    Map<String, dynamic> field,
    Map<String, dynamic>? item,
  ) {
    if (item == null) return field['default'];
    if (key == 'full_name') return item['name'];
    if (key == 'city') return item['city'];
    if (key == 'state') return item['state'];
    if (key == 'city_admin_id') return item['city_admin_id']?.toString();
    if (key == 'password') return '';
    return item[key] ?? field['default'];
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: _labelStyle(
        size: 13,
        weight: FontWeight.w700,
        color: _muted,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _ink, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Widget _loadingState() => Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 78,
              decoration: _cardDecoration(radius: 20),
            ),
          ),
        ),
      );

  Widget _errorState() => _messageBox(
        icon: Icons.error_outline_rounded,
        title: _error ?? 'Unable to load',
        action: _load,
      );

  Widget _emptyState() => _messageBox(
        icon: Icons.inbox_outlined,
        title: 'No records found',
        action: _load,
      );

  Widget _messageBox({
    required IconData icon,
    required String title,
    required VoidCallback action,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        children: [
          Icon(icon, color: _muted, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _labelStyle(size: 14, weight: FontWeight.w800, color: _text),
          ),
          const SizedBox(height: 12),
          _smallActionButton(
            label: 'Reload',
            icon: Icons.refresh_rounded,
            onTap: action,
          ),
        ],
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

  Widget _smallActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Ink(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(15),
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

  Widget _blackButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.65 : 1,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
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

  Widget _iconBox(IconData icon, Color color) {
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

  Widget _pill(String label, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
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
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  bool _isComplaintResource() => {
        'complaints',
        'problems',
        'solved',
        'review',
        'total'
      }.contains(_resource);

  String _singularTitle() {
    if (_title.endsWith('ies')) return _title.substring(0, _title.length - 3);
    if (_title.endsWith('s')) return _title.substring(0, _title.length - 1);
    return _title;
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

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
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
