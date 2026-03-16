import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../providers/complaint_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../l10n/app_strings.dart';
import './map_selection_screen.dart';

class SubmitComplaintScreen extends StatefulWidget {
  final String? categoryKey;
  final String? categoryName;
  const SubmitComplaintScreen({super.key, this.categoryKey, this.categoryName});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  static const _primary = Color(0xFF1E66F5);
  static const _textDark = Color(0xFF0f172a);
  static const _textMuted = Color(0xFF64748b);
  static const _borderColor = Color(0xFFe2e8f0);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _geoCtrl = TextEditingController();

  String _priority = 'medium'; // high, medium, normal

  List<String> _allStates = [];
  Map<String, List<String>> _citiesByState = {};
  String? _selectedState;
  String? _selectedCity;

  // Dynamic field controllers keyed by field id
  final Map<int, TextEditingController> _dynCtrl = {};
  final Map<int, String?> _dynDropdown = {};
  final Map<int, String?> _dynDate = {};

  List<Map<String, dynamic>> _subcategories = [];
  List<Map<String, dynamic>> _categoryFields = [];
  Map<String, dynamic>? _selectedSub;
  bool _loadingMeta = true;

  final List<File> _images = [];
  bool _submitting = false;
  bool _isPreviewing = false;
  double? _lat, _lng;

  static const _emojiMap = {
    'police': '🚓', 'traffic': '🚦', 'construction': '🏗️',
    'water': '🚰', 'electricity': '💡', 'garbage': '🗑️',
    'road': '🛣️', 'drainage': '🌊', 'illegal': '⚠️',
    'transportation': '🚌', 'cyber': '🛡️', 'other': '📋',
  };

