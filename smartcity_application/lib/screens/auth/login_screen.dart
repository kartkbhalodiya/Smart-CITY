import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../l10n/app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  late AnimationController _ac;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() { _ac.dispose(); _identifierController.dispose(); _passwordController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Background image
        Image.network(
          'https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667eea), Color(0xFF764ba2)]))),
        ),
        // Blur layer
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
                  constraints: const BoxConstraints(maxWidth: 380),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: const Color(0x261E66F5), blurRadius: 50, offset: const Offset(0, 20))],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _languageSelector(),
                    ),
                    const SizedBox(height: 10),
                    // Logo
                    Image.asset('assets/images/logo.png', height: 60),
                    const SizedBox(height: 6),
                    Text(AppStrings.t(context, 'COMPLAINT MANAGEMENT SYSTEM'), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5), letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text(AppStrings.t(context, 'Login to Your Account'), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                    const SizedBox(height: 20),
                    _inputField(_identifierController, AppStrings.t(context, 'Email / Mobile Number'), Icons.person_outline, TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _passwordField(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                        child: Text(AppStrings.t(context, 'Forgot Password?'), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E66F5), fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E66F5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(AppStrings.t(context, 'LOGIN'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    )),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCD34D), width: 1),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF78350F)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(text: TextSpan(
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF1C1C1C), height: 1.5),
                            children: [
                              TextSpan(text: AppStrings.t(context, 'Citizen? '), style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: AppStrings.t(context, 'Just enter your email and tap ')),
                              TextSpan(text: AppStrings.t(context, 'LOGIN'), style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: AppStrings.t(context, ' — no password needed. An OTP will be sent to your email.')),
                            ],
                          )),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0x0D000000)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _outlineBtn(Icons.person_outline, AppStrings.t(context, 'Guest'), () {
                        Navigator.pushReplacementNamed(context, AppRoutes.guestDashboard);
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: _outlineBtn(Icons.search, AppStrings.t(context, 'Track'), () {
                        Navigator.pushNamed(context, AppRoutes.guestTrack);
                      })),
                    ]),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                      child: RichText(text: TextSpan(
                        text: AppStrings.t(context, "Don't have an account? "),
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b)),
                        children: [TextSpan(text: AppStrings.t(context, 'Register Now'), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E66F5), fontWeight: FontWeight.w600))],
                      )),
                    ),
                    const SizedBox(height: 14),
                    Text(AppStrings.t(context, 'Designed by Kartik Bhalodiya.'), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _inputField(TextEditingController c, String hint, IconData icon, TextInputType type) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      child: TextField(
        controller: c, keyboardType: type,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)), prefixIcon: Icon(icon, color: const Color(0xFF64748b), size: 18), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      child: TextField(
        controller: _passwordController, obscureText: _obscure,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(
          hintText: AppStrings.t(context, 'Password (Staff/Admin only)'), hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)),
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF64748b), size: 18),
          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF64748b), size: 18), onPressed: () => setState(() => _obscure = !_obscure)),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _languageSelector() {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: localeProvider.locale.languageCode,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF1E66F5)),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a), fontWeight: FontWeight.w600),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
              ],
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                await localeProvider.setLocale(value);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: const Color(0xFF0f172a)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
        ]),
      ),
    );
  }

  Future<void> _login() async {
    if (_identifierController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'Please enter email or mobile')))); return; }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final password = _passwordController.text.trim();

    if (password.isNotEmpty) {
      // Password login (superadmin, city admin, department)
      final response = await auth.loginWithPassword(_identifierController.text.trim(), password);
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (response['success'] == true) {
        final role = response['role'] ?? 'citizen';
        if (role == 'superadmin' || role == 'city_admin' || role == 'department') {
          Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.userDashboard);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? AppStrings.t(context, 'Login failed'))));
      }
    } else {
      // OTP login (citizens)
      final success = await auth.sendOtp(_identifierController.text.trim());
      setState(() => _isLoading = false);
      if (success && mounted) {
        Navigator.pushNamed(context, AppRoutes.otp, arguments: {'email': _identifierController.text.trim()});
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? AppStrings.t(context, 'Failed to send OTP'))));
      }
    }
  }
}
