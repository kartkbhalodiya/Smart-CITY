import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_strings.dart';
import 'permission_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _accent = Color(0xFFFF6B35);

  late final AnimationController _bgController;
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _pulseController;
  late final AnimationController _quoteController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _pulseScale;
  late final Animation<double> _quoteOpacity;

  int _quoteIndex = 0;

  final List<String> _quotes = const [
    'Citizens first, always.',
    'Report smarter. Resolve faster.',
    'Better roads, safer city, cleaner tomorrow.',
    'Your voice powers civic action.',
    'Real-time complaints, real-world impact.',
  ];

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _quoteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _logoScale = Tween<double>(begin: 0.74, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, .18), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _pulseScale = Tween<double>(begin: .96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _quoteOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _quoteController, curve: Curves.easeInOut),
    );

    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 120));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    _quoteController.forward();
    _cycleQuotes();
    _navigateWhenReady();
  }

  Future<void> _navigateWhenReady() async {
    final results = await Future.wait([
      _checkPermissions(),
      _loadAuth(),
    ]);

    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    final allGranted = results[0];
    final isAuth = results[1];

    if (!allGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PermissionScreen(
            onDone: (BuildContext permContext) async {
              final authProvider = Provider.of<AuthProvider>(permContext, listen: false);
              await authProvider.loadUser();
              if (!permContext.mounted) return;
              Navigator.pushReplacementNamed(
                permContext,
                authProvider.isAuthenticated ? AppRoutes.userDashboard : AppRoutes.login,
              );
            },
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, isAuth ? AppRoutes.userDashboard : AppRoutes.login);
  }

  Future<bool> _checkPermissions() async {
    try {
      final loc = await Permission.locationWhenInUse.status;
      final cam = await Permission.camera.status;
      final notif = await Permission.notification.status;
      final photos = await Permission.photos.status;
      return loc.isGranted && cam.isGranted && notif.isGranted && photos.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _loadAuth() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadUser();
      return authProvider.isAuthenticated;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cycleQuotes() async {
    for (int i = 1; i < _quotes.length; i++) {
      await Future.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      await _quoteController.reverse();
      if (!mounted) return;
      setState(() => _quoteIndex = i);
      _quoteController.forward();
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final t = _bgController.value;
          final orb1X = (math.sin(t * math.pi * 2) * 26);
          final orb1Y = (math.cos(t * math.pi * 2) * 18);
          final orb2X = (math.cos(t * math.pi * 2) * 22);
          final orb2Y = (math.sin(t * math.pi * 2) * 16);

          // No city icons, no logo. Only text.

          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF8F9FA),
                      Color(0xFFF3F5F9),
                      Color(0xFFFFFFFF),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 90 + orb1Y,
                right: -30 + orb1X,
                child: _bgOrb(const Color(0x26FF6B35), 170),
              ),
              Positioned(
                bottom: 140 + orb2Y,
                left: -45 + orb2X,
                child: _bgOrb(const Color(0x1E3B82F6), 190),
              ),
              Positioned(
                top: 250 - orb2Y * .4,
                left: 40 - orb2X * .2,
                child: _bgOrb(const Color(0x1A4ADE80), 120),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 120),
                      // App logo centered, full width, no box
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildFeatureChips(),
                      const Spacer(),
                      _buildQuoteCard(),
                      const SizedBox(height: 16),
                      _buildBottomLoader(),
                      const SizedBox(height: 18),
                      Text(
                        AppStrings.t(context, 'Designed by Kartik Bhalodiya'),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bgOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // _buildLogoHero removed (no longer needed)

  // _buildTitleBlock removed (no longer needed)

  Widget _buildFeatureChips() {
    Widget chip(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEFF3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.3,
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(Icons.bolt_rounded, AppStrings.t(context, 'Fast')),
        chip(Icons.verified_user_rounded, AppStrings.t(context, 'Trusted')),
        chip(Icons.track_changes_rounded, AppStrings.t(context, 'Trackable')),
      ],
    );
  }

  Widget _buildQuoteCard() {
    return FadeTransition(
      opacity: _quoteOpacity,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEDEFF3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          AppStrings.t(context, _quotes[_quoteIndex]),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13.2,
            height: 1.45,
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLoader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1EB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFDFC8), width: 1),
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B35)),
              backgroundColor: Color(0xFFFFDEC9),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppStrings.t(context, 'Preparing your smart city experience...'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11.2,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
