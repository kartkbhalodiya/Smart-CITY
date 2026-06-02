import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _RegisterScreenState extends State<RegisterScreen> {
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
  bool _locationSet = false,
      _isLoading = false,
      _detectingLocation = false,
      _loadingStates = true,
      _openingMap = false;

  // Email OTP verification
  bool _sendingOtp = false,
      _otpSent = false,
      _verifyingOtp = false,
      _emailVerified = false;
  String? _otpError;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  static const _primary = Color(0xFF111827);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _textDark = Color(0xFF111827);
  static const _textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
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
    _resendTimer?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _pincodeCtrl.dispose();
    _addressCtrl.dispose();
    _aadhaarCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      final addr = await LocationService.getAddressFromCoordinates(
          pos.latitude, pos.longitude);
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationSet = true;
        _detectingLocation = false;
        if (_addressCtrl.text.isEmpty && addr['address']!.isNotEmpty) {
          _addressCtrl.text = addr['address']!;
        }
        if (addr['pincode']!.isNotEmpty) {
          _pincodeCtrl.text = addr['pincode']!;
        }
        // Auto-select state
        final detectedState = addr['state'] ?? '';
        if (detectedState.isNotEmpty) {
          final matchedState = _states.firstWhere(
            (s) =>
                s.toLowerCase().contains(detectedState.toLowerCase()) ||
                detectedState.toLowerCase().contains(s.toLowerCase()),
            orElse: () => '',
          );
          if (matchedState.isNotEmpty) {
            _selectedState = matchedState;
            final detectedCity = addr['city'] ?? '';
            if (detectedCity.isNotEmpty) {
              final cities = _citiesByState[matchedState] ?? [];
              final matchedCity = cities.firstWhere(
                (c) =>
                    c.toLowerCase().contains(detectedCity.toLowerCase()) ||
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
          SnackBar(
              content: Text(AppStrings.t(context, 'Could not get location.'))),
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
      AppRoutes.smoothRoute<MapPickerResult>(
        const RouteSettings(name: 'register-map-picker'),
        (_) => MapPickerScreen(
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
            (s) =>
                s.toLowerCase().contains(result.state.toLowerCase()) ||
                result.state.toLowerCase().contains(s.toLowerCase()),
            orElse: () => '',
          );
          if (matchedState.isNotEmpty) {
            _selectedState = matchedState;
            // Auto-select city
            if (result.city.isNotEmpty) {
              final cities = _citiesByState[matchedState] ?? [];
              final matchedCity = cities.firstWhere(
                (c) =>
                    c.toLowerCase().contains(result.city.toLowerCase()) ||
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
        SnackBar(
            content: Text(AppStrings.t(context, 'Enter a valid email first'))),
      );
      return;
    }
    if (_resendSeconds > 0) return;

    setState(() {
      _sendingOtp = true;
      _otpError = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.sendOtp(email);
    setState(() {
      _sendingOtp = false;
    });
    if (success) {
      setState(() {
        _otpSent = true;
        _emailVerified = false;
        _otpCtrl.clear();
      });
      _startResendTimer();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                auth.error ?? AppStrings.t(context, 'Failed to send OTP'))),
      );
    }
  }

  Future<void> _verifyEmailOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(
          () => _otpError = AppStrings.t(context, 'Enter the 6-digit OTP'));
      return;
    }
    setState(() {
      _verifyingOtp = true;
      _otpError = null;
    });
    final result = await ApiService.post(
      ApiConfig.verifyOtp,
      {'email': _emailCtrl.text.trim(), 'otp': otp},
      includeAuth: false,
    );
    setState(() => _verifyingOtp = false);
    if (result['success'] == true) {
      setState(() {
        _emailVerified = true;
        _otpSent = false;
      });
    } else {
      setState(() => _otpError =
          result['message'] ?? AppStrings.t(context, 'Invalid OTP'));
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
        SnackBar(
            content:
                Text(AppStrings.t(context, 'Please verify your email first'))),
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
        SnackBar(
            content: Text(
                auth.error ?? AppStrings.t(context, 'Registration failed'))),
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 54),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.t(context, 'Registration Successful!'),
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${AppStrings.t(context, 'Your account has been created for')} ${_emailCtrl.text.trim()}. ${AppStrings.t(context, 'Please login to continue.')}',
                style: GoogleFonts.inter(
                    fontSize: 13, color: _textMuted, height: 1.5),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(AppStrings.t(context, 'OKAY, LOGIN'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: false,
      body: _RegisterBackground(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
              final keyboardLift =
                  bottomInset > 0 ? math.min(bottomInset * 0.06, 20.0) : 0.0;
              final contentWidth =
                  constraints.maxWidth > 560 ? 430.0 : constraints.maxWidth;
              final horizontalPadding = constraints.maxWidth > 560 ? 0.0 : 24.0;
              return Padding(
                padding: EdgeInsets.only(bottom: keyboardLift),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    horizontalPadding,
                    28 + math.min(bottomInset * 0.08, 28.0),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: RepaintBoundary(child: _formContent()),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _formContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _iconButton(
              Icons.arrow_back_rounded, () => Navigator.pop(context)),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            AppStrings.t(context, 'Create Account'),
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 35,
              height: 1.02,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: const Color(0xFF0A0A0A),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.t(context, 'Register your JanHelp citizen profile.'),
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.42,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF7A7F8C),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: _field(
                  _firstNameCtrl,
                  AppStrings.t(context, 'First Name (Optional)'),
                  Icons.person_outline,
                  TextInputType.name)),
          const SizedBox(width: 12),
          Expanded(
              child: _field(
                  _lastNameCtrl,
                  AppStrings.t(context, 'Last Name (Optional)'),
                  Icons.person_outline,
                  TextInputType.name)),
        ]),
        const SizedBox(height: 12),
        _field(_mobileCtrl, AppStrings.t(context, 'Mobile Number (Optional)'),
            Icons.phone_outlined, TextInputType.phone),
        const SizedBox(height: 12),
        _emailFieldWithVerify(),
        if (_otpSent) ...[
          const SizedBox(height: 10),
          _otpVerifyBox(),
        ],
        const SizedBox(height: 12),
        _field(_pincodeCtrl, AppStrings.t(context, 'Pincode (Optional)'),
            Icons.location_on_outlined, TextInputType.number),
        const SizedBox(height: 12),
        // State + City row
        Row(children: [
          Expanded(
              child: _loadingStates
                  ? _loadingDropdown(AppStrings.t(context, 'Select State'))
                  : _dropdown(
                      AppStrings.t(context, 'Select State (Opt)'),
                      _states,
                      _selectedState,
                      (v) => setState(() {
                            _selectedState = v;
                            _selectedCity = null;
                          }))),
          const SizedBox(width: 12),
          Expanded(
              child: _loadingStates
                  ? _loadingDropdown(AppStrings.t(context, 'Select City'))
                  : _dropdown(
                      AppStrings.t(context, 'Select City (Opt)'),
                      _selectedState != null
                          ? (_citiesByState[_selectedState!] ?? [])
                          : [],
                      _selectedCity,
                      _selectedState == null
                          ? null
                          : (v) => setState(() => _selectedCity = v),
                    )),
        ]),
        const SizedBox(height: 12),
        _addressField(),
        const SizedBox(height: 12),
        _field(_aadhaarCtrl, AppStrings.t(context, 'Aadhaar Number (Optional)'),
            Icons.credit_card_outlined, TextInputType.number),
        const SizedBox(height: 14),
        // Location section
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppStrings.t(context, 'Location (GPS)'),
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w800, color: _textDark),
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withValues(alpha: 0.38)),
            ),
            child: Row(children: [
              const Icon(Icons.location_pin, size: 14, color: _green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${AppStrings.t(context, 'Lat')}: ${_lat!.toStringAsFixed(6)},  ${AppStrings.t(context, 'Lng')}: ${_lng!.toStringAsFixed(6)}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        _registerButton(),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: RichText(
              text: TextSpan(
            text: AppStrings.t(context, 'Already have an account?  '),
            style: GoogleFonts.inter(fontSize: 12, color: _textMuted),
            children: [
              TextSpan(
                  text: AppStrings.t(context, 'Login'),
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _primary,
                      fontWeight: FontWeight.w800))
            ],
          )),
        ),
        const SizedBox(height: 10),
        _secondaryAction(
          icon: Icons.search_rounded,
          label: AppStrings.t(context, 'Track Complaint as Guest'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.guestTrack),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: _textDark),
      ),
    );
  }

  Widget _field(
      TextEditingController c, String hint, IconData icon, TextInputType type) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.95), width: 1.35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TextField(
          controller: c,
          keyboardType: type,
          cursorColor: _textDark,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFA3A7B4),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF8B90A0), size: 22),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _addressField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.95), width: 1.35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TextField(
          controller: _addressCtrl,
          maxLines: 3,
          cursorColor: _textDark,
          style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
          decoration: InputDecoration(
            hintText: AppStrings.t(context, 'Address (Optional)'),
            hintStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFA3A7B4)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String hint, List<String> items, String? value,
      ValueChanged<String?>? onChanged) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: onChanged == null ? const Color(0xFFF4F5F8) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.95), width: 1.35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA3A7B4))),
          isExpanded: true,
          borderRadius: BorderRadius.circular(18),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _textDark, size: 21),
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: _textDark),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _loadingDropdown(String hint) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.95), width: 1.35),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Row(children: [
        const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: _textDark)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(hint,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textMuted))),
      ]),
    );
  }

  Widget _emailFieldWithVerify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _emailVerified
                  ? _green.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.95),
              width: _emailVerified ? 1.7 : 1.35,
            ),
            boxShadow: [
              if (_emailVerified)
                BoxShadow(
                  color: _green.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !_emailVerified,
              cursorColor: _textDark,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
              onChanged: (_) {
                if (_emailVerified || _otpSent) {
                  setState(() {
                    _emailVerified = false;
                    _otpSent = false;
                    _otpCtrl.clear();
                  });
                }
              },
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'Email Address'),
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA3A7B4),
                ),
                prefixIcon: Icon(
                  _emailVerified
                      ? Icons.verified_outlined
                      : Icons.email_outlined,
                  color: _emailVerified ? _green : const Color(0xFF8B90A0),
                  size: 22,
                ),
                suffixIcon: _emailVerified
                    ? const Icon(Icons.check_circle_rounded,
                        color: _green, size: 23)
                    : const SizedBox(width: 24),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
        ),
        if (!_emailVerified) ...[
          const SizedBox(height: 8),
          _smallActionButton(
            enabled: !_sendingOtp && _resendSeconds == 0,
            loading: _sendingOtp,
            icon: _otpSent ? Icons.refresh_rounded : Icons.send_rounded,
            label: _sendingOtp
                ? AppStrings.t(context, 'Sending...')
                : (_otpSent
                    ? (_resendSeconds > 0
                        ? '${AppStrings.t(context, 'Resend in')} ${_resendSeconds}s'
                        : AppStrings.t(context, 'Resend OTP'))
                    : AppStrings.t(context, 'Send Verification OTP')),
            onTap: _sendEmailOtp,
          ),
        ] else ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withValues(alpha: 0.38)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: _green),
                const SizedBox(width: 8),
                Text(
                  AppStrings.t(context, 'Verified'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _smallActionButton({
    required bool enabled,
    required bool loading,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: enabled ? (_) => HapticFeedback.selectionClick() : null,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.62,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: loading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: Colors.white, size: 17),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _registerButton() {
    final enabled = _emailVerified && !_isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => HapticFeedback.selectionClick() : null,
      onTap: enabled ? _register : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.62,
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 21,
                                width: 21,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(
                                AppStrings.t(context, 'REGISTER NOW'),
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const Positioned(
                        right: 10,
                        top: 8,
                        child: _ArrowCircle(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.92),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.055),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: _textDark),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otpVerifyBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.95), width: 1.35),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.mark_email_read_outlined,
                  size: 16, color: _textDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${AppStrings.t(context, 'OTP sent to')} ${_emailCtrl.text.trim()}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _textMuted,
                      fontWeight: FontWeight.w700),
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
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color:
                            _otpError != null ? _red : const Color(0xFFE5E7EB),
                        width: 1.5),
                  ),
                  child: TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        letterSpacing: 6),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '------',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 16, color: _textMuted, letterSpacing: 4),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: _verifyingOtp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(AppStrings.t(context, 'Submit'),
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ),
            ]),
            if (_otpError != null) ...[
              const SizedBox(height: 6),
              Text(_otpError!,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _red)),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _locationButtons() {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: _detectingLocation ? null : _detectLocation,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _locationSet ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _locationSet
                      ? _green.withValues(alpha: 0.42)
                      : Colors.white.withValues(alpha: 0.95)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _detectingLocation
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _textDark))
                  : Icon(
                      _locationSet
                          ? Icons.check
                          : Icons.location_searching_rounded,
                      size: 15,
                      color: _locationSet ? _green : _textDark),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _detectingLocation
                      ? AppStrings.t(context, 'Detecting...')
                      : (_locationSet
                          ? AppStrings.t(context, 'Location Set')
                          : AppStrings.t(context, 'Use Current')),
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _locationSet ? _green : _textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: GestureDetector(
          onTap: _openingMap ? null : _openMapPicker,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _openingMap
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _textDark))
                  : const Icon(Icons.map_outlined, size: 15, color: _textDark),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _openingMap
                      ? AppStrings.t(context, 'Opening...')
                      : AppStrings.t(context, 'Pick on Map'),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textDark),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _ArrowCircle extends StatelessWidget {
  const _ArrowCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: Colors.white,
        size: 21,
      ),
    );
  }
}

class _RegisterBackground extends StatelessWidget {
  final Widget child;

  const _RegisterBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF6F7FB),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8F8FA),
                  Color(0xFFF4F5F8),
                ],
                stops: [0.0, 0.40, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
