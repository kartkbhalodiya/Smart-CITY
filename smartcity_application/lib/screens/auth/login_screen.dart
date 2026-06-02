import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscure = true;
  bool _showPassword = false;
  bool _emailTouched = false;
  bool _emailHadValidState = false;
  bool _loginSuccess = false;
  bool _didPrecacheAuthAssets = false;
  String? _emailError;
  String? _passwordError;

  late final AnimationController _shakeController;

  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _ink = Color(0xFF111827);

  bool get _emailValid => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
      .hasMatch(_identifierController.text.trim());

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
    );
    _identifierController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheAuthAssets) return;
    _didPrecacheAuthAssets = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final asset in const [
        'assets/images/register_122842_bg.png',
        'assets/images/forgot_password_bg.png',
        'assets/images/otp_verify_bg.png',
        'assets/images/track_status_121826_bg.png',
      ]) {
        precacheImage(AssetImage(asset), context);
      }
    });
  }

  @override
  void dispose() {
    _identifierController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _shakeController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (_passwordError == null) return;
    setState(() => _passwordError = null);
  }

  void _onEmailChanged() {
    final valid = _emailValid;
    if (valid && !_emailHadValidState) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _emailTouched = _identifierController.text.isNotEmpty;
      _emailHadValidState = valid;
      if (valid || _identifierController.text.isEmpty) {
        _emailError = null;
      }
      if (_showPassword) {
        _showPassword = false;
        _passwordError = null;
        _passwordController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: false,
      body: _GlassScaffold(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
              final keyboardLift =
                  bottomInset > 0 ? math.min(bottomInset * 0.06, 20.0) : 0.0;
              final compactLogin = _showPassword;
              final contentWidth =
                  constraints.maxWidth > 520 ? 390.0 : constraints.maxWidth;
              final horizontalPadding = constraints.maxWidth > 520 ? 0.0 : 32.0;
              final tallScreen = constraints.maxHeight > 760;
              final baseContentTop =
                  constraints.maxHeight * (tallScreen ? 0.25 : 0.22);
              final extraContentOffset = tallScreen ? 194.0 : 138.0;
              const keyboardTopAdjustment = 0.0;
              final contentTop = math.max(18.0,
                  baseContentTop + extraContentOffset - keyboardTopAdjustment);
              return Padding(
                padding: EdgeInsets.only(bottom: keyboardLift),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: bottomInset > 0 || compactLogin
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    contentTop,
                    horizontalPadding,
                    28 + math.min(bottomInset * 0.08, 28.0),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _loginBox(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Welcome Back',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: GoogleFonts.poppins(
                                    fontSize: compactLogin ? 33 : 37,
                                    height: 1.02,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                    color: const Color(0xFF0A0A0A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Login to your account to continue with JanHelp.',
                                style: GoogleFonts.inter(
                                  fontSize: compactLogin ? 13.5 : 15,
                                  height: 1.42,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF7A7F8C),
                                ),
                              ),
                              const SizedBox(height: 14),
                              AnimatedBuilder(
                                animation: _shakeController,
                                builder: (context, child) {
                                  final dx = _shakeController.value == 0
                                      ? 0.0
                                      : 10 *
                                          (1 - _shakeController.value) *
                                          ((_shakeController.value * 5)
                                                  .round()
                                                  .isEven
                                              ? 1
                                              : -1);
                                  return Transform.translate(
                                      offset: Offset(dx, 0), child: child);
                                },
                                child: _GlassTextField(
                                  controller: _identifierController,
                                  focusNode: _emailFocus,
                                  hint: 'Email address',
                                  icon: Icons.person_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  valid: _emailTouched && _emailValid,
                                  error: _emailError,
                                  onSubmitted: (_) => _login(),
                                ),
                              ),
                              if (_showPassword) ...[
                                const SizedBox(height: 14),
                                _GlassTextField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  hint: AppStrings.t(context, 'Password'),
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscure,
                                  error: _passwordError,
                                  suffix: IconButton(
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF7A7F8C),
                                      size: 24,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                  onSubmitted: (_) => _login(),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, AppRoutes.forgotPassword),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF111111),
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 42),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    AppStrings.t(context, 'Forgot Password?'),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _GlassButton(
                                label: _loginSuccess
                                    ? 'Login Successful'
                                    : (_isLoading
                                        ? 'Authenticating...'
                                        : 'Sign In'),
                                icon: _loginSuccess
                                    ? Icons.check_circle_rounded
                                    : null,
                                loading: _isLoading,
                                success: _loginSuccess,
                                onPressed: _isLoading ? null : _login,
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, AppRoutes.register),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      text: AppStrings.t(
                                          context, "Don't have an account? "),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: const Color(0xFF8B90A0),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              AppStrings.t(context, 'Register'),
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _GlassActionTile(
                                      icon: Icons.person_outline_rounded,
                                      label: 'Guest',
                                      onTap: () =>
                                          Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        AppRoutes.guestDashboard,
                                        (_) => false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _GlassActionTile(
                                      icon: Icons.search_rounded,
                                      label: 'Track Request',
                                      onTap: () => Navigator.pushNamed(
                                          context, AppRoutes.guestTrack),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _loginBox({required Widget child}) {
    return RepaintBoundary(child: child);
  }

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    if (identifier.isEmpty || !_emailValid) {
      setState(() {
        _emailTouched = true;
        _emailError = identifier.isEmpty
            ? 'Email is required'
            : 'Enter a valid email address';
      });
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _loginSuccess = false;
      _emailError = null;
      _passwordError = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_showPassword) {
      if (password.isEmpty) {
        setState(() {
          _isLoading = false;
          _passwordError = 'Password is required';
        });
        HapticFeedback.mediumImpact();
        return;
      }

      final response = await auth.loginWithPassword(identifier, password);
      if (!mounted) return;
      if (response['success'] == true) {
        await _completeSuccess();
        if (!mounted) return;
        final role = response['role'] ?? 'citizen';
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.dashboardForRole(role?.toString()),
        );
      } else {
        HapticFeedback.mediumImpact();
        setState(() {
          _isLoading = false;
          _passwordError = auth.error ?? AppStrings.t(context, 'Login failed');
        });
      }
      return;
    }

    final success = await auth.sendOtp(identifier);
    if (!mounted) return;
    if (success) {
      await _completeSuccess();
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.otp,
          arguments: {'email': identifier});
    } else {
      setState(() => _isLoading = false);
      final message = auth.error ?? AppStrings.t(context, 'Failed to send OTP');
      final lowerMessage = message.toLowerCase();
      if (lowerMessage.contains('staff') ||
          lowerMessage.contains('admin') ||
          lowerMessage.contains('password')) {
        setState(() {
          _showPassword = true;
          _passwordError = null;
        });
        return;
      }
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _completeSuccess() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = false;
      _loginSuccess = true;
    });
    await Future.delayed(const Duration(milliseconds: 420));
  }
}

