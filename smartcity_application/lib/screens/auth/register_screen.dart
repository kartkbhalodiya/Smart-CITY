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

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();

  String? _selectedState, _selectedCity;
  List<String> _states = [];
  Map<String, List<String>> _citiesByState = {};
  double? _lat, _lng;
  bool _locationSet = false, _isLoading = false, _detectingLocation = false, _loadingStates = true;

  late AnimationController _fadeCtrl, _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _blue = Color(0xFF1E66F5);
  static const _darkBlue = Color(0xFF0D47A1);
  static const _green = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
    _slideCtrl.forward();
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
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
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
        _lat = pos.latitude; _lng = pos.longitude;
        _locationSet = true; _detectingLocation = false;
        if (_addressCtrl.text.isEmpty && addr['address']!.isNotEmpty) _addressCtrl.text = addr['address']!;
      });
    } else {
      setState(() => _detectingLocation = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get location.')));
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
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1E66F5), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative circles
          Positioned(top: -60, right: -60, child: _circle(200, Colors.white.withOpacity(0.06))),
          Positioned(top: 80, left: -40, child: _circle(120, Colors.white.withOpacity(0.05))),
          Positioned(bottom: 100, right: -30, child: _circle(160, Colors.white.withOpacity(0.05))),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Create Account', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text('Join JanHelp today', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                        ]),
                        const Spacer(),
                        Image.asset('assets/images/logo.png', height: 44),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form card
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _sectionLabel('Personal Info', Icons.person_rounded),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _field(_firstNameCtrl, 'First Name', Icons.badge_outlined, TextInputType.name)),
                              const SizedBox(width: 12),
                              Expanded(child: _field(_lastNameCtrl, 'Last Name', Icons.badge_outlined, TextInputType.name)),
                            ]),
                            const SizedBox(height: 12),
                            _field(_mobileCtrl, 'Mobile Number', Icons.phone_rounded, TextInputType.phone),
                            const SizedBox(height: 12),
                            _field(_emailCtrl, 'Email Address', Icons.email_rounded, TextInputType.emailAddress),
                            const SizedBox(height: 24),

                            _sectionLabel('Location Details', Icons.location_on_rounded),
                            const SizedBox(height: 12),
                            _field(_pincodeCtrl, 'Pincode', Icons.pin_drop_outlined, TextInputType.number),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _loadingStates
                                ? _loadingDropdown('State')
                                : _dropdown('State', _states, _selectedState,
                                    (v) => setState(() { _selectedState = v; _selectedCity = null; }))),
                              const SizedBox(width: 12),
                              Expanded(child: _loadingStates
                                ? _loadingDropdown('City')
                                : _dropdown(
                                    'City',
                                    _selectedState != null ? (_citiesByState[_selectedState!] ?? []) : [],
                                    _selectedCity,
                                    _selectedState == null ? null : (v) => setState(() => _selectedCity = v),
                                  )),
                            ]),
                            const SizedBox(height: 12),
                            _addressField(),
                            const SizedBox(height: 24),

                            _sectionLabel('Identity & GPS', Icons.security_rounded),
                            const SizedBox(height: 12),
                            _field(_aadhaarCtrl, 'Aadhaar Number (Optional)', Icons.credit_card_rounded, TextInputType.number),
                            const SizedBox(height: 12),
                            _locationCard(),
                            const SizedBox(height: 28),

                            // Register button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: GestureDetector(
                                onTap: _isLoading ? null : _register,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [_darkBlue, _blue, Color(0xFF42A5F5)]),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20),
                                          const SizedBox(width: 10),
                                          Text('CREATE ACCOUNT', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                                        ]),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: RichText(text: TextSpan(
                                  text: 'Already have an account?  ',
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)),
                                  children: [TextSpan(text: 'Sign In', style: GoogleFonts.inter(fontSize: 13, color: _blue, fontWeight: FontWeight.w700))],
                                )),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _sectionLabel(String label, IconData icon) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: _blue),
    ),
    const SizedBox(width: 10),
    Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
    const SizedBox(width: 10),
    Expanded(child: Divider(color: _blue.withOpacity(0.15), thickness: 1)),
  ]);

  Widget _field(TextEditingController c, String hint, IconData icon, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: c, keyboardType: type,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94a3b8)),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: _blue, size: 16),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _addressField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _addressCtrl, maxLines: 3,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(
          hintText: 'Full Address',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94a3b8)),
          prefixIcon: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.home_rounded, color: _blue, size: 16),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        ),
      ),
    );
  }

  Widget _dropdown(String hint, List<String> items, String? value, ValueChanged<String?>? onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: onChanged == null ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onChanged == null ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94a3b8))),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: onChanged == null ? const Color(0xFFcbd5e1) : _blue, size: 20),
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _loadingDropdown(String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _blue)),
        const SizedBox(width: 10),
        Text(hint, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94a3b8))),
      ]),
    );
  }

  Widget _locationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: _detectingLocation ? null : _detectLocation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: _locationSet
                ? const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF69F0AE)])
                : LinearGradient(colors: [_blue.withOpacity(0.08), _blue.withOpacity(0.04)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _locationSet ? _green.withOpacity(0.4) : _blue.withOpacity(0.2)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _detectingLocation
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                : Icon(
                    _locationSet ? Icons.check_circle_rounded : Icons.my_location_rounded,
                    size: 18,
                    color: _locationSet ? Colors.white : _blue,
                  ),
              const SizedBox(width: 8),
              Text(
                _detectingLocation ? 'Detecting location...' : (_locationSet ? 'Location Captured ✓' : 'Detect My Location'),
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _locationSet ? Colors.white : _blue,
                ),
              ),
            ]),
          ),
        ),
        if (_locationSet && _lat != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.location_pin, size: 14, color: _green),
              const SizedBox(width: 6),
              Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0f172a), fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ]),
    );
  }
}
