import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
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
                authProvider.isAuthenticated ? AppRoutes.dashboard : AppRoutes.login,
              );
            },
          ),
        ),
      );
      return;
    }
    Navigator.pushReplacementNamed(context, isAuth ? AppRoutes.dashboard : AppRoutes.login);
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
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // Bare logo — no box, no bg
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Loading circle
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Rotating quotes
            FadeTransition(
              opacity: _quoteFade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _quotes[_quoteIndex],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quote dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_quotes.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _quoteIndex ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _quoteIndex
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            const Spacer(),

            // Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Made with ❤️ in India 🇮🇳',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
