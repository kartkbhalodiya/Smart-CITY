import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
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

  final _cityCtrl = TextEditingController();
  String? _selectedState;
  double? _lat, _lng;
  bool _locationSet = false;
  bool _isLoading = false;
  bool _detectingLocation = false;

  late AnimationController _ac;
  late Animation<Offset> _slide;

  // Basic India states list
  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Delhi', 'Jammu & Kashmir', 'Ladakh',
  ];

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _mobileCtrl.dispose();
    _emailCtrl.dispose(); _pincodeCtrl.dispose(); _addressCtrl.dispose(); _aadhaarCtrl.dispose(); _cityCtrl.dispose();
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
      'district': _cityCtrl.text,
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
      body: Stack(children: [
        Image.network(
          'https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            )),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(color: Colors.black.withOpacity(0.25)),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SlideTransition(
                position: _slide,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: const Color(0x261E66F5), blurRadius: 50, offset: const Offset(0, 20))],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Logo
                    Image.network('https://res.cloudinary.com/dk1q50evg/image/upload/logo',
                      height: 56, errorBuilder: (_, __, ___) => const Icon(Icons.location_city, size: 56, color: Color(0xFF1E66F5))),
                    const SizedBox(height: 4),
                    Text('COMPLAINT MANAGEMENT SYSTEM', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5), letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text('Create Account', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                    const SizedBox(height: 20),

                    // First + Last name row
                    Row(children: [
                      Expanded(child: _field(_firstNameCtrl, 'First Name', Icons.person_outline, TextInputType.name)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_lastNameCtrl, 'Last Name', Icons.person_outline, TextInputType.name)),
                    ]),
                    const SizedBox(height: 12),
                    _field(_mobileCtrl, 'Mobile Number', Icons.phone_outlined, TextInputType.phone),
                    const SizedBox(height: 12),
                    _field(_emailCtrl, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _field(_pincodeCtrl, 'Pincode', Icons.location_on_outlined, TextInputType.number),
                    const SizedBox(height: 12),

                    // State + City row
                    Row(children: [
                      Expanded(child: _dropdown('Select State', _states, _selectedState, (v) => setState(() { _selectedState = v; _cityCtrl.clear(); }))),
                      const SizedBox(width: 12),
                      Expanded(child: _cityField()),
                    ]),
                    const SizedBox(height: 12),

                    // Address textarea
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
                      child: TextField(
                        controller: _addressCtrl, maxLines: 3,
                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
                        decoration: InputDecoration(hintText: 'Address', hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)), border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(_aadhaarCtrl, 'Aadhaar Number (Optional)', Icons.credit_card_outlined, TextInputType.number),
                    const SizedBox(height: 16),

                    // Location section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.my_location, size: 14, color: Color(0xFF0f172a)),
                          const SizedBox(width: 6),
                          Text('Location (GPS)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
                        ]),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _detectingLocation ? null : _detectLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: _locationSet ? const Color(0xFFdbeafe) : const Color(0xFFe5e7eb),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                _detectingLocation
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5)))
                                    : Icon(_locationSet ? Icons.check : Icons.location_searching, size: 14, color: _locationSet ? const Color(0xFF1e40af) : const Color(0xFF374151)),
                                const SizedBox(width: 6),
                                Text(
                                  _detectingLocation ? 'Detecting...' : (_locationSet ? 'Location Set ✓' : 'Use Current Location'),
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _locationSet ? const Color(0xFF1e40af) : const Color(0xFF374151)),
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
                    const SizedBox(height: 20),

                    // Register button
                    SizedBox(width: double.infinity, child: GestureDetector(
                      onTap: _isLoading ? null : _register,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF2ECC71), Color(0xFF764ba2)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0x4D1E66F5), blurRadius: 16, offset: const Offset(0, 8))],
                        ),
                        child: Center(child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.person_add_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text('REGISTER NOW', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                            ]),
                        ),
                      ),
                    )),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0x0D000000)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: RichText(text: TextSpan(
                        text: 'Already have an account? ',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b)),
                        children: [TextSpan(text: 'Login', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E66F5), fontWeight: FontWeight.w600))],
                      )),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.trackComplaints),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.search, size: 14, color: Color(0xFF0f172a)),
                          const SizedBox(width: 6),
                          Text('Track Complaint as Guest', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _cityField() {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      child: TextField(
        controller: _cityCtrl, keyboardType: TextInputType.text,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(hintText: 'City', hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)), prefixIcon: const Icon(Icons.location_city_outlined, color: Color(0xFF64748b), size: 18), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      ),
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

  Widget _dropdown(String hint, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
          isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748b), size: 18),
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
