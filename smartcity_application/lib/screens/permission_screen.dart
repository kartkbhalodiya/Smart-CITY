import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionScreen({super.key, required this.onDone});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1E66F5);

  bool _requesting = false;
  PermissionStatus? _locStatus;
  PermissionStatus? _camStatus;
  PermissionStatus? _notifStatus;
  PermissionStatus? _storageStatus;

  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
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
    final loc = await Permission.locationWhenInUse.status;
    final cam = await Permission.camera.status;
    final notif = await Permission.notification.status;
    final storage = await _storagePermission().status;
    if (mounted) {
      setState(() {
        _locStatus = loc;
        _camStatus = cam;
        _notifStatus = notif;
        _storageStatus = storage;
      });
    }
  }

  // Android 13+ uses photos, older uses storage
  Permission _storagePermission() {
    return Permission.photos;
  }

  bool get _allGranted =>
      (_locStatus?.isGranted ?? false) &&
      (_camStatus?.isGranted ?? false) &&
      (_notifStatus?.isGranted ?? false) &&
      (_storageStatus?.isGranted ?? false);

  Future<void> _requestAll() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    try {
      // Request all at once using permission_handler only
      final Map<Permission, PermissionStatus> results = await [
        Permission.locationWhenInUse,
        Permission.camera,
        Permission.notification,
        Permission.photos,
      ].request();

      // If photos denied, try storage (older Android)
      PermissionStatus storageResult =
          results[Permission.photos] ?? PermissionStatus.denied;
      if (!storageResult.isGranted) {
        storageResult = await Permission.storage.request();
      }

      if (!mounted) return;

      setState(() {
        _locStatus = results[Permission.locationWhenInUse];
        _camStatus = results[Permission.camera];
        _notifStatus = results[Permission.notification];
        _storageStatus = storageResult;
        _requesting = false;
      });

      // Check if any permanently denied
      final anyPermanent = (_locStatus?.isPermanentlyDenied ?? false) ||
          (_camStatus?.isPermanentlyDenied ?? false) ||
          (_notifStatus?.isPermanentlyDenied ?? false) ||
          (_storageStatus?.isPermanentlyDenied ?? false);

      if (anyPermanent) {
        _showSettingsDialog();
        return;
      }

      // Always proceed after requesting — don't block on non-critical perms
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Permissions Blocked',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Some permissions are permanently denied. Open App Settings to enable them.',
          style: GoogleFonts.inter(
              fontSize: 13, color: const Color(0xFF64748b)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDone(); // let them continue anyway
            },
            child: Text('Skip',
                style: GoogleFonts.inter(color: const Color(0xFF94a3b8))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              await Future.delayed(const Duration(milliseconds: 500));
              await _checkStatuses();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Open Settings',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _PermItem(Icons.location_on_rounded, 'Location',
          'Detect & pin your address on map', const Color(0xFF1E66F5), _locStatus),
      _PermItem(Icons.photo_library_rounded, 'Photos & Storage',
          'Attach photos with complaints', const Color(0xFF7C3AED), _storageStatus),
      _PermItem(Icons.camera_alt_rounded, 'Camera',
          'Capture photos directly in app', const Color(0xFF059669), _camStatus),
      _PermItem(Icons.notifications_rounded, 'Notifications',
          'Get updates on your complaints', const Color(0xFFD97706), _notifStatus),
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
                    decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.security_rounded,
                        size: 38, color: _primary),
                  ),
                  const SizedBox(height: 18),
                  Text('App Permissions',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0f172a))),
                  const SizedBox(height: 6),
                  Text(
                    'JanHelp needs these permissions for the best experience',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748b),
                        height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  ...items.map((p) => _permCard(p)),
                  const Spacer(),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _requesting
                          ? null
                          : (_allGranted ? widget.onDone : _requestAll),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _allGranted
                            ? const Color(0xFF059669)
                            : _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _requesting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    _allGranted
                                        ? Icons.check_circle_rounded
                                        : Icons.security_rounded,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _allGranted
                                      ? 'Continue'
                                      : 'Allow Permissions',
                                  style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: widget.onDone,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Skip for now',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94a3b8),
                              fontWeight: FontWeight.w500)),
                    ),
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
    final permanentDenied = p.status?.isPermanentlyDenied ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: granted
            ? const Color(0xFFF0FDF4)
            : permanentDenied
                ? const Color(0xFFFFF1F2)
                : p.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted
              ? const Color(0xFF86EFAC)
              : permanentDenied
                  ? const Color(0xFFFFCDD2)
                  : p.color.withOpacity(0.15),
        ),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: granted
                ? const Color(0xFFDCFCE7)
                : p.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(p.icon,
              color: granted ? const Color(0xFF059669) : p.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(p.title,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0f172a))),
              Text(p.subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748b))),
            ])),
        const SizedBox(width: 8),
        if (p.status == null)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF94a3b8)))
        else if (granted)
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF059669), size: 20)
        else if (permanentDenied)
          const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 20)
        else
          Icon(Icons.radio_button_unchecked_rounded,
              color: p.color.withOpacity(0.5), size: 20),
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
  const _PermItem(
      this.icon, this.title, this.subtitle, this.color, this.status);
}
