import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/complaint_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

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
  static const _border = Color(0xFFe2e8f0);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Dynamic field controllers keyed by field id
  final Map<int, TextEditingController> _dynCtrl = {};
  final Map<int, String?> _dynDropdown = {};

  List<Map<String, dynamic>> _subcategories = [];
  List<Map<String, dynamic>> _catFields = [];   // category-level fields
  List<Map<String, dynamic>> _subFields = [];   // subcategory-level fields
  String? _selectedSubcategoryId;
  bool _loadingMeta = true;

  final List<File> _images = [];
  bool _submitting = false;
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
    for (final c in _dynCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    try {
      final res = await ApiService.get(
        ApiConfig.subcategories(widget.categoryKey ?? 'other'),
        includeAuth: false,
      );
      if (res['success'] == true) {
        final subs = (res['subcategories'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final catF = (res['category_fields'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _initControllers(catF);
        setState(() { _subcategories = subs; _catFields = catF; });
      }
    } catch (_) {}
    setState(() => _loadingMeta = false);
  }

  void _initControllers(List<Map<String, dynamic>> fields) {
    for (final f in fields) {
      final id = f['id'] as int;
      if (f['field_type'] == 'select') {
        _dynDropdown[id] = null;
      } else {
        _dynCtrl[id] = TextEditingController();
      }
    }
  }

  void _onSubcategoryChanged(String? subId) {
    // Clear old sub-level controllers
    for (final f in _subFields) {
      final id = f['id'] as int;
      _dynCtrl.remove(id)?.dispose();
      _dynDropdown.remove(id);
    }
    setState(() { _selectedSubcategoryId = subId; _subFields = []; });
    if (subId == null) return;

    // Find subcategory fields from already-loaded subcategory data
    final sub = _subcategories.firstWhere(
      (s) => s['id'].toString() == subId,
      orElse: () => {},
    );
    final fields = (sub['dynamic_fields'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _initControllers(fields);
    setState(() => _subFields = fields);
  }

  Future<void> _detectLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      _lat = pos.latitude;
      _lng = pos.longitude;
      final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
      if (mounted && (addr['address'] ?? '').isNotEmpty) {
        _addressCtrl.text = addr['address']!;
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) setState(() => _images.add(File(picked.path)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    // Build dynamic field responses
    final fieldResponses = <Map<String, dynamic>>[];
    for (final f in [..._catFields, ..._subFields]) {
      final id = f['id'] as int;
      String value = '';
      if (f['field_type'] == 'select') {
        value = _dynDropdown[id] ?? '';
      } else {
        value = _dynCtrl[id]?.text ?? '';
      }
      if (value.isNotEmpty) fieldResponses.add({'field_id': id, 'value': value});
    }

    final data = <String, String>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'latitude': (_lat ?? 20.5937).toString(),
      'longitude': (_lng ?? 78.9629).toString(),
      'complaint_type': widget.categoryKey ?? 'other',
      if (_selectedSubcategoryId != null) 'subcategory': _selectedSubcategoryId!,
    };

    final provider = Provider.of<ComplaintProvider>(context, listen: false);
    final success = await provider.createComplaint(data, _images);
    setState(() => _submitting = false);

    if (!mounted) return;
    if (success) {
      await provider.refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint submitted successfully!'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      Navigator.popUntil(context, (r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to submit'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.categoryKey ?? 'other';
    final emoji = _emojiMap[key] ?? '📋';
    final bg = _bgMap[key] ?? const Color(0xFFF8FAFC);
    final name = widget.categoryName ?? 'Complaint';

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
              Text(name,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
              Text('Submit a complaint',
                  style: GoogleFonts.inter(fontSize: 11, color: _textMuted)),
            ]),
          ]),
        ),

        Expanded(
          child: _loadingMeta
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Subcategory dropdown ──────────────────────────
                      if (_subcategories.isNotEmpty) ...[
                        _label('Subcategory', required: false),
                        const SizedBox(height: 6),
                        _dropdownField(
                          hint: 'Select subcategory (optional)',
                          value: _selectedSubcategoryId,
                          items: _subcategories.map((s) => DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(s['name'] as String,
                                style: GoogleFonts.inter(fontSize: 14, color: _textDark)),
                          )).toList(),
                          onChanged: _onSubcategoryChanged,
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── Category-level dynamic fields ─────────────────
                      ..._buildDynamicFields(_catFields),

                      // ── Subcategory-level dynamic fields ──────────────
                      ..._buildDynamicFields(_subFields),

                      // ── Title ─────────────────────────────────────────
                      _label('Complaint Title'),
                      const SizedBox(height: 6),
                      _textField(
                        controller: _titleCtrl,
                        hint: 'Brief title of your complaint',
                        validator: (v) => (v ?? '').isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 18),

                      // ── Description ───────────────────────────────────
                      _label('Description'),
                      const SizedBox(height: 6),
                      _textField(
                        controller: _descCtrl,
                        hint: 'Describe the issue in detail...',
                        maxLines: 4,
                        validator: (v) => (v ?? '').isEmpty ? 'Description is required' : null,
                      ),
                      const SizedBox(height: 18),

                      // ── Address ───────────────────────────────────────
                      _label('Location / Address'),
                      const SizedBox(height: 6),
                      _textField(
                        controller: _addressCtrl,
                        hint: 'Address of the issue',
                        maxLines: 2,
                        suffix: IconButton(
                          icon: const Icon(Icons.my_location_rounded, color: _primary, size: 20),
                          onPressed: _detectLocation,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Photos ────────────────────────────────────────
                      _label('Evidence Photos', required: false),
                      const SizedBox(height: 8),
                      _photoSection(),
                      const SizedBox(height: 28),

                      // ── Submit button ─────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _submitting
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text('Submit Complaint',
                                  style: GoogleFonts.poppins(
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                ),
        ),
      ]),
    );
  }

  // ── Dynamic fields builder ──────────────────────────────────────────────
  List<Widget> _buildDynamicFields(List<Map<String, dynamic>> fields) {
    if (fields.isEmpty) return [];
    final widgets = <Widget>[];
    for (final f in fields) {
      final id = f['id'] as int;
      final label = f['label'] as String;
      final type = f['field_type'] as String;
      final required = f['is_required'] == true;

      widgets.add(_label(label, required: required));
      widgets.add(const SizedBox(height: 6));

      if (type == 'select') {
        final options = ((f['options_list'] as List?) ?? [])
            .map((o) => o.toString())
            .toList();
        widgets.add(_dropdownField(
          hint: 'Select $label',
          value: _dynDropdown[id],
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o, style: GoogleFonts.inter(fontSize: 14, color: _textDark)),
          )).toList(),
          onChanged: (v) => setState(() => _dynDropdown[id] = v),
          validator: required ? (v) => (v == null || v.isEmpty) ? '$label is required' : null : null,
        ));
      } else if (type == 'textarea') {
        widgets.add(_textField(
          controller: _dynCtrl[id]!,
          hint: 'Enter $label',
          maxLines: 3,
          validator: required ? (v) => (v ?? '').isEmpty ? '$label is required' : null : null,
        ));
      } else {
        widgets.add(_textField(
          controller: _dynCtrl[id]!,
          hint: 'Enter $label',
          keyboardType: type == 'number' ? TextInputType.number
              : type == 'email' ? TextInputType.emailAddress
              : type == 'tel' ? TextInputType.phone
              : TextInputType.text,
          validator: required ? (v) => (v ?? '').isEmpty ? '$label is required' : null : null,
        ));
      }
      widgets.add(const SizedBox(height: 18));
    }
    return widgets;
  }

  // ── Photo section ───────────────────────────────────────────────────────
  Widget _photoSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_images.isNotEmpty)
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
                  image: DecorationImage(
                      image: FileImage(_images[i]), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4, right: 14,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(i)),
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ]),
          ),
        ),
      if (_images.isNotEmpty) const SizedBox(height: 10),
      Row(children: [
        _photoBtn(Icons.camera_alt_rounded, 'Camera', () => _pickImage(ImageSource.camera)),
        const SizedBox(width: 10),
        _photoBtn(Icons.photo_library_rounded, 'Gallery', () => _pickImage(ImageSource.gallery)),
      ]),
    ]);
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
        ]),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────
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
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: _textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
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
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2)),
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      isExpanded: true,
    );
  }
}
