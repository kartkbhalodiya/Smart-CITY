import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
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
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _quoteController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _quoteFade;

  int _quoteIndex = 0;

  final List<String> _quotes = [
    '🏙️ Building a smarter city, together',
    '🧹 Clean streets, happy citizens',
    '🚦 Safer roads for everyone',
    '💧 Every complaint counts for change',
    '🌳 A greener city starts with you',
    '🔧 Report it. Fix it. Live better.',
  ];

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _quoteController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _textSlide = CurvedAnimation(parent: _textController, curve: Curves.easeOut)
        .drive(Tween(begin: const Offset(0, 0.3), end: Offset.zero));
    _quoteFade = CurvedAnimation(parent: _quoteController, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _quoteController.forward();
    _cycleQuotes();
    _navigateWhenReady();
  }

  Future<void> _navigateWhenReady() async {
    final results = await Future.wait([
      _checkPermissions(),
      _loadAuth(),
    ]);

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final allGranted = results[0] as bool;
    final isAuth = results[1] as bool;

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

  void _cycleQuotes() async {
    for (int i = 1; i < _quotes.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await _quoteController.reverse();
      setState(() => _quoteIndex = i);
      _quoteController.forward();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF8F9FF),
              Color(0xFFEEF2FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo with animated container
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E66F5).withOpacity(0.1),
                          const Color(0xFF667EEA).withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E66F5).withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // App name
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      Text(
                        'JanHelp',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E66F5),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.t(context, 'Smart City Complaint Management'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Loading circle
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E66F5).withOpacity(0.1),
                    ),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E66F5),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Rotating quotes
              FadeTransition(
                opacity: _quoteFade,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E66F5).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1E66F5).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    AppStrings.t(context, _quotes[_quoteIndex]),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF475569),
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quote dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_quotes.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _quoteIndex ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: i == _quoteIndex
                          ? const LinearGradient(
                              colors: [Color(0xFF1E66F5), Color(0xFF667EEA)],
                            )
                          : null,
                      color: i == _quoteIndex ? null : const Color(0xFF1E66F5).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),

              const Spacer(),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    Text(
                      AppStrings.t(context, 'Made with ❤️ in India 🇮🇳'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.t(context, 'Designed by Kartik Bhalodiya'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
