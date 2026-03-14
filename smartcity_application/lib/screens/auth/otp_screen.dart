import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _c = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _f = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  late AnimationController _ac;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _f[0].requestFocus());
  }

  @override
  void dispose() { _ac.dispose(); for (var c in _c) c.dispose(); for (var f in _f) f.dispose(); super.dispose(); }

  String get _otp => _c.map((c) => c.text).join();
  bool get _complete => _otp.length == 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Image.network('https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667eea), Color(0xFF764ba2)]))),
        ),
        Container(color: const Color(0x331E66F5)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SlideTransition(
                position: _slide,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: const Color(0x261E66F5), blurRadius: 50, offset: const Offset(0, 20))],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.network('https://res.cloudinary.com/dk1q50evg/image/upload/logo', height: 56,
                      errorBuilder: (_, __, ___) => const Icon(Icons.location_city, size: 56, color: Color(0xFF1E66F5))),
                    const SizedBox(height: 4),
                    Text('COMPLAINT MANAGEMENT SYSTEM', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5), letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text('Verify OTP', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                    Text('Secure login verification', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
                    const SizedBox(height: 20),
                    // Email info banner - gradient same as website
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF2ECC71)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Text('OTP sent to', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(widget.email, style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    // 6 OTP input boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) => _otpBox(i)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isLoading || !_complete) ? null : _verify,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text('VERIFY & CONTINUE', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _complete ? const Color(0xFF1E66F5) : const Color(0xFF94a3b8),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (_isLoading) ...[const SizedBox(height: 12), const CircularProgressIndicator(color: Color(0xFF1E66F5))],
                    const SizedBox(height: 20),
                    const Divider(color: Color(0x0D000000)),
                    const SizedBox(height: 12),
                    Text("Didn't receive the code?", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.refresh, size: 16, color: Color(0xFF1E66F5)),
                        const SizedBox(width: 6),
                        Text('Resend OTP', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E66F5), fontWeight: FontWeight.w600)),
                      ]),
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

  Widget _otpBox(int i) {
    return Container(
      width: 45, height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      child: TextField(
        controller: _c[i], focusNode: _f[i],
        textAlign: TextAlign.center, keyboardType: TextInputType.number,
        maxLength: 1, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a)),
        decoration: const InputDecoration(border: InputBorder.none, counterText: '', contentPadding: EdgeInsets.zero),
        onChanged: (val) {
          if (val.isNotEmpty && i < 5) _f[i + 1].requestFocus();
          else if (val.isEmpty && i > 0) _f[i - 1].requestFocus();
          setState(() {});
        },
      ),
    );
  }

  Future<void> _verify() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOtp(widget.email, _otp);
    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Invalid OTP')));
    }
  }
}
