import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();

  String? _selectedState;
  String? _selectedCity;
  List<String> _states = [];
  Map<String, List<String>> _citiesByState = {};
  double? _lat, _lng;
  bool _locationSet = false;
  bool _isLoading = false;
  bool _detectingLocation = false;
  bool _loadingStates = true;

  late AnimationController _ac;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
    _fetchStatesCities();
  }

  Future<void> _fetchStatesCities() async {
    final result = await ApiService.get(ApiConfig.statesCities, includeAuth: false);
    if (mounted && result['success'] == true) {
      final rawCities = result['cities_by_state'] as Map<String, dynamic>;
      setState(() {
        _states = List<String>.from(result['states'] ?? []);
        _citiesByState = rawCities.map((k, v) => MapEntry(k, List<String>.from(v)));
        _loadingStates = false;
      });
    } else if (mounted) {
      setState(() => _loadingStates = false);
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _mobileCtrl.dispose();
    _emailCtrl.dispose(); _pincodeCtrl.dispose(); _addressCtrl.dispose(); _aadhaarCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationSet = true;
        _detectingLocation = false;
        if (_addressCtrl.text.isEmpty && addr['address']!.isNotEmpty) {
          _addressCtrl.text = addr['address']!;
        }
      });
    } else {
      setState(() => _detectingLocation = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get location. Please try again.')));
    }
  }

  Future<void> _register() async {
    if (_firstNameCtrl.text.isEmpty || _lastNameCtrl.text.isEmpty ||
        _mobileCtrl.text.isEmpty || _emailCtrl.text.isEmpty ||
        _pincodeCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register({
      'name': '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim(),
      'mobile_no': _mobileCtrl.text,
      'email': _emailCtrl.text,
      'pincode': _pincodeCtrl.text,
      'state': _selectedState ?? '',
      'district': _selectedCity ?? '',
      'address': _addressCtrl.text,
      'aadhaar': _aadhaarCtrl.text,
      'latitude': _lat?.toString() ?? '',
      'longitude': _lng?.toString() ?? '',
    });
    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Registration failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0f172a)),
              ),
            ),
            const SizedBox(height: 24),

            // Logo + title
            Center(
              child: Column(children: [
                Image.asset('assets/images/logo.png', height: 64),
                const SizedBox(height: 8),
                Text('COMPLAINT MANAGEMENT SYSTEM', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5), letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text('Create Account', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                const SizedBox(height: 4),
                Text('Join JanHelp to report city issues', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
              ]),
            ),
            const SizedBox(height: 28),

            // First + Last name row
            Row(children: [
              Expanded(child: _field(_firstNameCtrl, 'First Name', Icons.person_outline, TextInputType.name)),
              const SizedBox(width: 12),
              Expanded(child: _field(_lastNameCtrl, 'Last Name', Icons.person_outline, TextInputType.name)),
            ]),
            const SizedBox(height: 14),
            _field(_mobileCtrl, 'Mobile Number', Icons.phone_outlined, TextInputType.phone),
            const SizedBox(height: 14),
            _field(_emailCtrl, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
            const SizedBox(height: 14),
            _field(_pincodeCtrl, 'Pincode', Icons.location_on_outlined, TextInputType.number),
            const SizedBox(height: 14),

            // State + City row
            Row(children: [
              Expanded(child: _loadingStates
                ? _loadingDropdown('Select State')
                : _dropdown('Select State', _states, _selectedState, (v) => setState(() { _selectedState = v; _selectedCity = null; }))),
              const SizedBox(width: 12),
              Expanded(child: _loadingStates
                ? _loadingDropdown('Select City')
                : _dropdown(
                    'Select City',
                    (_selectedState != null ? (_citiesByState[_selectedState!] ?? []) : []),
                    _selectedCity,
                    _selectedState == null ? null : (v) => setState(() => _selectedCity = v),
                  )),
            ]),
            const SizedBox(height: 14),

            // Address textarea
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
              child: TextField(
                controller: _addressCtrl, maxLines: 3,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
                decoration: InputDecoration(hintText: 'Address', hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)), border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
              ),
            ),
            const SizedBox(height: 14),
            _field(_aadhaarCtrl, 'Aadhaar Number (Optional)', Icons.credit_card_outlined, TextInputType.number),
            const SizedBox(height: 20),

            // Location section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFe2e8f0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.my_location, size: 16, color: Color(0xFF1E66F5)),
                  const SizedBox(width: 8),
                  Text('GPS Location', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _detectingLocation ? null : _detectLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _locationSet ? const Color(0xFFdbeafe) : const Color(0xFF1E66F5).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _locationSet ? const Color(0xFF93c5fd) : const Color(0xFF1E66F5).withOpacity(0.2)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _detectingLocation
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5)))
                            : Icon(_locationSet ? Icons.check_circle_rounded : Icons.location_searching_rounded, size: 16, color: _locationSet ? const Color(0xFF1e40af) : const Color(0xFF1E66F5)),
                        const SizedBox(width: 8),
                        Text(
                          _detectingLocation ? 'Detecting...' : (_locationSet ? 'Location Set ✓' : 'Use Current Location'),
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _locationSet ? const Color(0xFF1e40af) : const Color(0xFF1E66F5)),
                        ),
                      ]),
                    ),
                  ),
                ),
                if (_locationSet && _lat != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0x1A1E66F5), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.location_pin, size: 14, color: Color(0xFF1E66F5)),
                      const SizedBox(width: 6),
                      Text('Lat: ${_lat!.toStringAsFixed(6)}, Lng: ${_lng!.toStringAsFixed(6)}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0f172a))),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),

            // Register button
            SizedBox(width: double.infinity, child: GestureDetector(
              onTap: _isLoading ? null : _register,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF2ECC71)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0x4D1E66F5), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Center(child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('REGISTER NOW', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ]),
                ),
              ),
            )),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFe2e8f0)),
            const SizedBox(height: 16),

            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(text: TextSpan(
                  text: 'Already have an account? ',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)),
                  children: [TextSpan(text: 'Login', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E66F5), fontWeight: FontWeight.w700))],
                )),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _loadingDropdown(String hint) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5))),
        const SizedBox(width: 10),
        Text(hint, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, TextInputType type) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      child: TextField(
        controller: c, keyboardType: type,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)), prefixIcon: Icon(icon, color: const Color(0xFF64748b), size: 18), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      ),
    );
  }

  Widget _dropdown(String hint, List<String> items, String? value, ValueChanged<String?>? onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: onChanged == null ? const Color(0xFFF1F5F9) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748b), size: 18),
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
