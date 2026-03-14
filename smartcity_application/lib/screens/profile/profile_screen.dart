import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (context, auth, _) {
      final user = auth.user;
      return Scaffold(
        body: Stack(children: [
          Image.network('https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
            fit: BoxFit.cover, width: double.infinity, height: double.infinity,
            errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667eea), Color(0xFF764ba2)]))),
          ),
          Container(color: const Color(0x331E66F5)),
          SafeArea(
            child: Column(children: [
              // Back button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x331E66F5), width: 1.5)),
                      child: Row(children: [
                        const Icon(Icons.arrow_back, size: 16, color: Color(0xFF1E66F5)),
                        const SizedBox(width: 6),
                        Text('Back', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E66F5))),
                      ]),
                    ),
                  ),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: const Color(0x261E66F5), blurRadius: 50, offset: const Offset(0, 20))],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(children: [
                    // Avatar
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF154ec7)]),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [BoxShadow(color: const Color(0x401E66F5), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Text(user?.fullName ?? 'User', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                    Text(user?.email ?? '', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF154ec7)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: const Color(0x401E66F5), blurRadius: 12)],
                      ),
                      child: Text('Citizen', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 24),
                    // Section title
                    _sectionTitle(Icons.person_outline, 'Personal Information'),
                    _infoField(Icons.badge_outlined, 'Full Name', user?.fullName ?? ''),
                    const SizedBox(height: 12),
                    _infoField(Icons.email_outlined, 'Email', user?.email ?? ''),
                    const SizedBox(height: 24),
                    // Section title
                    _sectionTitle(Icons.language, 'Language Settings'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF).withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x261E66F5), width: 1.5)),
                      child: Row(children: [
                        const Icon(Icons.language, color: Color(0xFF1E66F5), size: 18),
                        const SizedBox(width: 10),
                        Text('English', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF0f172a))),
                        const Spacer(),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748b)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    // Member since
                    _infoField(Icons.calendar_today_outlined, 'Member Since', user != null ? 'Active Member' : ''),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: Text('SAVE', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E66F5), padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                        ),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          await auth.logout();
                          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
                        },
                        icon: const Icon(Icons.logout, size: 16, color: Color(0xFFdc2626)),
                        label: Text('LOGOUT', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: const Color(0xFFdc2626))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFfecaca), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )),
                    ]),
                    const SizedBox(height: 20),
                    Text('Designed by Kartik Bhalodiya.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
                  ]),
                ),
              )),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF1E66F5)),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      ]),
    );
  }

  Widget _infoField(IconData icon, String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: const Color(0xFF1E66F5)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
      ]),
      const SizedBox(height: 6),
      Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
        child: Text(value.isEmpty ? 'Not provided' : value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF0f172a))),
      ),
    ]);
  }
}
