import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';

enum _OtpMergeState { idle, checking, success, failure }

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF64748B);
  static const _emptySlot = '\u200B';

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<String> _lastDigits = List.filled(6, '');

  late final AnimationController _shakeController;
  late final AnimationController _mergeController;
  late final AnimationController _markController;

  bool _isLoading = false;
  bool _success = false;
  _OtpMergeState _mergeState = _OtpMergeState.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _mergeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _markController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    for (var i = 0; i < 6; i++) {
      _writeDigit(i, '');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusOtpInput(0));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _mergeController.dispose();
    _markController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _otp => _digits.join();
  List<String> get _digits =>
      _controllers.map((controller) => _digitFrom(controller.text)).toList();
  bool get _complete => _otp.length == 6;
  int get _activeIndex {
    final focused = _focusNodes.indexWhere((node) => node.hasFocus);
    if (focused != -1) return focused;
    final empty =
        _controllers.indexWhere((controller) => controller.text.isEmpty);
    return empty == -1 ? 5 : empty;
  }

  String _digitFrom(String value) {
    final cleaned =
        value.replaceAll(_emptySlot, '').replaceAll(RegExp(r'\D'), '');
    return cleaned.isEmpty ? '' : cleaned[cleaned.length - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: false,
      body: _AuthGlassBackground(
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
                  constraints.maxHeight * (tallScreen ? 0.36 : 0.30);
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
                              _emailPill(),
                              const SizedBox(height: 18),
                              _otpBoxes(),
                              _error == null
                                  ? const SizedBox(height: 18)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            color: _red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _error!,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              const SizedBox(height: 8),
                              _verifyButton(),
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
            AppStrings.t(context, 'Verify OTP'),
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 37,
              height: 1.02,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: const Color(0xFF0A0A0A),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the code sent to your email.',
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

  Widget _emailPill() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.35,
        ),
        boxShadow: [
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
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            color: Color(0xFF8B90A0),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(context, 'OTP sent to'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF7A7F8C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBoxes() {
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _mergeController]),
      builder: (context, child) {
        final shakeStrength = 1 - _mergeController.value;
        final dx =
            math.sin(_shakeController.value * math.pi * 8) * 8 * shakeStrength;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxSize =
                  ((constraints.maxWidth - 42) / 6).clamp(42.0, 56.0);
              final rowWidth = math.min(
                constraints.maxWidth,
                (boxSize * 6) + 42,
              );
              final gap = (rowWidth - (boxSize * 6)) / 5;
              final rowStart = (constraints.maxWidth - rowWidth) / 2;
              final boxHeight = boxSize + 4;
              final statusWidth = boxSize;
              final statusHeight = boxHeight;
              final rawProgress = _mergeController.value;
              final progress =
                  Curves.easeInOutCubic.transform(rawProgress.clamp(0.0, 1.0));
              final boxOpacity =
                  (1 - ((rawProgress - 0.66) / 0.20).clamp(0.0, 1.0))
                      .toDouble();
              final statusOpacity =
                  ((rawProgress - 0.54) / 0.34).clamp(0.0, 1.0).toDouble();
              final statusScale =
                  0.86 + (0.14 * Curves.easeOutCubic.transform(statusOpacity));

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _mergeState == _OtpMergeState.idle
                    ? () => _focusOtpInput(_activeIndex)
                    : null,
                child: SizedBox(
                  height: boxHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ...List.generate(6, (index) {
                        final startLeft = rowStart + index * (boxSize + gap);
                        final centerLeft = (constraints.maxWidth - boxSize) / 2;
                        final drift = (index - 2.5) * (1 - progress) * 0.8;
                        final left = lerpDouble(
                            startLeft, centerLeft + drift, progress)!;
                        final yLift =
                            -math.sin(progress * math.pi) * (6 + index * 0.7);
                        final scale = lerpDouble(1, 0.88, progress)!;

                        return Positioned(
                          left: left,
                          top: yLift,
                          width: boxSize,
                          height: boxHeight,
                          child: Opacity(
                            opacity: boxOpacity,
                            child: Transform.scale(
                              scale: scale,
                              child: _otpBox(index, boxSize),
                            ),
                          ),
                        );
                      }),
                      if (rawProgress > 0)
                        Positioned(
                          left: (constraints.maxWidth - statusWidth) / 2,
                          top: 0,
                          width: statusWidth,
                          height: statusHeight,
                          child: Opacity(
                            opacity: statusOpacity,
                            child: Transform.scale(
                              scale: statusScale,
                              child: _mergedOtpBox(statusWidth, statusHeight),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _mergedOtpBox(double width, double height) {
    final isFailure = _mergeState == _OtpMergeState.failure;
    final isSuccess = _mergeState == _OtpMergeState.success;
    final color = isFailure || isSuccess ? (isFailure ? _red : _green) : null;

    return AnimatedContainer(
      key: ValueKey(_mergeState),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFailure
              ? _red.withValues(alpha: 0.86)
              : _green.withValues(alpha: 0.86),
          width: 1.7,
        ),
        boxShadow: [
          BoxShadow(
            color: (isFailure ? _red : _green).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: _mergeState == _OtpMergeState.checking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: _green,
                  strokeWidth: 2.2,
                ),
              )
            : AnimatedBuilder(
                animation: _markController,
                builder: (context, child) {
                  final progress = Curves.easeOutCubic
                      .transform(_markController.value.clamp(0.0, 1.0));
                  final pop = 0.88 + math.sin(progress * math.pi) * 0.14;
                  return Transform.scale(
                    scale: pop,
                    child: CustomPaint(
                      size: Size.square(height * 0.52),
                      painter: _StatusMarkPainter(
                        isSuccess: isSuccess,
                        progress: progress,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _focusOtpInput(int index) {
    if (_mergeState != _OtpMergeState.idle) return;
    final target = index.clamp(0, 5);
    final controller = _controllers[target];
    _focusNodes[target].requestFocus();
    final end = controller.text.length;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: end,
    );
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    if (mounted) setState(() {});
  }

  void _writeDigit(int index, String digit) {
    final nextDigit = digit.isEmpty ? '' : digit[digit.length - 1];
    _lastDigits[index] = nextDigit;
    final text = nextDigit.isEmpty ? _emptySlot : nextDigit;
    _controllers[index].value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  }

  Color _boxFill({
    required bool filled,
    required bool failed,
    required bool verifying,
    required bool active,
  }) {
    if (failed) return const Color(0xFFFFF1F2);
    if (verifying) return const Color(0xFFF0FDF4);
    if (filled) return const Color(0xFFF8FAFC);
    if (active) return const Color(0xFFF8FAFC);
    return const Color(0xFFF8FAFC);
  }

  Color _digitColor({required bool filled, required bool failed}) {
    if (failed) return _red;
    if (filled) return _ink;
    return _muted.withValues(alpha: 0.36);
  }

  Widget _otpBox(int index, double size) {
    final digit = _digits[index];
    final filled = digit.isNotEmpty;
    final active = index == _activeIndex &&
        _focusNodes[index].hasFocus &&
        _mergeState == _OtpMergeState.idle;
    final failed = _error != null || _mergeState == _OtpMergeState.failure;
    final verifying = _mergeState == _OtpMergeState.checking ||
        _mergeState == _OtpMergeState.success;
    final borderColor = failed
        ? _red.withValues(alpha: 0.82)
        : verifying
            ? _green.withValues(alpha: 0.82)
            : active
                ? _green.withValues(alpha: 0.62)
                : const Color(0xFFD6DEE9).withValues(alpha: 0.95);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusOtpInput(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        width: size,
        height: size + 4,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _boxFill(
            filled: filled,
            failed: failed,
            verifying: verifying,
            active: active,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: failed || verifying ? 1.7 : 1.35,
          ),
          boxShadow: [
            if (failed || verifying)
              BoxShadow(
                color: (failed ? _red : _green).withValues(alpha: 0.18),
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 190),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: filled
                    ? Text(
                        digit,
                        key: ValueKey('otp-$index-$digit'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: size * 0.42,
                          fontWeight: FontWeight.w800,
                          color: _digitColor(filled: filled, failed: failed),
                        ),
                      )
                    : SizedBox.shrink(key: ValueKey('empty-$index')),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    textInputAction: index == 5
                        ? TextInputAction.done
                        : TextInputAction.next,
                    autofillHints:
                        index == 0 ? const [AutofillHints.oneTimeCode] : null,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    cursorColor: Colors.transparent,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => _focusOtpInput(index),
                    onChanged: (value) => _handleOtpInput(index, value),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verifyButton() {
    final enabled = _complete && !_isLoading && !_success;
    final visible = _mergeState == _OtpMergeState.idle;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      opacity: visible ? (enabled ? 1 : 0.62) : 0.36,
      child: GestureDetector(
        onTapDown:
            enabled && visible ? (_) => HapticFeedback.selectionClick() : null,
        onTap: enabled && visible ? _verify : null,
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
                        child: Text(
                          _isLoading
                              ? 'Verifying...'
                              : AppStrings.t(context, 'VERIFY & CONTINUE'),
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
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text(AppStrings.t(context, 'Change email or resend OTP')),
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

  void _handleOtpInput(int index, String value) {
    final cleaned =
        value.replaceAll(_emptySlot, '').replaceAll(RegExp(r'\D'), '');
    final previousDigit = _lastDigits[index];
    setState(() {
      _error = null;
      _success = false;
      _mergeState = _OtpMergeState.idle;
    });

    if (cleaned.isEmpty) {
      if (previousDigit.isNotEmpty) {
        _writeDigit(index, '');
        _focusOtpInput(index > 0 ? index - 1 : index);
      } else if (index > 0) {
        _writeDigit(index, '');
        _writeDigit(index - 1, '');
        _focusOtpInput(index - 1);
      } else {
        _writeDigit(index, '');
      }
      HapticFeedback.selectionClick();
      return;
    }

    if (cleaned.length > 1) {
      for (var offset = 0;
          offset < cleaned.length && index + offset < 6;
          offset++) {
        _writeDigit(index + offset, cleaned[offset]);
      }
      final nextIndex = math.min(index + cleaned.length, 5);
      _focusOtpInput(nextIndex);
      HapticFeedback.selectionClick();
      return;
    }

    _writeDigit(index, cleaned[cleaned.length - 1]);
    if (index < 5) {
      _focusOtpInput(index + 1);
    } else {
      _focusOtpInput(index);
    }
    if (_complete) HapticFeedback.selectionClick();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
      _error = null;
      _mergeState = _OtpMergeState.checking;
    });
    _markController.reset();

    final responseFuture = auth.verifyOtp(widget.email, _otp);
    await _mergeController.forward(from: 0);
    final response = await responseFuture;
    if (!mounted) return;

    if (response['success'] == true) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _success = true;
        _mergeState = _OtpMergeState.success;
      });
      _markController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 820));
      if (!mounted) return;
      final role = response['role'] ?? 'citizen';
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.dashboardForRole(role?.toString()),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _mergeState = _OtpMergeState.failure;
      });
      _markController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 720));
      if (!mounted) return;
      await _mergeController.reverse();
      _markController.reset();
      if (!mounted) return;
      setState(() {
        _mergeState = _OtpMergeState.idle;
        _error =
            auth.error ?? AppStrings.t(context, 'Incorrect OTP. Try Again');
      });
      _shakeController.forward(from: 0);
      _focusOtpInput(_activeIndex);
    }
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
    final strokeWidth = size.width * 0.16;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth * 1.55
      ..color = Colors.white.withValues(alpha: 0.20 * progress);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = Colors.white;

    final path = isSuccess ? _checkPath(size) : _crossPath(size);
    _drawPathProgress(canvas, path, glowPaint, progress);
    _drawPathProgress(canvas, path, paint, progress);

    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.42
      ..color = Colors.white.withValues(alpha: 0.28 * progress);
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.18),
      Offset(size.width * 0.34, size.height * 0.08),
      shinePaint,
    );
  }

  Path _checkPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.18, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.84, size.height * 0.24);
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

class _AuthGlassBackground extends StatefulWidget {
  final Widget child;

  const _AuthGlassBackground({required this.child});

  @override
  State<_AuthGlassBackground> createState() => _AuthGlassBackgroundState();
}

class _AuthGlassBackgroundState extends State<_AuthGlassBackground> {
  bool _evictedOtpAsset = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_evictedOtpAsset) return;
    _evictedOtpAsset = true;
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
          height: screenHeight * 0.39,
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
