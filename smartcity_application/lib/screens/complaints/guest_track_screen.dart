import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';

class GuestTrackScreen extends StatefulWidget {
  const GuestTrackScreen({super.key});

  @override
  State<GuestTrackScreen> createState() => _GuestTrackScreenState();
}

class _GuestTrackScreenState extends State<GuestTrackScreen>
    with TickerProviderStateMixin {
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF64748B);

  final _complaintCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _complaintFocus = FocusNode();
  final _phoneFocus = FocusNode();

  late final AnimationController _shakeController;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _complaint;

  bool get _hasComplaintId => _complaintCtrl.text.trim().isNotEmpty;
  bool get _hasPhone => _phoneCtrl.text.trim().isNotEmpty;
  bool get _canTrack => _hasComplaintId && _hasPhone && !_isLoading;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _complaintCtrl.addListener(_onInputChanged);
    _phoneCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _complaintCtrl.removeListener(_onInputChanged);
    _phoneCtrl.removeListener(_onInputChanged);
    _shakeController.dispose();
    _complaintFocus.dispose();
    _phoneFocus.dispose();
    _complaintCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (!mounted) return;
    setState(() => _error = null);
  }

  Future<void> _track() async {
    if (!_hasComplaintId || !_hasPhone) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = AppStrings.t(
          context,
          'Please enter both complaint ID and mobile number',
        );
        _complaint = null;
      });
      _shakeController.forward(from: 0);
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _isLoading = true;
      _error = null;
      _complaint = null;
    });

    final response = await ApiService.post(
      ApiConfig.trackGuest,
      {
        'complaint_number': _complaintCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      },
      includeAuth: false,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response['success'] == true && response['complaint'] is Map) {
        _complaint = Map<String, dynamic>.from(response['complaint'] as Map);
      } else {
        _error =
            response['message'] ?? AppStrings.t(context, 'Complaint not found');
      }
    });

    if (_complaint != null) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: false,
      body: _TrackBackground(
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
              final contentTop = constraints.maxHeight *
                  (_complaint == null
                      ? (tallScreen ? 0.42 : 0.34)
                      : (tallScreen ? 0.24 : 0.18));
              return Padding(
                padding: EdgeInsets.only(bottom: keyboardLift),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: bottomInset > 0 || _complaint != null
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
                                child: Column(
                                  children: [
                                    _trackField(
                                      controller: _complaintCtrl,
                                      focusNode: _complaintFocus,
                                      hint: AppStrings.t(
                                        context,
                                        'Enter Complaint ID',
                                      ),
                                      icon: Icons.tag_rounded,
                                      valid: _hasComplaintId && _error == null,
                                      error: _error != null && !_hasComplaintId,
                                      onSubmitted: (_) =>
                                          _phoneFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: 12),
                                    _trackField(
                                      controller: _phoneCtrl,
                                      focusNode: _phoneFocus,
                                      hint: AppStrings.t(
                                        context,
                                        'Enter Mobile Number',
                                      ),
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      valid: _hasPhone && _error == null,
                                      error: _error != null && !_hasPhone,
                                      onSubmitted: (_) => _track(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _statusMessage(),
                              const SizedBox(height: 18),
                              _trackButton(),
                              if (_complaint != null) ...[
                                const SizedBox(height: 24),
                                _resultSection(_complaint!),
                              ],
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
            AppStrings.t(context, 'Track Request'),
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
          AppStrings.t(
            context,
            'Enter complaint ID and mobile number to view live status.',
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

  Widget _trackField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool valid = false,
    bool error = false,
    ValueChanged<String>? onSubmitted,
  }) {
    final borderColor = error
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
          width: error || valid ? 1.7 : 1.35,
        ),
        boxShadow: [
          if (error || valid)
            BoxShadow(
              color: (error ? _red : _green).withValues(alpha: 0.18),
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
          textInputAction:
              onSubmitted == null ? TextInputAction.done : TextInputAction.next,
          onSubmitted: onSubmitted,
          cursorColor: _ink,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFA3A7B4),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF8B90A0), size: 22),
            suffixIcon: error
                ? const Icon(Icons.cancel_rounded, color: _red, size: 23)
                : valid
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: _green,
                        size: 23,
                      )
                    : const SizedBox(width: 24),
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

  Widget _statusMessage() {
    if (_error != null) {
      return _messageCard(
        key: const ValueKey('track-error'),
        color: _red,
        icon: Icons.error_outline_rounded,
        title: AppStrings.t(context, 'Complaint not found'),
        text: _error!,
      );
    }
    if (_complaint != null) {
      return _messageCard(
        key: const ValueKey('track-found'),
        color: _green,
        icon: Icons.check_circle_outline_rounded,
        title: AppStrings.t(context, 'Complaint found'),
        text: AppStrings.t(context, 'Status loaded successfully.'),
      );
    }
    return _messageCard(
      key: const ValueKey('track-help'),
      color: _red,
      icon: Icons.info_outline_rounded,
      title: AppStrings.t(context, 'Guest tracking'),
      text: AppStrings.t(
        context,
        'Use the complaint ID from your submission receipt.',
      ),
    );
  }

  Widget _messageCard({
    required Key key,
    required Color color,
    required IconData icon,
    required String title,
    required String text,
  }) {
    final bg = color == _red
        ? const Color(0xFFFFF1F2)
        : color == _green
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF8FAFC);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
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
                    text,
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

  Widget _trackButton() {
    return GestureDetector(
      onTapDown: _canTrack ? (_) => HapticFeedback.selectionClick() : null,
      onTap: _canTrack ? _track : null,
      child: Opacity(
        opacity: _canTrack ? 1 : 0.62,
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B1020),
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
                                    AppStrings.t(context, 'TRACKING...'),
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                AppStrings.t(context, 'TRACK COMPLAINT'),
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

  Widget _resultSection(Map<String, dynamic> complaint) {
    final status = (complaint['work_status'] ?? 'pending').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultHeader(complaint, status),
        const SizedBox(height: 16),
        _infoGrid(complaint),
        const SizedBox(height: 18),
        _sectionTitle(
          AppStrings.t(context, 'Status Timeline'),
          Icons.timeline_rounded,
        ),
        const SizedBox(height: 12),
        _timeline(status, complaint),
        _proofSection(complaint),
        _mapSection(complaint),
      ],
    );
  }

  Widget _resultHeader(Map<String, dynamic> complaint, String status) {
    final color = _statusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6DEE9)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${complaint['complaint_number'] ?? ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppStrings.t(context, _statusLabel(status)),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _ink, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _infoGrid(Map<String, dynamic> complaint) {
    final items = [
      (AppStrings.t(context, 'Category'), _localizedComplaintType(complaint)),
      if (complaint['assigned_department'] != null)
        (
          AppStrings.t(context, 'Assigned To'),
          complaint['assigned_department'].toString()
        ),
      (
        AppStrings.t(context, 'Location'),
        '${complaint['city'] ?? ''}, ${complaint['pincode'] ?? ''}'.trim(),
      ),
      (
        AppStrings.t(context, 'Date Submitted'),
        (complaint['created_at'] ?? '').toString(),
      ),
      if ((complaint['resolved_at'] ?? '').toString().trim().isNotEmpty)
        (
          AppStrings.t(context, 'Resolved At'),
          (complaint['resolved_at'] ?? '').toString(),
        ),
      if ((complaint['resolution_notes'] ?? '').toString().trim().isNotEmpty)
        (
          AppStrings.t(context, 'Resolution Notes'),
          (complaint['resolution_notes'] ?? '').toString(),
        ),
      if ((complaint['citizen_rating'] ?? '').toString().trim().isNotEmpty)
        (
          AppStrings.t(context, 'Rating'),
          '${complaint['citizen_rating']}/5',
        ),
      (
        AppStrings.t(context, 'Contact Person'),
        (complaint['contact_name'] ?? '').toString(),
      ),
      (AppStrings.t(context, 'Mobile'), (complaint['mobile'] ?? '').toString()),
      (AppStrings.t(context, 'Email'), (complaint['email'] ?? '').toString()),
    ]
        .where((item) => item.$2.trim().isNotEmpty && item.$2.trim() != ',')
        .toList();

    return Column(
      children: items
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD6DEE9)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _proofSection(Map<String, dynamic> complaint) {
    final resolutionProofs = _listFrom(complaint, 'resolution_proofs');
    final reopenProofs = _listFrom(complaint, 'reopen_proofs');
    if (resolutionProofs.isEmpty && reopenProofs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        _sectionTitle(
          AppStrings.t(context, 'Proof Details'),
          Icons.verified_outlined,
        ),
        const SizedBox(height: 12),
        if (resolutionProofs.isNotEmpty) ...[
          _proofGrid(
            proofs: resolutionProofs,
            title: AppStrings.t(context, 'Completion Proof'),
          ),
        ],
        if (reopenProofs.isNotEmpty) ...[
          if (resolutionProofs.isNotEmpty) const SizedBox(height: 12),
          _reopenProofList(reopenProofs),
        ],
      ],
    );
  }

  Widget _proofGrid({
    required List<Map<String, dynamic>> proofs,
    required String title,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6DEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: proofs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: proofs.length == 1 ? 1 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: proofs.length == 1 ? 1.75 : 1.05,
            ),
            itemBuilder: (context, index) => _proofTile(proofs[index]),
          ),
        ],
      ),
    );
  }

  Widget _proofTile(Map<String, dynamic> proof) {
    final url = _proofUrl(proof);
    final fileType = (proof['file_type'] ?? '').toString().toLowerCase();
    final isVideo = fileType == 'video' ||
        url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.webm');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: url.isEmpty || isVideo ? null : () => _openProofViewer(url),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url.isNotEmpty && !isVideo)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _proofFallback(isVideo),
                  )
                else
                  _proofFallback(isVideo),
                Positioned(
                  left: 9,
                  right: 9,
                  bottom: 9,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatProofDate(proof['uploaded_at']).isEmpty
                          ? AppStrings.t(context, 'Proof')
                          : _formatProofDate(proof['uploaded_at']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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

  Widget _reopenProofList(List<Map<String, dynamic>> proofs) {
    return Column(
      children: proofs
          .map(
            (proof) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD6DEE9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t(context, 'Reopen Proof'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (proof['reason'] ?? '').toString().trim().isEmpty
                        ? AppStrings.t(context, 'No reason provided')
                        : proof['reason'].toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniPill(
                        (proof['requested_by_name'] ?? '').toString().isEmpty
                            ? AppStrings.t(context, 'Citizen')
                            : proof['requested_by_name'].toString(),
                        _ink,
                      ),
                      if (_formatProofDate(proof['created_at']).isNotEmpty)
                        _miniPill(
                          _formatProofDate(proof['created_at']),
                          _statusColor('confirmed'),
                        ),
                    ],
                  ),
                  if (_proofUrl(proof).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _proofViewButton(_proofUrl(proof)),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _miniPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _proofViewButton(String url) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openProofViewer(url),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD6DEE9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_outlined, color: _ink, size: 17),
              const SizedBox(width: 7),
              Text(
                AppStrings.t(context, 'View Proof'),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proofFallback(bool isVideo) {
    return Container(
      color: const Color(0xFFEFF4FA),
      child: Icon(
        isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined,
        color: _muted,
        size: 32,
      ),
    );
  }

  Widget _timeline(String status, Map<String, dynamic> complaint) {
    final steps = [
      _TimelineStep(
        AppStrings.t(context, 'Submitted'),
        _isCompleted(status, 'pending'),
        _statusColor('pending'),
        complaint['created_at'] ?? '',
        Icons.assignment_turned_in_outlined,
      ),
      _TimelineStep(
        AppStrings.t(context, 'Verified'),
        _isCompleted(status, 'confirmed'),
        _statusColor('confirmed'),
        _isCompleted(status, 'confirmed')
            ? (complaint['updated_at'] ?? '')
            : AppStrings.t(context, 'Pending'),
        Icons.verified_outlined,
      ),
      _TimelineStep(
        AppStrings.t(context, 'Assigned'),
        _isCompleted(status, 'process'),
        _statusColor('process'),
        _isCompleted(status, 'process')
            ? (complaint['updated_at'] ?? '')
            : AppStrings.t(context, 'Pending'),
        Icons.engineering_outlined,
      ),
      _TimelineStep(
        status == 'reopened'
            ? AppStrings.t(context, 'Reopened')
            : AppStrings.t(context, 'Resolved'),
        _isCompleted(status, 'solved'),
        _statusColor(status == 'reopened' ? 'reopened' : 'solved'),
        _isCompleted(status, 'solved')
            ? (complaint['updated_at'] ?? '')
            : AppStrings.t(context, 'Pending'),
        status == 'reopened' ? Icons.refresh_rounded : Icons.task_alt_rounded,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6DEE9)),
      ),
      child: Column(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: step.completed ? step.color : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: step.completed
                            ? Colors.transparent
                            : const Color(0xFFCBD5E1),
                        width: 1.6,
                      ),
                    ),
                    child: Icon(
                      step.completed ? Icons.check_rounded : step.icon,
                      size: 15,
                      color: step.completed ? Colors.white : _muted,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 38,
                      color: step.completed
                          ? step.color.withValues(alpha: 0.38)
                          : const Color(0xFFCBD5E1),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 14 : 20, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.date.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _mapSection(Map<String, dynamic> complaint) {
    final lat = _toDouble(complaint['latitude']);
    final lng = _toDouble(complaint['longitude']);
    if (lat == 0.0 && lng == 0.0) return const SizedBox.shrink();

    final position = LatLng(lat, lng);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        _sectionTitle(
          AppStrings.t(context, 'Complaint Location'),
          Icons.location_on_outlined,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(initialCenter: position, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.janhelp.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: position,
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.location_pin,
                        color: _red,
                        size: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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

  String _localizedComplaintType(Map<String, dynamic> complaint) {
    final display =
        (complaint['complaint_type_display'] ?? '').toString().trim();
    if (display.isNotEmpty) return AppStrings.t(context, display);
    final code = (complaint['complaint_type'] ?? '').toString().trim();
    return AppStrings.t(context, _categoryKeyToText(code));
  }

  String _categoryKeyToText(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'police':
        return 'Police';
      case 'traffic':
        return 'Traffic';
      case 'construction':
        return 'Construction';
      case 'water':
      case 'water supply':
        return 'Water Supply';
      case 'electricity':
        return 'Electricity';
      case 'garbage':
        return 'Garbage';
      case 'road':
      case 'pothole':
        return 'Road / Pothole';
      case 'drainage':
        return 'Drainage';
      case 'illegal':
      case 'illegal activity':
        return 'Illegal Activity';
      case 'transportation':
        return 'Transportation';
      case 'cyber':
      case 'cyber crime':
        return 'Cyber Crime';
      default:
        return categoryKey;
    }
  }

  bool _isCompleted(String current, String step) {
    const order = ['pending', 'confirmed', 'process', 'solved', 'reopened'];
    final currentIndex = order.indexOf(current);
    final stepIndex = order.indexOf(step);
    if (step == 'solved') return current == 'solved' || current == 'reopened';
    return currentIndex >= stepIndex && stepIndex != -1;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Submitted';
      case 'confirmed':
        return 'Verified';
      case 'process':
        return 'Assigned';
      case 'solved':
        return 'Resolved';
      case 'reopened':
        return 'Reopened';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFEF4444);
      case 'confirmed':
        return const Color(0xFFF97316);
      case 'process':
        return const Color(0xFFEAB308);
      case 'solved':
        return const Color(0xFF22C55E);
      case 'reopened':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  List<Map<String, dynamic>> _listFrom(
    Map<String, dynamic> complaint,
    String key,
  ) {
    final raw = complaint[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _proofUrl(Map<String, dynamic> proof) {
    final raw = (proof['file_url'] ??
            proof['proof_url'] ??
            proof['file'] ??
            proof['proof'] ??
            '')
        .toString()
        .trim();
    if (raw.isEmpty || raw.startsWith('http')) return raw;
    final apiRoot = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return raw.startsWith('/') ? '$apiRoot$raw' : raw;
  }

  String _formatProofDate(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year} $hour:$minute';
  }

  void _openProofViewer(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: InteractiveViewer(
            minScale: 0.7,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: Colors.white,
                alignment: Alignment.center,
                child: Text(
                  AppStrings.t(context, 'Unable to load proof'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                  ),
                ),
              ),
            ),
          ),
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

class _TimelineStep {
  final String label;
  final bool completed;
  final Color color;
  final dynamic date;
  final IconData icon;

  const _TimelineStep(
    this.label,
    this.completed,
    this.color,
    this.date,
    this.icon,
  );
}

class _TrackBackground extends StatefulWidget {
  final Widget child;

  const _TrackBackground({required this.child});

  @override
  State<_TrackBackground> createState() => _TrackBackgroundState();
}

class _TrackBackgroundState extends State<_TrackBackground> {
  bool _evictedTrackAsset = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_evictedTrackAsset) return;
    _evictedTrackAsset = true;
    const AssetImage('assets/images/track_status_121826_bg.png').evict();
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
          top: screenHeight * 0.01,
          height: screenHeight * 0.40,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Image.asset(
                'assets/images/track_status_121826_bg.png',
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
