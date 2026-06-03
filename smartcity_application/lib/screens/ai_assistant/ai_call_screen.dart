import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/deepgram_stt_call_service.dart';

class AICallScreen extends StatefulWidget {
  const AICallScreen({super.key});

  @override
  State<AICallScreen> createState() => _AICallScreenState();
}

class _AICallScreenState extends State<AICallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  late final DeepgramSttCallService _deepgram;

  bool _muted = false;
  bool _speakerOn = true;
  bool _connecting = true;
  bool _active = false;
  bool _listening = false;
  String _status = 'Connecting';
  String _liveTranscript = '';
  String _finalTranscript = '';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _deepgram = DeepgramSttCallService()
      ..onStatus = _handleDeepgramStatus
      ..onConnected = _handleDeepgramConnected
      ..onListening = _handleDeepgramListening
      ..onTranscript = _handleDeepgramTranscript;

    _startDeepgramCall();
  }

  @override
  void dispose() {
    _deepgram.stop();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _startDeepgramCall() async {
    final started = await _deepgram.start();
    if (!mounted) return;
    if (!started) {
      setState(() {
        _connecting = false;
        _active = false;
        _listening = false;
      });
    }
  }

  void _handleDeepgramStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  void _handleDeepgramConnected(bool connected) {
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _active = connected;
      if (!connected) _listening = false;
    });
  }

  void _handleDeepgramListening(bool listening) {
    if (!mounted) return;
    setState(() => _listening = listening);
  }

  void _handleDeepgramTranscript(String transcript, bool isFinal) {
    if (!mounted || transcript.trim().isEmpty) return;
    setState(() {
      _liveTranscript = transcript.trim();
      if (isFinal) {
        _finalTranscript = transcript.trim();
      }
    });
  }

  Future<void> _endCall() async {
    HapticFeedback.mediumImpact();
    await _deepgram.stop();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _toggleMute() async {
    HapticFeedback.selectionClick();
    final nextMuted = !_muted;
    setState(() {
      _muted = nextMuted;
      _status = nextMuted ? 'Muted' : 'Listening';
    });
    await _deepgram.setMuted(nextMuted);
  }

  void _toggleSpeaker() {
    HapticFeedback.selectionClick();
    setState(() {
      _speakerOn = !_speakerOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            children: [
              Row(
                children: [
                  _buildTopButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: _endCall,
                  ),
                  const Spacer(),
                  _buildStatusPill(),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 230,
                          height: 230,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildWaveRings(),
                              _buildLogoAvatar(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'JanHelp AI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            color: const Color(0xFF09090B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildTranscriptPanel(),
                      ],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildControlButton(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      tooltip: _muted ? 'Unmute' : 'Mute',
                      active: _muted,
                      onTap: _active || _connecting ? _toggleMute : null,
                    ),
                    _buildControlButton(
                      icon: Icons.call_end_rounded,
                      tooltip: 'End call',
                      danger: true,
                      onTap: _endCall,
                    ),
                    _buildControlButton(
                      icon: _speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      tooltip: _speakerOn ? 'Speaker on' : 'Speaker off',
                      active: _speakerOn,
                      onTap: _active || _connecting ? _toggleSpeaker : null,
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

  Widget _buildStatusPill() {
    final text = _connecting
        ? 'Connecting'
        : _muted
            ? 'Muted'
            : _listening
                ? 'Listening'
                : 'Active';
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _connecting
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptPanel() {
    final text = _liveTranscript.isNotEmpty
        ? _liveTranscript
        : _finalTranscript.isNotEmpty
            ? _finalTranscript
            : 'Speak now. Deepgram will show the transcript here.';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 18,
                color: _listening
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                'Deepgram STT',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.35,
              fontWeight:
                  _liveTranscript.isEmpty ? FontWeight.w600 : FontWeight.w800,
              color: _liveTranscript.isEmpty
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoAvatar() {
    return Container(
      width: 128,
      height: 128,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.smart_toy_rounded,
          size: 54,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildWaveRings() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final base = _waveController.value;
        return Stack(
          alignment: Alignment.center,
          children: List.generate(4, (index) {
            final progress = (base + index / 4) % 1.0;
            final size = 118.0 + (progress * 112.0);
            final alpha = (1.0 - progress).clamp(0.0, 1.0) * 0.24;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF111827).withValues(alpha: alpha),
                  width: 1.6,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTapDown: (_) => HapticFeedback.selectionClick(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF111827)),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool active = false,
    bool danger = false,
  }) {
    final enabled = onTap != null;
    final dark = active && !danger;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTapDown: enabled ? (_) => HapticFeedback.selectionClick() : null,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: Container(
            width: danger ? 78 : 66,
            height: danger ? 78 : 66,
            decoration: BoxDecoration(
              color: danger || dark ? null : Colors.white,
              shape: BoxShape.circle,
              gradient: danger
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    )
                  : dark
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
                        )
                      : null,
              boxShadow: [
                BoxShadow(
                  color: (danger ? const Color(0xFFEF4444) : Colors.black)
                      .withValues(alpha: danger ? 0.25 : 0.08),
                  blurRadius: danger ? 30 : 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: danger ? 30 : 25,
              color: danger || dark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }
}
