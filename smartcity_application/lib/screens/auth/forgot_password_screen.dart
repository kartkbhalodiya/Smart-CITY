import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _error;

  late AnimationController _ac;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your department email');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ApiService.post(
      ApiConfig.departmentForgotPassword,
      {'email': email},
      includeAuth: false,
    );

    setState(() {
      _isLoading = false;
      if (res['success'] == true) {
        _sent = true;
      } else {
        _error = res['message'] ?? 'Something went wrong. Try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Background image
        Image.network(
          'https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
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
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x261E66F5),
                        blurRadius: 50,
                        offset: const Offset(0, 20),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: _sent ? _successView() : _formView(),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _formView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Logo
      Image.asset('assets/images/logo.png', height: 60),
      const SizedBox(height: 6),
      Text(
        'COMPLAINT MANAGEMENT SYSTEM',
        style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E66F5),
            letterSpacing: 1.2),
      ),
      const SizedBox(height: 16),

      // Lock icon badge
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1E66F5).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_reset_rounded,
            size: 32, color: Color(0xFF1E66F5)),
      ),
      const SizedBox(height: 14),

      Text(
        'Forgot Password?',
        style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0f172a)),
      ),
      const SizedBox(height: 6),
      Text(
        'Enter your department email address.\nA new password will be sent instantly.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748b),
            height: 1.5),
      ),
      const SizedBox(height: 24),

      // Info banner
      Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFFEA580C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This is only for Department accounts. Citizens use OTP login.',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFEA580C),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // Error
      if (_error != null) ...[
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFF991B1B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF991B1B),
                      fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],

      // Email field
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
        ),
        child: TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFF0f172a)),
          decoration: InputDecoration(
            hintText: 'Department Email Address',
            hintStyle: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF64748b)),
            prefixIcon: const Icon(Icons.email_outlined,
                color: Color(0xFF64748b), size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ),
      const SizedBox(height: 20),

      // Submit button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _isLoading ? 'Sending...' : 'SEND NEW PASSWORD',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E66F5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Divider(color: Color(0x0D000000)),
      const SizedBox(height: 14),

      // Back to login
      GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.arrow_back_rounded,
              size: 15, color: Color(0xFF1E66F5)),
          const SizedBox(width: 6),
          Text(
            'Back to Login',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF1E66F5),
                fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    ]);
  }

  Widget _successView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/images/logo.png', height: 60),
      const SizedBox(height: 24),

      // Success icon
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mark_email_read_rounded,
            size: 40, color: Color(0xFF22C55E)),
      ),
      const SizedBox(height: 20),

      Text(
        'Email Sent! ✅',
        style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0f172a)),
      ),
      const SizedBox(height: 10),
      Text(
        'A new password has been sent to',
        style: GoogleFonts.inter(
            fontSize: 13, color: const Color(0xFF64748b)),
      ),
      const SizedBox(height: 4),
      Text(
        _emailCtrl.text.trim(),
        style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E66F5)),
      ),
      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(children: [
          _step('📧', 'Check your inbox for the new password'),
          const SizedBox(height: 8),
          _step('🔐', 'Login with the new password'),
          const SizedBox(height: 8),
          _step('🔑', 'Change it from your profile settings'),
        ]),
      ),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.login),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: Text(
            'GO TO LOGIN',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E66F5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  Widget _step(String emoji, String text) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF166534),
                fontWeight: FontWeight.w500)),
      ),
    ]);
  }
}