  static const _bgMap = {
    'police': Color(0xFFEEF2FF), 'traffic': Color(0xFFFFF7ED),
    'construction': Color(0xFFF0F9FF), 'water': Color(0xFFF0FDF4),
    'electricity': Color(0xFFFFFBEB), 'garbage': Color(0xFFECFDF5),
    'road': Color(0xFFFAF5FF), 'drainage': Color(0xFFEFF6FF),
    'illegal': Color(0xFFFFF1F2), 'transportation': Color(0xFFF0F9FF),
    'cyber': Color(0xFFF5F3FF), 'other': Color(0xFFF8FAFC),
  };

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _detectLocation();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _pincodeCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _geoCtrl.dispose();
    for (final c in _dynCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    if (widget.categoryKey == null) {
      if (mounted) setState(() => _loadingMeta = false);
      return;
    }
    
    setState(() => _loadingMeta = true);
    try {
      final provider = Provider.of<ComplaintProvider>(context, listen: false);
      
      // Load both meta and states/cities in parallel
      final results = await Future.wait([
        provider.getSubcategories(widget.categoryKey!),
        provider.loadStatesCities(),
      ]);

      final res = results[0] as Map<String, dynamic>;
      
      if (res['success'] == true) {
        final rawSubs = res['subcategories'] as List? ?? [];
        final subs = rawSubs.map((e) {
          final sub = Map<String, dynamic>.from(e as Map);
          final fields = sub['dynamic_fields'] as List? ?? [];
          sub['dynamic_fields'] = fields.map((f) => Map<String, dynamic>.from(f as Map)).toList();
          return sub;
        }).toList();
        
        final rawCatFields = res['category_fields'] as List? ?? [];
        final catFields = rawCatFields.map((f) => Map<String, dynamic>.from(f as Map)).toList();
        
        // Initialize controllers for category fields
        for (final f in catFields) {
          final id = f['id'] as int;
          final type = f['field_type'] as String;
          if (type == 'select') {
            _dynDropdown[id] = null;
          } else if (type == 'date' || type == 'datetime-local') {
            _dynDate[id] = null;
          } else {
            _dynCtrl[id] = TextEditingController();
          }
        }

        Map<String, dynamic>? firstSub;
        if (subs.isNotEmpty) {
          firstSub = subs.first;
          // Init controllers for first subcategory
          final fields = firstSub['dynamic_fields'] as List<Map<String, dynamic>>? ?? [];
          for (final f in fields) {
            final id = f['id'] as int;
            final type = f['field_type'] as String;
            if (_dynCtrl.containsKey(id) || _dynDropdown.containsKey(id) || _dynDate.containsKey(id)) continue;
            if (type == 'select') {
              _dynDropdown[id] = null;
            } else if (type == 'date' || type == 'datetime-local') {
              _dynDate[id] = null;
            } else {
              _dynCtrl[id] = TextEditingController();
            }
          }
        }

        if (mounted) {
          setState(() {
            _subcategories = subs;
            _categoryFields = catFields;
            _selectedSub = firstSub;
            _allStates = provider.states;
            _citiesByState = provider.citiesByState;
            _loadingMeta = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingMeta = false);
      }
    } catch (e) {
      debugPrint('_loadMeta error: $e');
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  void _selectSub(Map<String, dynamic> sub) {
    // Keep category fields, but clear old subcategory fields
    final oldSubFields = _selectedSub != null ? (_selectedSub!['dynamic_fields'] as List<Map<String, dynamic>>? ?? []) : [];
    for (final f in oldSubFields) {
      final id = f['id'] as int;
      // Only remove if it's NOT a category field
      if (!_categoryFields.any((cf) => cf['id'] == id)) {
        _dynCtrl.remove(id)?.dispose();
        _dynDropdown.remove(id);
        _dynDate.remove(id);
      }
    }

    // Init new controllers for new subcategory
    final fields = sub['dynamic_fields'] as List<Map<String, dynamic>>? ?? [];
    for (final f in fields) {
      final id = f['id'] as int;
      final type = f['field_type'] as String;
      
      // Don't re-init if already exists (from category fields)
      if (_dynCtrl.containsKey(id) || _dynDropdown.containsKey(id) || _dynDate.containsKey(id)) continue;

      if (type == 'select') {
        _dynDropdown[id] = null;
      } else if (type == 'date' || type == 'datetime-local') {
        _dynDate[id] = null;
      } else {
        _dynCtrl[id] = TextEditingController();
      }
    }
    setState(() => _selectedSub = sub);
  }

  Future<void> _detectLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _geoCtrl.text = '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}';
      final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
      if (mounted) {
        if ((addr['address'] ?? '').isNotEmpty) {
          _addressCtrl.text = addr['address']!;
        }
        if (addr['city'] != null) {
          final city = addr['city']!;
          // Find state by city if not directly available or to sync
          String? foundState = addr['state'];
          if (foundState != null && _allStates.contains(foundState)) {
            _selectedState = foundState;
            if (_citiesByState[_selectedState]?.contains(city) == true) {
              _selectedCity = city;
            }
          } else {
            // Search city in all states
            for (final entry in _citiesByState.entries) {
              if (entry.value.contains(city)) {
                _selectedState = entry.key;
                _selectedCity = city;
                break;
              }
            }
          }
        }
        if (addr['pincode'] != null) _pincodeCtrl.text = addr['pincode']!;
        setState(() {});
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) setState(() => _images.add(File(picked.path)));
  }

  void _updateGeoFromText(String v) {
    try {
      final parts = v.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          _lat = lat;
          _lng = lng;
        }
      }
    } catch (_) {}
  }

  Future<void> _selectOnMap() async {
    final ll.LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectionScreen(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );

    if (result != null && mounted) {
      _lat = result.latitude;
      _lng = result.longitude;
      _geoCtrl.text = '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}';
      
      // Update address automatically from coordinates
      final addr = await LocationService.getAddressFromCoordinates(_lat!, _lng!);
      if (mounted) {
        if ((addr['address'] ?? '').isNotEmpty) {
          _addressCtrl.text = addr['address']!;
        }
        if (addr['city'] != null) {
          final city = addr['city']!;
          String? foundState = addr['state'];
          if (foundState != null && _allStates.contains(foundState)) {
            _selectedState = foundState;
            if (_citiesByState[_selectedState]?.contains(city) == true) {
              _selectedCity = city;
            }
          } else {
            for (final entry in _citiesByState.entries) {
              if (entry.value.contains(city)) {
                _selectedState = entry.key;
                _selectedCity = city;
                break;
              }
            }
          }
        }
        if (addr['pincode'] != null) _pincodeCtrl.text = addr['pincode']!;
        setState(() {});
      }
    }
  }

  Future<void> _pickDate(int fieldId, bool withTime) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    if (withTime) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() => _dynDate[fieldId] =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}');
        return;
      }
    }
    setState(() => _dynDate[fieldId] =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
  }

  Future<void> _submit() async {
    if (!_isPreviewing) {
      if (_selectedSub == null && _subcategories.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'Please select a subcategory')), backgroundColor: Colors.orange),
        );
        return;
      }
      if (!_formKey.currentState!.validate()) return;

      // Validate date fields
      if (_selectedSub != null) {
        for (final f in (_selectedSub!['dynamic_fields'] as List<Map<String, dynamic>>? ?? [])) {
          final id = f['id'] as int;
          final type = f['field_type'] as String;
          final required = f['is_required'] == true;
          if ((type == 'date' || type == 'datetime-local') && required && (_dynDate[id] == null || _dynDate[id]!.isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${f['label']} ${AppStrings.t(context, 'is required')}'), backgroundColor: Colors.orange),
            );
            return;
          }
        }
      }
      setState(() => _isPreviewing = true);
      return;
    }

    setState(() => _submitting = true);

    final data = <String, String>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'latitude': (_lat ?? 20.5937).toString(),
      'longitude': (_lng ?? 78.9629).toString(),
      'complaint_type': widget.categoryKey ?? 'other',
      'priority': _priority,
      'name': _nameCtrl.text.trim(),
      'mobile_no': _mobileCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'state': _selectedState ?? '',
      'city': _selectedCity ?? '',
      if (_selectedSub != null) 'subcategory': _selectedSub!['name'] as String,
    };

    // Collect dynamic fields from both category and subcategory
    final allFields = [..._categoryFields];
    if (_selectedSub != null) {
      allFields.addAll(_selectedSub!['dynamic_fields'] as List<Map<String, dynamic>>? ?? []);
    }

    for (final f in allFields) {
      final id = f['id'] as int;
      final type = f['field_type'] as String;
      String? value;
      if (type == 'select') {
        value = _dynDropdown[id];
      } else if (type == 'date' || type == 'datetime-local') {
        value = _dynDate[id];
      } else {
        value = _dynCtrl[id]?.text;
      }
      if (value != null && value.isNotEmpty) {
        data['field_$id'] = value;
      }
    }

    final provider = Provider.of<ComplaintProvider>(context, listen: false);
    final res = await provider.createComplaint(data, _images);
    setState(() => _submitting = false);

    if (!mounted) return;
    if (res != null) {
      await provider.refresh();
      
      final complaint = res['complaint'];
      final complaintId = complaint?['complaint_number'] ?? AppStrings.t(context, 'N/A');
      final title = complaint?['title'] ?? _titleCtrl.text;
      final desc = complaint?['description'] ?? _descCtrl.text;

      Navigator.pushReplacementNamed(
        context, 
        AppRoutes.complaintSuccess,
        arguments: {
          'complaintId': complaintId,
          'title': title,
          'description': desc,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? AppStrings.t(context, 'Failed to submit')), backgroundColor: Colors.red),
      );
    }
  }

  Widget _previewSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppStrings.t(context, 'Preview Your Complaint'),
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: _textDark)),
        const SizedBox(height: 4),
        Text(AppStrings.t(context, 'Please verify your details before confirming'),
            style: GoogleFonts.inter(fontSize: 14, color: _textMuted)),
        const SizedBox(height: 24),
        
        _previewCard(AppStrings.t(context, 'Issue Details'), [
          (AppStrings.t(context, 'Title'), _titleCtrl.text),
          (AppStrings.t(context, 'Category'), widget.categoryName ?? AppStrings.t(context, 'Other')),
          if (_selectedSub != null) (AppStrings.t(context, 'Subcategory'), _selectedSub!['name'] as String),
          (AppStrings.t(context, 'Priority'), _priority.toUpperCase()),
          (AppStrings.t(context, 'Description'), _descCtrl.text),
        ]),
        const SizedBox(height: 16),
        
        _previewCard(AppStrings.t(context, 'Location'), [
          (AppStrings.t(context, 'Address'), _addressCtrl.text),
          (AppStrings.t(context, 'City'), _selectedCity ?? AppStrings.t(context, 'Not Selected')),
          (AppStrings.t(context, 'State'), _selectedState ?? AppStrings.t(context, 'Not Selected')),
          (AppStrings.t(context, 'Pincode'), _pincodeCtrl.text),
        ]),
        const SizedBox(height: 16),
        
        _previewCard(AppStrings.t(context, 'Personal Info'), [
          (AppStrings.t(context, 'Name'), _nameCtrl.text),
          (AppStrings.t(context, 'Mobile'), _mobileCtrl.text),
          if (_emailCtrl.text.isNotEmpty) (AppStrings.t(context, 'Email'), _emailCtrl.text),
        ]),
        const SizedBox(height: 32),
        
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(AppStrings.t(context, 'Confirm & Submit'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => setState(() => _isPreviewing = false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(AppStrings.t(context, 'Edit Details'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _primary)),
          ),
        ),
      ]),
    );
  }

  Widget _previewCard(String title, List<(String, String)> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _primary)),
        const Divider(height: 24),
        ...items.map((it) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.$1, style: GoogleFonts.inter(fontSize: 12, color: _textMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(it.$2, style: GoogleFonts.inter(fontSize: 14, color: _textDark, fontWeight: FontWeight.w600)),
          ]),
        )).toList(),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.categoryKey ?? 'other';
    final emoji = _emojiMap[key] ?? '📋';
    final bg = _bgMap[key] ?? const Color(0xFFF8FAFC);
    final name = widget.categoryName ?? AppStrings.t(context, 'Complaint');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        _topNav(emoji, bg, name),
        Expanded(
          child: _loadingMeta
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _isPreviewing 
                ? _previewSection()
                : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildFormSections()),
                  ),
                ),
        ),
      ]),
    );
  }

  List<Widget> _buildFormSections() {
    final sections = <Widget>[];
    int step = 1;

    // ── Step 1: Subcategory selection ─────────────────
    if (_subcategories.isNotEmpty) {
      sections.add(_sectionTitle((step++).toString(), AppStrings.t(context, 'Select Subcategory')));
      sections.add(const SizedBox(height: 12));
      sections.add(_subcategoryGrid());
      sections.add(const SizedBox(height: 24));
    }

    // ── Category-level fields ──────────────────────────
    if (_categoryFields.isNotEmpty) {
      sections.add(_sectionTitle((step++).toString(), AppStrings.t(context, 'Additional Information')));
      sections.add(const SizedBox(height: 12));
      sections.add(_card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildDynamicFields(_categoryFields),
      )));
      sections.add(const SizedBox(height: 24));
    }

    // ── Step 2: Dynamic fields for selected subcategory
    if (_selectedSub != null) {
      final subFields = _selectedSub!['dynamic_fields'] as List<Map<String, dynamic>>? ?? [];
      if (subFields.isNotEmpty) {
        sections.add(_sectionTitle((step++).toString(), _selectedSub!['name'] as String));
        sections.add(const SizedBox(height: 12));
        sections.add(_card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildDynamicFields(subFields),
        )));
        sections.add(const SizedBox(height: 24));
      }
    }

    // ── Step 3: Contact Information ──────────────────
    sections.add(_sectionTitle((step++).toString(), AppStrings.t(context, 'Contact Information')));
    sections.add(const SizedBox(height: 12));
    sections.add(_card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(AppStrings.t(context, 'Full Name')),
      const SizedBox(height: 6),
      _textField(
        controller: _nameCtrl,
        hint: AppStrings.t(context, 'Your full name'),
        validator: (v) => (v ?? '').trim().isEmpty ? AppStrings.t(context, 'Name is required') : null,
      ),
      const SizedBox(height: 16),
      _label(AppStrings.t(context, 'Mobile Number')),
      const SizedBox(height: 6),
      _textField(
        controller: _mobileCtrl,
        hint: AppStrings.t(context, 'Your contact number'),
        keyboard: TextInputType.phone,
        validator: (v) => (v ?? '').trim().isEmpty ? AppStrings.t(context, 'Mobile number is required') : null,
      ),
      const SizedBox(height: 16),
      _label(AppStrings.t(context, 'Email Address')),
      const SizedBox(height: 6),
      _textField(
        controller: _emailCtrl,
        hint: AppStrings.t(context, 'Your email address'),
        keyboard: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      _label(AppStrings.t(context, 'State')),
      const SizedBox(height: 6),
      _dropdownField(
        hint: AppStrings.t(context, 'Select State'),
        value: _selectedState,
        items: _allStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() {
          _selectedState = v;
          _selectedCity = null;
        }),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(AppStrings.t(context, 'City')),
          const SizedBox(height: 6),
          _dropdownField(
            hint: AppStrings.t(context, 'Select City'),
            value: _selectedCity,
            items: (_citiesByState[_selectedState] ?? []).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _selectedCity = v),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(AppStrings.t(context, 'Pincode')),
          const SizedBox(height: 6),
          _textField(controller: _pincodeCtrl, hint: AppStrings.t(context, 'Pincode'), keyboard: TextInputType.number),
        ])),
      ]),
    ])));
    sections.add(const SizedBox(height: 24));

    // ── Step 4: Priority & Severity ───────────────────
    sections.add(_sectionTitle((step++).toString(), AppStrings.t(context, 'Set Priority')));
    sections.add(const SizedBox(height: 12));
    sections.add(_prioritySelector());
    sections.add(const SizedBox(height: 24));

    // ── Step 5: Complaint details ─────────────────────
    sections.add(_sectionTitle((step++).toString(), AppStrings.t(context, 'Complaint Details')));
    sections.add(const SizedBox(height: 12));
    sections.add(_card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(AppStrings.t(context, 'Title')),
      const SizedBox(height: 6),
      _textField(
        controller: _titleCtrl,
        hint: AppStrings.t(context, 'Brief title of your complaint'),
        validator: (v) => (v ?? '').trim().isEmpty ? AppStrings.t(context, 'Title is required') : null,
      ),
      const SizedBox(height: 16),
      _label(AppStrings.t(context, 'Description')),
      const SizedBox(height: 6),
      _textField(
        controller: _descCtrl,
        hint: AppStrings.t(context, 'Describe the issue in detail...'),
        maxLines: 4,
        validator: (v) => (v ?? '').trim().isEmpty ? AppStrings.t(context, 'Description is required') : null,
      ),
      const SizedBox(height: 16),
      _label(AppStrings.t(context, 'Location / Address')),
      const SizedBox(height: 6),
      _textField(
        controller: _addressCtrl,
        hint: AppStrings.t(context, 'Address of the issue'),
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      _locationButtons(),
      const SizedBox(height: 16),
      _label(AppStrings.t(context, 'Geo Coordinates (Lat, Lng)')),
      const SizedBox(height: 6),
      _textField(
        controller: _geoCtrl,
        hint: AppStrings.t(context, 'Latitude, Longitude'),
        onChanged: _updateGeoFromText,
      ),
    ])));
    sections.add(const SizedBox(height: 24));

    // ── Step 6: Photos ────────────────────────────────
    sections.add(_sectionTitle((step++).toString(), AppStrings.t(context, 'Evidence Photos')));
    sections.add(const SizedBox(height: 12));
    sections.add(_card(child: _photoSection()));
    sections.add(const SizedBox(height: 28));

    // ── Submit ────────────────────────────────────────
    sections.add(SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _submitting
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(_isPreviewing ? AppStrings.t(context, 'Confirm & Submit') : AppStrings.t(context, 'Preview Complaint'),
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    ));

    return sections;
  }

  // ── Top nav ───────────────────────────────────────────────────────────────
  Widget _topNav(String emoji, Color bg, String name) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 8, right: 16, bottom: 12),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
          Text(AppStrings.t(context, 'Submit a complaint'), style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
        ]),
      ]),
    );
  }

  // ── Section title with step number ───────────────────────────────────────
  Widget _sectionTitle(String step, String title) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
        child: Center(child: Text(step,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
      ),
      const SizedBox(width: 10),
      Flexible(child: Text(title,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark))),
    ]);
  }

  // ── Subcategory grid ──────────────────────────────────────────────────────
  Widget _subcategoryGrid() {
    if (_subcategories.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _subcategories.map((sub) {
        final selected = _selectedSub?['id'] == sub['id'];
        return GestureDetector(
          onTap: () => _selectSub(sub),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _primary : _borderColor,
                width: selected ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? _primary.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: selected ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(sub['name'] as String,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _textDark)),
          ),
        );
      }).toList(),
    );
  }

  // ── Dynamic fields ────────────────────────────────────────────────────────
  List<Widget> _buildDynamicFields(List<Map<String, dynamic>> fields) {
    if (fields.isEmpty) return [
      Text(AppStrings.t(context, 'No additional fields required.'),
          style: GoogleFonts.inter(fontSize: 13, color: _textMuted)),
    ];

    final widgets = <Widget>[];
    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      final id = f['id'] as int;
      final label = f['label'] as String;
      final type = f['field_type'] as String;
      final required = f['is_required'] == true;

      if (i > 0) widgets.add(const SizedBox(height: 16));
      widgets.add(_label(label, required: required));
      widgets.add(const SizedBox(height: 6));

      if (type == 'select') {
        List<String> options = [];
        try {
          if (f['options'] is List) {
            options = (f['options'] as List).map((o) => o.toString()).toList();
          } else if (f['options_list'] is List) {
            options = (f['options_list'] as List).map((o) => o.toString()).toList();
          } else if (f['options'] is String && (f['options'] as String).isNotEmpty) {
            options = (f['options'] as String).split(',').map((e) => e.trim()).toList();
          }
        } catch (e) {
          debugPrint('Error parsing options for field $label: $e');
        }

        widgets.add(_dropdownField(
          hint: '${AppStrings.t(context, 'Select')} $label',
          value: _dynDropdown[id],
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o, style: GoogleFonts.inter(fontSize: 14, color: _textDark)),
          )).toList(),
          onChanged: (v) => setState(() => _dynDropdown[id] = v),
          validator: required ? (v) => (v == null || v.isEmpty) ? '$label ${AppStrings.t(context, 'is required')}' : null : null,
        ));
      } else if (type == 'date' || type == 'datetime-local') {
        widgets.add(_dateField(
          id: id,
          label: label,
          withTime: type == 'datetime-local',
          required: required,
        ));
      } else if (type == 'textarea') {
        widgets.add(_textField(
          controller: _dynCtrl[id]!,
          hint: '${AppStrings.t(context, 'Enter')} $label',
          maxLines: 3,
          validator: required ? (v) => (v ?? '').trim().isEmpty ? '$label ${AppStrings.t(context, 'is required')}' : null : null,
        ));
      } else {
        widgets.add(_textField(
          controller: _dynCtrl[id]!,
          hint: '${AppStrings.t(context, 'Enter')} $label',
          keyboard: type == 'number' ? TextInputType.number
              : type == 'email' ? TextInputType.emailAddress
              : type == 'tel' ? TextInputType.phone
              : TextInputType.text,
          validator: required ? (v) => (v ?? '').trim().isEmpty ? '$label ${AppStrings.t(context, 'is required')}' : null : null,
        ));
      }
    }
    return widgets;
  }

  // ── Date field ────────────────────────────────────────────────────────────
  Widget _dateField({required int id, required String label, required bool withTime, required bool required}) {
    final value = _dynDate[id];
    return GestureDetector(
      onTap: () => _pickDate(id, withTime),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Row(children: [
          Icon(withTime ? Icons.access_time_rounded : Icons.calendar_today_rounded,
              size: 18, color: value != null ? _primary : _textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(
            value ?? (withTime ? AppStrings.t(context, 'Select date & time') : AppStrings.t(context, 'Select date')),
            style: GoogleFonts.inter(
                fontSize: 14,
                color: value != null ? _textDark : _textMuted),
          )),
          const Icon(Icons.arrow_drop_down, color: _textMuted),
        ]),
      ),
    );
  }

  // ── Photo section ─────────────────────────────────────────────────────────
  Widget _photoSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_images.isNotEmpty) ...[
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            itemBuilder: (_, i) => Stack(children: [
              Container(
                width: 90, height: 90,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: FileImage(_images[i]), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4, right: 14,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(i)),
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Row(children: [
        _photoBtn(Icons.camera_alt_rounded, AppStrings.t(context, 'Camera'), () => _pickImage(ImageSource.camera)),
        const SizedBox(width: 10),
        _photoBtn(Icons.photo_library_rounded, AppStrings.t(context, 'Gallery'), () => _pickImage(ImageSource.gallery)),
      ]),
      const SizedBox(height: 4),
      Text(AppStrings.t(context, 'Add photos as evidence (optional)'),
          style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
    ]);
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
        ]),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _label(String text, {bool required = true}) {
    return Row(children: [
      Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
      if (required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
    ]);
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboard,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: _textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
      ),
    );
  }

  Widget _prioritySelector() {
    return Row(children: [
      _priorityBtn('high', AppStrings.t(context, 'High'), Colors.red, const Color(0xFFFEF2F2)),
      const SizedBox(width: 10),
      _priorityBtn('medium', AppStrings.t(context, 'Medium'), Colors.orange, const Color(0xFFFFF7ED)),
      const SizedBox(width: 10),
      _priorityBtn('normal', AppStrings.t(context, 'Normal'), Colors.green, const Color(0xFFF0FDF4)),
    ]);
  }

  Widget _priorityBtn(String key, String label, Color color, Color bg) {
    final selected = _priority == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = key),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? color : bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : color.withOpacity(0.2), width: 1.5),
            boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : color)),
          ),
        ),
      ),
    );
  }

  Widget _locationButtons() {
    return Row(children: [
      Expanded(
        child: _smallBtn(Icons.my_location_rounded, AppStrings.t(context, 'Detect Location'), _detectLocation),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _smallBtn(Icons.map_outlined, AppStrings.t(context, 'Select on Map'), _selectOnMap),
      ),
    ]);
  }

  Widget _smallBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Darker UI
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _dropdownField({
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: _textMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      isExpanded: true,
    );
  }
}
