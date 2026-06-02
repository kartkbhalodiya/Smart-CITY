import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';

enum _ForgotResult { idle, sent, notFound }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF64748B);

  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  late final AnimationController _shakeController;
  late final AnimationController _markController;

  bool _isLoading = false;
  String? _error;
  String? _serverMessage;
  _ForgotResult _result = _ForgotResult.idle;

  bool get _validEmail =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailCtrl.text.trim());

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _markController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _emailCtrl.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_onEmailChanged);
    _shakeController.dispose();
    _markController.dispose();
    _emailFocus.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _serverMessage = null;
      _result = _ForgotResult.idle;
    });
    _markController.reset();
  }

  Future<void> _submit() async {
    if (_result == _ForgotResult.sent) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    final email = _emailCtrl.text.trim();
    if (!_validEmail) {
      HapticFeedback.heavyImpact();
      setState(() {
        _result = _ForgotResult.notFound;
        _error = AppStrings.t(context, 'Enter a valid email address');
      });
      _shakeController.forward(from: 0);
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _isLoading = true;
      _error = null;
      _serverMessage = null;
      _result = _ForgotResult.idle;
    });

    final response = await ApiService.post(
      ApiConfig.departmentForgotPassword,
      {'email': email},
      includeAuth: false,
    );
    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        _isLoading = false;
        _result = _ForgotResult.sent;
        _serverMessage = AppStrings.t(
          context,
          'Email found. New password sent to your email.',
        );
      });
      HapticFeedback.mediumImpact();
      _markController.forward(from: 0);
      return;
    }

    final message = '${response['message'] ?? ''}'.trim();
    setState(() {
      _isLoading = false;
      _result = _ForgotResult.notFound;
      _error = message.isEmpty
          ? AppStrings.t(context, 'No email found')
          : AppStrings.t(context, 'No email found');
      _serverMessage = message.isEmpty ? null : message;
    });
    HapticFeedback.heavyImpact();
    _markController.forward(from: 0);
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: false,
      body: _ForgotGlassBackground(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
              final keyboardLift =
                  bottomInset > 0 ? math.min(bottomInset * 0.06, 20.0) : 0.0;
              final contentWidth =
                  constraints.maxWidth > 520 ? 390.0 : constraints.maxWidth;
              final horizontalPadding = constraints.maxWidth > 520 ? 0.0 : 32.0;
              final tallScreen = constraints.maxHeight > 760;
              final contentTop =
                  constraints.maxHeight * (tallScreen ? 0.42 : 0.34);
              return Padding(
                padding: EdgeInsets.only(bottom: keyboardLift),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: bottomInset > 0
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    math.max(18.0, contentTop),
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
                        child: RepaintBoundary(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _brandHeader(),
                              const SizedBox(height: 14),
                              AnimatedBuilder(
                                animation: _shakeController,
                                builder: (context, child) {
                                  final dx = math.sin(
                                        _shakeController.value * math.pi * 8,
                                      ) *
                                      7;
                                  return Transform.translate(
                                    offset: Offset(dx, 0),
                                    child: child,
                                  );
                                },
                                child: _emailField(),
                              ),
                              const SizedBox(height: 14),
                              _statusCard(),
                              const SizedBox(height: 18),
                              _submitButton(),
                              const SizedBox(height: 16),
                              _backAction(),
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

  Widget _brandHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            AppStrings.t(context, 'Forgot Password?'),
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 35,
              height: 1.02,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: const Color(0xFF0A0A0A),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.t(
            context,
            'Enter department email. If found, a new password will be sent.',
          ),
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.42,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF7A7F8C),
          ),
        ),
      ],
    );
  }

  Widget _emailField() {
    final hasError = _result == _ForgotResult.notFound || _error != null;
    final valid = _validEmail && !hasError;
    final borderColor = hasError
        ? _red.withValues(alpha: 0.82)
        : valid
            ? _green.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.95);
    return Container(
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
              color: (hasError ? _red : _green).withValues(alpha: 0.18),
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
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          cursorColor: _ink,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
          decoration: InputDecoration(
            hintText: AppStrings.t(context, 'Department Email Address'),
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF68758C),
            ),
            prefixIcon: const Icon(
              Icons.alternate_email_rounded,
              color: Color(0xFF8B90A0),
              size: 22,
            ),
            suffixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.30, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: hasError
                  ? const Icon(
                      Icons.cancel_rounded,
                      key: ValueKey('not-found'),
                      color: _red,
                      size: 24,
                    )
                  : valid
                      ? const Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey('valid'),
                          color: _green,
                          size: 24,
                        )
                      : const SizedBox(key: ValueKey('empty'), width: 24),
            ),
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
    );
  }

  Widget _statusCard() {
    final show = _result != _ForgotResult.idle || _error != null;
    final isSent = _result == _ForgotResult.sent;
    final color = isSent ? _green : _red;
    final title = isSent
        ? AppStrings.t(context, 'Email found')
        : (_error ?? AppStrings.t(context, 'No email found'));
    final message = isSent
        ? (_serverMessage ??
            AppStrings.t(context, 'New password sent to your email.'))
        : (_serverMessage ??
            AppStrings.t(context, 'No account exists for this email.'));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: !show
          ? _noticeCard()
          : Container(
              key: ValueKey(_result),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isSent ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _statusIcon(isSent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _noticeCard() {
    return Container(
      key: const ValueKey('notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDA4AF), width: 1.35),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFE11D48),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.t(
                context,
                'Only department accounts receive a new password by email.',
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF9F1239),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(bool isSent) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isSent ? _green : _red,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: (isSent ? _green : _red).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _markController,
        builder: (context, child) {
          final progress = Curves.easeOutCubic
              .transform(_markController.value.clamp(0.0, 1.0));
          return CustomPaint(
            painter: _StatusMarkPainter(
              isSuccess: isSent,
              progress: progress,
            ),
          );
        },
      ),
    );
  }

  Widget _submitButton() {
    final enabled = _validEmail && !_isLoading;
    final sent = _result == _ForgotResult.sent;
    final active = enabled || sent;
    return GestureDetector(
      onTapDown: active ? (_) => HapticFeedback.selectionClick() : null,
      onTap: active ? _submit : null,
      child: Opacity(
        opacity: active ? 1 : 0.62,
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
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: _isLoading
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.3,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppStrings.t(context, 'CHECKING EMAIL...'),
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                sent
                                    ? AppStrings.t(context, 'GO TO LOGIN')
                                    : AppStrings.t(
                                        context,
                                        'SEND NEW PASSWORD',
                                      ),
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const Positioned(
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

  Widget _backAction() {
    return Center(
      child: TextButton.icon(
        onPressed: () =>
            Navigator.pushReplacementNamed(context, AppRoutes.login),
        icon: const Icon(Icons.arrow_back_rounded, size: 16),
        label: Text(AppStrings.t(context, 'Back to Login')),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF111111),
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle:
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ArrowCircle extends StatelessWidget {
  const _ArrowCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _StatusMarkPainter extends CustomPainter {
  final bool isSuccess;
  final double progress;

  const _StatusMarkPainter({
    required this.isSuccess,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final markSize = side * 0.52;
    final markBounds = Size.square(markSize);
    canvas.save();
    canvas.translate(center.dx - markSize / 2, center.dy - markSize / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = markSize * 0.16
      ..color = Colors.white;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = markSize * 0.24
      ..color = Colors.white.withValues(alpha: 0.18 * progress);

    final path = isSuccess ? _checkPath(markBounds) : _crossPath(markBounds);
    _drawPathProgress(canvas, path, glow, progress);
    _drawPathProgress(canvas, path, paint, progress);
    canvas.restore();
  }

  Path _checkPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.16, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.78)
      ..lineTo(size.width * 0.86, size.height * 0.22);
  }

  Path _crossPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.24, size.height * 0.24)
      ..lineTo(size.width * 0.76, size.height * 0.76)
      ..moveTo(size.width * 0.76, size.height * 0.24)
      ..lineTo(size.width * 0.24, size.height * 0.76);
  }

  void _drawPathProgress(
    Canvas canvas,
    Path path,
    Paint paint,
    double progress,
  ) {
    for (final metric in path.computeMetrics()) {
      final extract = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(extract, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StatusMarkPainter oldDelegate) {
    return oldDelegate.isSuccess != isSuccess ||
        oldDelegate.progress != progress;
  }
}

class _ForgotGlassBackground extends StatefulWidget {
  final Widget child;

  const _ForgotGlassBackground({required this.child});

  @override
  State<_ForgotGlassBackground> createState() => _ForgotGlassBackgroundState();
}

class _ForgotGlassBackgroundState extends State<_ForgotGlassBackground> {
  bool _evictedForgotAsset = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_evictedForgotAsset) return;
    _evictedForgotAsset = true;
    const AssetImage('assets/images/otp_verify_bg.png').evict();
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
          top: screenHeight * 0.03,
          height: screenHeight * 0.40,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Image.asset(
                'assets/images/otp_verify_bg.png',
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
