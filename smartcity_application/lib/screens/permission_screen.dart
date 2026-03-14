import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionScreen({super.key, required this.onDone});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1E66F5);

  bool _requesting = false;
  Map<String, PermissionStatus> _statuses = {};

  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
    _checkStatuses();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _checkStatuses() async {
    final loc = await Permission.location.status;
    final cam = await Permission.camera.status;
    final notif = await Permission.notification.status;
    // photos for Android 13+, storage for older
    final photos = await Permission.photos.status;
    if (mounted) {
      setState(() {
        _statuses = {
          'location': loc,
          'camera': cam,
          'notification': notif,
          'photos': photos,
        };
      });
    }
  }

  bool get _allGranted => _statuses.values.every((s) => s.isGranted);

  Future<void> _requestAll() async {
    setState(() => _requesting = true);

    try {
      // Request location via geolocator (more reliable on Android)
      LocationPermission locPerm = await Geolocator.checkPermission();
      if (locPerm == LocationPermission.denied) {
        locPerm = await Geolocator.requestPermission();
      }

      // Request others one by one to avoid hang
      final cam = await Permission.camera.request();
      final notif = await Permission.notification.request();

      // Storage: try photos first (Android 13+), fallback to storage
      PermissionStatus photos = await Permission.photos.request();
      if (!photos.isGranted) {
        photos = await Permission.storage.request();
      }

      if (!mounted) return;

      // Check if any are permanently denied → open settings
      final anyDeniedForever = cam.isPermanentlyDenied ||
          notif.isPermanentlyDenied ||
          photos.isPermanentlyDenied ||
          locPerm == LocationPermission.deniedForever;

      if (anyDeniedForever) {
        setState(() => _requesting = false);
        _showSettingsDialog();
        return;
      }

      await _checkStatuses();
      setState(() => _requesting = false);

      // If all critical ones granted, proceed
      if (locPerm != LocationPermission.denied) {
        widget.onDone();
      }
    } catch (e) {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Permissions Required', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Some permissions were denied. Please enable them from App Settings to use all features.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748b))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // Re-check after returning from settings
              await _checkStatuses();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Open Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _PermItem(Icons.location_on_rounded, 'Location', 'Detect & pin your address on map', const Color(0xFF1E66F5), _statuses['location']),
      _PermItem(Icons.photo_library_rounded, 'Photos & Storage', 'Attach photos with complaints', const Color(0xFF7C3AED), _statuses['photos']),
      _PermItem(Icons.camera_alt_rounded, 'Camera', 'Capture photos directly in app', const Color(0xFF059669), _statuses['camera']),
      _PermItem(Icons.notifications_rounded, 'Notifications', 'Get updates on your complaints', const Color(0xFFD97706), _statuses['notification']),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.security_rounded, size: 38, color: _primary),
                  ),
                  const SizedBox(height: 18),
                  Text('App Permissions', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                  const SizedBox(height: 6),
                  Text(
                    'JanHelp needs these permissions for the best experience',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b), height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  ...items.map((p) => _permCard(p)),
                  const Spacer(),

                  // Allow button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _requesting ? null : (_allGranted ? widget.onDone : _requestAll),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _allGranted ? const Color(0xFF059669) : _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _requesting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_allGranted ? Icons.check_circle_rounded : Icons.security_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _allGranted ? 'Continue' : 'Allow Permissions',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Skip
                  GestureDetector(
                    onTap: _requesting ? null : widget.onDone,
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
    final granted = p.status?.isGranted ?? false;
    final denied = p.status?.isPermanentlyDenied ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: granted ? const Color(0xFFF0FDF4) : p.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted ? const Color(0xFF86EFAC) : denied ? const Color(0xFFFFCDD2) : p.color.withOpacity(0.15),
        ),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: granted ? const Color(0xFFDCFCE7) : p.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(p.icon, color: granted ? const Color(0xFF059669) : p.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
          Text(p.subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b))),
        ])),
        const SizedBox(width: 8),
        if (p.status == null)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94a3b8)))
        else if (granted)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20)
        else if (denied)
          const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 20)
        else
          Icon(Icons.radio_button_unchecked_rounded, color: p.color.withOpacity(0.4), size: 20),
      ]),
    );
  }
}

class _PermItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final PermissionStatus? status;
  const _PermItem(this.icon, this.title, this.subtitle, this.color, this.status);
}