class _GlassScaffold extends StatefulWidget {
  final Widget child;
  const _GlassScaffold({required this.child});

  @override
  State<_GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<_GlassScaffold> {
  bool _evictedLoginAsset = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_evictedLoginAsset) return;
    _evictedLoginAsset = true;
    const AssetImage('assets/images/login_hero_illustration.png').evict();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF6F7FB),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8F8FA),
                  Color(0xFFF4F5F8),
                ],
                stops: [0.0, 0.40, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: screenHeight * 0.50,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Image.asset(
                'assets/images/login_hero_illustration.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: screenHeight * 0.35,
          height: screenHeight * 0.16,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.38, 0.74, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    const Color(0xFFF6F7FB).withValues(alpha: 0.82),
                    const Color(0xFFF6F7FB).withValues(alpha: 0.98),
                    const Color(0xFFF6F7FB),
                  ],
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool valid;
  final String? error;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _GlassTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.valid = false,
    this.error,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final borderColor = hasError
        ? _LoginScreenState._red.withValues(alpha: 0.82)
        : valid
            ? _LoginScreenState._green.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.95);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: hasError || valid ? 1.7 : 1.35,
            ),
            boxShadow: [
              if (hasError || valid)
                BoxShadow(
                  color: (hasError
                          ? _LoginScreenState._red
                          : _LoginScreenState._green)
                      .withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              obscureText: obscureText,
              onSubmitted: onSubmitted,
              cursorColor: _LoginScreenState._ink,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _LoginScreenState._ink,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA3A7B4),
                ),
                prefixIcon:
                    Icon(icon, color: const Color(0xFF8B90A0), size: 22),
                suffixIcon: suffix ??
                    (valid
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: _LoginScreenState._green,
                            size: 24,
                          )
                        : const SizedBox(width: 24)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 7),
            child: Text(
              error!,
              style: GoogleFonts.inter(
                color: _LoginScreenState._red,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool success;
  final IconData? icon;

  const _GlassButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.success = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final borderAlpha = success ? 0.34 : 0.24;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onPressed?.call();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A1A),
                Color(0xFF050505),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withValues(alpha: borderAlpha)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: loading
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon, color: Colors.white, size: 24),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (!loading && icon == null)
                        Positioned(
                          right: 10,
                          top: 8,
                          child: _ArrowCircle(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 21,
        ),
      ),
    );
  }
}

class _GlassActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GlassActionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.88), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.055),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.85),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.42),
                  Colors.white.withValues(alpha: 0.10),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.42),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  child: Icon(icon, color: const Color(0xFF111111), size: 17),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _LoginScreenState._ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
