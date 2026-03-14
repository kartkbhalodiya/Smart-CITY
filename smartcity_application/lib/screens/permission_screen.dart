import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionScreen({super.key, required this.onDone});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1E66F5);
  bool _requesting = false;

  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _permissions = [
    _PermItem(Icons.location_on_rounded, 'Location', 'To detect & pin your address on map', const Color(0xFF1E66F5)),
    _PermItem(Icons.photo_library_rounded, 'Photos & Storage', 'To attach photos with your complaints', const Color(0xFF7C3AED)),
    _PermItem(Icons.camera_alt_rounded, 'Camera', 'To capture photos directly in app', const Color(0xFF059669)),
    _PermItem(Icons.notifications_rounded, 'Notifications', 'To get updates on your complaints', const Color(0xFFD97706)),
  ];

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _requestAll() async {
    setState(() => _requesting = true);

    await [
      Permission.location,
      Permission.photos,
      Permission.storage,
      Permission.camera,
      Permission.notification,
    ].request();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);

    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Icon
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_rounded, size: 40, color: _primary),
                  ),
                  const SizedBox(height: 20),

                  Text('App Permissions', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                  const SizedBox(height: 8),
                  Text(
                    'JanHelp needs a few permissions to give you the best experience',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b), height: 1.5),
                  ),
                  const SizedBox(height: 36),

                  // Permission cards
                  ..._permissions.map((p) => _permCard(p)),

                  const Spacer(),

                  // Allow button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _requesting ? null : _requestAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _requesting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text('Allow Permissions', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Skip
                  GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('permissions_requested', true);
                      if (mounted) widget.onDone();
                    },
                    child: Text('Skip for now', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94a3b8), fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _permCard(_PermItem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: p.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(p.icon, color: p.color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
          Text(p.subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
        ])),
        Icon(Icons.check_circle_outline_rounded, color: p.color.withOpacity(0.4), size: 20),
      ]),
    );
  }
}

class _PermItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _PermItem(this.icon, this.title, this.subtitle, this.color);
}
