import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../l10n/app_strings.dart';
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
  int _resendSeconds = 0;
  Timer? _resendTimer;

  late AnimationController _ac;
  late Animation<Offset> _slideAnim;

  static const _primary = Color(0xFF1E66F5);
  static const _textDark = Color(0xFF0f172a);
  static const _textMuted = Color(0xFF64748b);
  static const _borderColor = Color(0xFFe2e8f0);

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
    _fetchStatesCities();
  }

  Future<void> _fetchStatesCities() async {
    final provider = Provider.of<ComplaintProvider>(context, listen: false);
    await provider.loadStatesCities();
    if (mounted) {
      setState(() {
        _states = provider.states;
        _citiesByState = provider.citiesByState;
        _loadingStates = false;
      });
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _resendTimer?.cancel();
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
        if (addr['pincode']!.isNotEmpty) _pincodeCtrl.text = addr['pincode']!;
        // Auto-select state
        final detectedState = addr['state'] ?? '';
        if (detectedState.isNotEmpty) {
          final matchedState = _states.firstWhere(
            (s) => s.toLowerCase().contains(detectedState.toLowerCase()) ||
                   detectedState.toLowerCase().contains(s.toLowerCase()),
            orElse: () => '',
          );
          if (matchedState.isNotEmpty) {
            _selectedState = matchedState;
            final detectedCity = addr['city'] ?? '';
            if (detectedCity.isNotEmpty) {
              final cities = _citiesByState[matchedState] ?? [];
              final matchedCity = cities.firstWhere(
                (c) => c.toLowerCase().contains(detectedCity.toLowerCase()) ||
                       detectedCity.toLowerCase().contains(c.toLowerCase()),
                orElse: () => '',
              );
              if (matchedCity.isNotEmpty) _selectedCity = matchedCity;
            }
          }
        }
      });
    } else {
      setState(() => _detectingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'Could not get location.'))),
        );
      }
    }
  }

  Future<void> _openMapPicker() async {
    setState(() => _openingMap = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _openingMap = false);
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _lat = result.lat;
        _lng = result.lng;
        _locationSet = true;
        if (result.address.isNotEmpty) _addressCtrl.text = result.address;
        // Auto-fill pincode
        if (result.pincode.isNotEmpty) _pincodeCtrl.text = result.pincode;
        // Auto-select state
        if (result.state.isNotEmpty) {
          final matchedState = _states.firstWhere(
            (s) => s.toLowerCase().contains(result.state.toLowerCase()) ||
                   result.state.toLowerCase().contains(s.toLowerCase()),
            orElse: () => '',
          );
          if (matchedState.isNotEmpty) {
            _selectedState = matchedState;
            // Auto-select city
            if (result.city.isNotEmpty) {
              final cities = _citiesByState[matchedState] ?? [];
              final matchedCity = cities.firstWhere(
                (c) => c.toLowerCase().contains(result.city.toLowerCase()) ||
                       result.city.toLowerCase().contains(c.toLowerCase()),
                orElse: () => '',
              );
              if (matchedCity.isNotEmpty) _selectedCity = matchedCity;
            }
          }
        }
      });
    }
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'Enter a valid email first'))),
      );
      return;
    }
    if (_resendSeconds > 0) return;

    setState(() { _sendingOtp = true; _otpError = null; });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.sendOtp(email);
    setState(() { _sendingOtp = false; });
    if (success) {
      setState(() { _otpSent = true; _emailVerified = false; _otpCtrl.clear(); });
      _startResendTimer();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? AppStrings.t(context, 'Failed to send OTP'))),
      );
    }
  }

  Future<void> _verifyEmailOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _otpError = AppStrings.t(context, 'Enter the 6-digit OTP'));
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
      setState(() => _otpError = result['message'] ?? AppStrings.t(context, 'Invalid OTP'));
    }
  }

  Future<void> _register() async {
    if (_emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'Email is required'))),
      );
      return;
    }
    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'Please verify your email first'))),
      );
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
      _showRegistrationSuccessDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? AppStrings.t(context, 'Registration failed'))),
      );
    }
  }

  void _showRegistrationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 54),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.t(context, 'Registration Successful!'),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${AppStrings.t(context, 'Your account has been created for')} ${_emailCtrl.text.trim()}. ${AppStrings.t(context, 'Please login to continue.')}',
                style: GoogleFonts.inter(fontSize: 13, color: _textMuted, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Close dialog
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(AppStrings.t(context, 'OKAY, LOGIN'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Image.network(
          'https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667eea), Color(0xFF764ba2)]))),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        SafeArea(
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _formContent(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _formContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back button
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
          AppStrings.t(context, 'COMPLAINT MANAGEMENT SYSTEM'),
          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: _primary, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        // Heading
        Text(
          AppStrings.t(context, 'Create Account'),
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: _textDark),
        ),
        const SizedBox(height: 20),
        // First + Last name row
        Row(children: [
          Expanded(child: _field(_firstNameCtrl, AppStrings.t(context, 'First Name (Optional)'), Icons.person_outline, TextInputType.name)),
          const SizedBox(width: 12),
          Expanded(child: _field(_lastNameCtrl, AppStrings.t(context, 'Last Name (Optional)'), Icons.person_outline, TextInputType.name)),
        ]),
        const SizedBox(height: 12),
        _field(_mobileCtrl, AppStrings.t(context, 'Mobile Number (Optional)'), Icons.phone_outlined, TextInputType.phone),
        const SizedBox(height: 12),
        _emailFieldWithVerify(),
        if (_otpSent) ...[
          const SizedBox(height: 10),
          _otpVerifyBox(),
        ],
        const SizedBox(height: 12),
        _field(_pincodeCtrl, AppStrings.t(context, 'Pincode (Optional)'), Icons.location_on_outlined, TextInputType.number),
        const SizedBox(height: 12),
        // State + City row
        Row(children: [
          Expanded(child: _loadingStates
            ? _loadingDropdown(AppStrings.t(context, 'Select State'))
            : _dropdown(AppStrings.t(context, 'Select State (Opt)'), _states, _selectedState,
                (v) => setState(() { _selectedState = v; _selectedCity = null; }))),
          const SizedBox(width: 12),
          Expanded(child: _loadingStates
            ? _loadingDropdown(AppStrings.t(context, 'Select City'))
            : _dropdown(
                AppStrings.t(context, 'Select City (Opt)'),
                _selectedState != null ? (_citiesByState[_selectedState!] ?? []) : [],
                _selectedCity,
                _selectedState == null ? null : (v) => setState(() => _selectedCity = v),
              )),
        ]),
        const SizedBox(height: 12),
        _addressField(),
        const SizedBox(height: 12),
        _field(_aadhaarCtrl, AppStrings.t(context, 'Aadhaar Number (Optional)'), Icons.credit_card_outlined, TextInputType.number),
        const SizedBox(height: 14),
        // Location section
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppStrings.t(context, '📍 Location (GPS)'),
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
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.location_pin, size: 14, color: _primary),
              const SizedBox(width: 6),
              Text(
                '${AppStrings.t(context, 'Lat')}: ${_lat!.toStringAsFixed(6)},  ${AppStrings.t(context, 'Lng')}: ${_lng!.toStringAsFixed(6)}',
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
                  ? [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))]
                  : [],
              ),
              child: Center(
                child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(AppStrings.t(context, 'REGISTER NOW'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: Colors.black.withValues(alpha: 0.08)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: RichText(text: TextSpan(
            text: AppStrings.t(context, 'Already have an account?  '),
            style: GoogleFonts.inter(fontSize: 12, color: _textMuted),
            children: [TextSpan(text: AppStrings.t(context, 'Login'), style: GoogleFonts.inter(fontSize: 12, color: _primary, fontWeight: FontWeight.w600))],
          )),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.guestTrack),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor, width: 1.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.search_rounded, size: 15, color: _textDark),
              const SizedBox(width: 6),
              Text(AppStrings.t(context, 'Track Complaint as Guest'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
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
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: TextField(
        controller: _addressCtrl, maxLines: 3,
        style: GoogleFonts.inter(fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          hintText: AppStrings.t(context, 'Address (Optional)'),
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
        color: onChanged == null ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.9),
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
        color: Colors.white.withValues(alpha: 0.9),
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
            color: Colors.white.withValues(alpha: 0.9),
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
              hintText: AppStrings.t(context, 'Email Address'),
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
                      Text(AppStrings.t(context, 'Verified'), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF22c55e), fontWeight: FontWeight.w700)),
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
              onPressed: (_sendingOtp || _resendSeconds > 0) ? null : _sendEmailOtp,
              icon: _sendingOtp
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_otpSent ? Icons.refresh_rounded : Icons.send_rounded, size: 15),
              label: Text(
                _sendingOtp
                    ? AppStrings.t(context, 'Sending...')
                    : (_otpSent
                        ? (_resendSeconds > 0
                            ? '${AppStrings.t(context, 'Resend in')} ${_resendSeconds}s'
                            : AppStrings.t(context, 'Resend OTP'))
                        : AppStrings.t(context, 'Send Verification OTP')),
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
                  '${AppStrings.t(context, 'OTP sent to')} ${_emailCtrl.text.trim()}',
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
                      : Text(AppStrings.t(context, 'Submit'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _detectingLocation
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))
                : Icon(_locationSet ? Icons.check : Icons.location_searching_rounded, size: 15,
                    color: _locationSet ? const Color(0xFF1e40af) : const Color(0xFF374151)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _detectingLocation
                      ? AppStrings.t(context, 'Detecting...')
                      : (_locationSet
                          ? AppStrings.t(context, 'Location Set ✓')
                          : AppStrings.t(context, 'Use Current')),
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
              boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _openingMap
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))
                : const Icon(Icons.map_outlined, size: 15, color: Color(0xFF1e40af)),
              const SizedBox(width: 6),
              Text(
                _openingMap
                    ? AppStrings.t(context, 'Opening...')
                    : AppStrings.t(context, 'Pick on Map'),
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1e40af)),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
