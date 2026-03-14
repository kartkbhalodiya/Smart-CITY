import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import 'map_picker_screen.dart';

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

  final _otpCtrl = TextEditingController();

  String? _selectedState, _selectedCity;
  List<String> _states = [];
  Map<String, List<String>> _citiesByState = {};
  double? _lat, _lng;
  bool _locationSet = false, _isLoading = false, _detectingLocation = false, _loadingStates = true, _openingMap = false;

  // Email OTP verification
  bool _sendingOtp = false, _otpSent = false, _verifyingOtp = false, _emailVerified = false;
  String? _otpError;

  late AnimationController _ac;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _primary = Color(0xFF1E66F5);
  static const _textDark = Color(0xFF0f172a);
  static const _textMuted = Color(0xFF64748b);
  static const _borderColor = Color(0xFFe2e8f0);

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
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
    _emailCtrl.dispose(); _pincodeCtrl.dispose(); _addressCtrl.dispose(); _aadhaarCtrl.dispose(); _otpCtrl.dispose();
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

  Future<void> _openMapPicker() async {
    setState(() => _openingMap = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _openingMap = false);
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    if (result != null && mounted) {
      final addr = await LocationService.getAddressFromCoordinates(result.latitude, result.longitude);
      setState(() {
        _lat = result.latitude; _lng = result.longitude;
        _locationSet = true;
        if (addr['address']!.isNotEmpty) _addressCtrl.text = addr['address']!;
      });
    }
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email first')));
      return;
    }
    setState(() { _sendingOtp = true; _otpError = null; });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.sendOtp(email);
    setState(() { _sendingOtp = false; });
    if (success) {
      setState(() { _otpSent = true; _emailVerified = false; _otpCtrl.clear(); });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Failed to send OTP')));
    }
  }

  Future<void> _verifyEmailOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _otpError = 'Enter the 6-digit OTP');
      return;
    }
    setState(() { _verifyingOtp = true; _otpError = null; });
    final result = await ApiService.post(
      ApiConfig.verifyOtp,
      {'email': _emailCtrl.text.trim(), 'otp': otp},
      includeAuth: false,
    );
    setState(() => _verifyingOtp = false);
    if (result['success'] == true) {
      setState(() { _emailVerified = true; _otpSent = false; });
    } else {
      setState(() => _otpError = result['message'] ?? 'Invalid OTP');
    }
  }

  Future<void> _register() async {
    if (_firstNameCtrl.text.isEmpty || _lastNameCtrl.text.isEmpty ||
        _mobileCtrl.text.isEmpty || _emailCtrl.text.isEmpty ||
        _pincodeCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify your email first')));
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
      if (auth.isAuthenticated) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      } else {
        // Registration succeeded but no auto-login — go to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login.')),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Registration failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background image
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Image.network(
                'https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E66F5)),
              ),
            ),
            // Blue gradient overlay (matches website)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x331E66F5),
                    Color(0x26667EEA),
                    Color(0x1A764BA2),
                  ],
                ),
              ),
            ),
            // Backdrop blur overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.transparent),
            ),

            // Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _glassCard(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E66F5).withOpacity(0.15), blurRadius: 50, offset: const Offset(0, 20)),
          BoxShadow(color: const Color(0xFF1E66F5).withOpacity(0.05), blurRadius: 100),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button row
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 18, color: _textDark),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Logo
                Image.asset('assets/images/logo.png', height: 80),
                const SizedBox(height: 8),

                // Brand subtitle
                Text(
                  'COMPLAINT MANAGEMENT SYSTEM',
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: _primary, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),

                // Heading
                Text(
                  'Create Account',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: _textDark),
                ),
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
                _emailFieldWithVerify(),
                if (_otpSent) ...[
                  const SizedBox(height: 10),
                  _otpVerifyBox(),
                ],
                const SizedBox(height: 12),
                _field(_pincodeCtrl, 'Pincode', Icons.location_on_outlined, TextInputType.number),
                const SizedBox(height: 12),

                // State + City row
                Row(children: [
                  Expanded(child: _loadingStates
                    ? _loadingDropdown('Select State')
                    : _dropdown('Select State', _states, _selectedState,
                        (v) => setState(() { _selectedState = v; _selectedCity = null; }))),
                  const SizedBox(width: 12),
                  Expanded(child: _loadingStates
                    ? _loadingDropdown('Select City')
                    : _dropdown(
                        'Select City',
                        _selectedState != null ? (_citiesByState[_selectedState!] ?? []) : [],
                        _selectedCity,
                        _selectedState == null ? null : (v) => setState(() => _selectedCity = v),
                      )),
                ]),
                const SizedBox(height: 12),

                // Address
                _addressField(),
                const SizedBox(height: 12),

                // Aadhaar
                _field(_aadhaarCtrl, 'Aadhaar Number (Optional)', Icons.credit_card_outlined, TextInputType.number),
                const SizedBox(height: 14),

                // Location section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '📍 Location (GPS)',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark),
                  ),
                ),
                const SizedBox(height: 10),
                _locationButtons(),
                if (_locationSet && _lat != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.location_pin, size: 14, color: _primary),
                      const SizedBox(width: 6),
                      Text(
                        'Lat: ${_lat!.toStringAsFixed(6)},  Lng: ${_lng!.toStringAsFixed(6)}',
                        style: GoogleFonts.inter(fontSize: 12, color: _textDark),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),

                // Register button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: GestureDetector(
                    onTap: (_isLoading || !_emailVerified) ? null : _register,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _emailVerified
                          ? const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF2ECC71), Color(0xFF764ba2)])
                          : const LinearGradient(colors: [Color(0xFFcbd5e1), Color(0xFFcbd5e1)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _emailVerified
                          ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))]
                          : [],
                      ),
                      child: Center(
                        child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text('REGISTER NOW', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                            ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Footer divider
                Divider(color: Colors.black.withOpacity(0.05)),
                const SizedBox(height: 12),

                // Already have account
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(text: TextSpan(
                    text: 'Already have an account?  ',
                    style: GoogleFonts.inter(fontSize: 12, color: _textMuted),
                    children: [TextSpan(text: 'Login', style: GoogleFonts.inter(fontSize: 12, color: _primary, fontWeight: FontWeight.w600))],
                  )),
                ),
                const SizedBox(height: 10),

                // Guest track link
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.guestTrack),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor, width: 1.5),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.search_rounded, size: 15, color: _textDark),
                      const SizedBox(width: 6),
                      Text('Track Complaint as Guest', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: TextField(
        controller: c, keyboardType: type,
        style: GoogleFonts.inter(fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: _textMuted),
          prefixIcon: Icon(icon, color: _textMuted, size: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _addressField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: TextField(
        controller: _addressCtrl, maxLines: 3,
        style: GoogleFonts.inter(fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Address',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: _textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _dropdown(String hint, List<String> items, String? value, ValueChanged<String?>? onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: onChanged == null ? const Color(0xFFF1F5F9) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: _textMuted)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _textMuted, size: 18),
          style: GoogleFonts.inter(fontSize: 13, color: _textDark),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _loadingDropdown(String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
        const SizedBox(width: 10),
        Text(hint, style: GoogleFonts.inter(fontSize: 13, color: _textMuted)),
      ]),
    );
  }

  Widget _emailFieldWithVerify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email input field
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _emailVerified ? const Color(0xFF22c55e) : _borderColor,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            enabled: !_emailVerified,
            style: GoogleFonts.inter(fontSize: 14, color: _textDark),
            onChanged: (_) {
              if (_emailVerified || _otpSent) {
                setState(() { _emailVerified = false; _otpSent = false; _otpCtrl.clear(); });
              }
            },
            decoration: InputDecoration(
              hintText: 'Email Address',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _textMuted),
              prefixIcon: Icon(
                _emailVerified ? Icons.verified_outlined : Icons.email_outlined,
                color: _emailVerified ? const Color(0xFF22c55e) : _textMuted,
                size: 18,
              ),
              suffixIcon: _emailVerified
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle, color: Color(0xFF22c55e), size: 16),
                      const SizedBox(width: 4),
                      Text('Verified', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF22c55e), fontWeight: FontWeight.w700)),
                    ]),
                  )
                : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
        // Verify / Resend button below the field
        if (!_emailVerified) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _sendingOtp ? null : _sendEmailOtp,
              icon: _sendingOtp
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_otpSent ? Icons.refresh_rounded : Icons.send_rounded, size: 15),
              label: Text(
                _sendingOtp ? 'Sending...' : (_otpSent ? 'Resend OTP' : 'Send Verification OTP'),
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _otpSent ? const Color(0xFF0f172a) : _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _otpVerifyBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFeff6ff),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFbfdbfe), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.mark_email_read_outlined, size: 14, color: Color(0xFF1e40af)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'OTP sent to ${_emailCtrl.text.trim()}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1e40af), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _otpError != null ? Colors.red : _borderColor, width: 1.5),
                  ),
                  child: TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark, letterSpacing: 6),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '------',
                      hintStyle: GoogleFonts.poppins(fontSize: 16, color: _textMuted, letterSpacing: 4),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setState(() => _otpError = null),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _verifyingOtp ? null : _verifyEmailOtp,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _verifyingOtp
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Submit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ]),
            if (_otpError != null) ...[
              const SizedBox(height: 6),
              Text(_otpError!, style: GoogleFonts.inter(fontSize: 11, color: Colors.red)),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _locationButtons() {
    return Row(children: [
      // Use Current Location
      Expanded(
        child: GestureDetector(
          onTap: _detectingLocation ? null : _detectLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: _locationSet ? const Color(0xFFdbeafe) : const Color(0xFFe5e7eb),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _detectingLocation
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))
                : Icon(_locationSet ? Icons.check : Icons.location_searching_rounded, size: 15,
                    color: _locationSet ? const Color(0xFF1e40af) : const Color(0xFF374151)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _detectingLocation ? 'Detecting...' : (_locationSet ? 'Location Set ✓' : 'Use Current'),
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700,
                      color: _locationSet ? const Color(0xFF1e40af) : const Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Pick on Map
      Expanded(
        child: GestureDetector(
          onTap: _openingMap ? null : _openMapPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFdbeafe),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _openingMap
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))
                : const Icon(Icons.map_outlined, size: 15, color: Color(0xFF1e40af)),
              const SizedBox(width: 6),
              Text(
                _openingMap ? 'Opening...' : 'Pick on Map',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1e40af)),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
