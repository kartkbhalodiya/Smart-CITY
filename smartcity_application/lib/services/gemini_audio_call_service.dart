import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart' as pcm;
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_conversation_manager.dart';
import 'gemini_live_call_service.dart';

typedef CallStatusCallback = void Function(String status);
typedef CallBoolCallback = void Function(bool value);
typedef CallTranscriptCallback = void Function(String role, String text, bool isFinal);

class GeminiAudioCallService {
  static const String _audioModel = 'gemini-2.5-flash-native-audio-preview-12-2025';
  static const String _endpoint =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?alt=ws';
  static const int _outRate = 24000;
  static const int _outChunk = 480;
  static const int _inRate = 16000;
  static const int _inBuf = 512;
  static const String _voice = 'Kore';
  static const int _notifId = 9901;

  static final _notifs = FlutterLocalNotificationsPlugin();
  static bool _notifsReady = false;

  final List<int> _buf = [];
  final CallConversationManager _conv = CallConversationManager();
  String _userName = '';

  WebSocket? _ws;
  StreamSubscription? _wsSub;
  final FlutterAudioCapture _mic = FlutterAudioCapture();
  bool _micOn = false;
  Completer<void>? _setupDone;
  String? _lastErr;

  bool _pcmReady = false;
  bool _closed = false;
  bool _speaking = false;
  bool _muted = false;
  bool _speakerOn = true;
  bool _greetingDone = false;
  Timer? _keepAlive;
  Timer? _silenceTimer;
  Timer? _echoGraceTimer;
  String _lastCity = '';

  // SIMPLE MIC GATE: Don't send mic audio while AI is speaking (prevents echo)
  // After AI stops → 300ms grace → mic opens
  bool _micGated = false;

  // Throttle _setSpeaking callbacks to avoid saturating BLASTBufferQueue
  // (max one UI update per 100ms prevents excessive frame buffer allocation)
  DateTime? _lastSpeakingUpdate;

  // Track overlap events without cutting off active AI playback.
  bool _wasInterrupted = false;
  String _lastAIUtterance = '';
  final List<Map<String, String>> _conversationHistory = [];

  CallStatusCallback? onStatus;
  CallBoolCallback? onListening;
  CallBoolCallback? onSpeaking;
  CallBoolCallback? onConnected;
  CallTranscriptCallback? onTranscript;
  void Function(VoiceCallStage)? onStageChanged;
  void Function(bool)? onInterrupted;

  set onListeningChanged(CallBoolCallback? v) => onListening = v;
  set onSpeakingChanged(CallBoolCallback? v) => onSpeaking = v;
  set onConnectedChanged(CallBoolCallback? v) => onConnected = v;

  String _userTx = '';
  String _aiTx = '';
  bool get wasInterrupted => _wasInterrupted;
  String get lastAIUtterance => _lastAIUtterance;
  List<Map<String, String>> get conversationHistory => List.unmodifiable(_conversationHistory);

  bool get isCapturing => _micOn;
  VoiceCallStage get conversationStage => _conv.stage;
  VoiceComplaintDraft get complaintDraft => _conv.draft;
  CallConversationManager get callConversationManager => _conv;

  /// Inject a system event into the AI mid-call via clientContent.
  /// Only safe to call when mic is already streaming (greetingDone).
  void injectSystemEvent(String text) {
    if (_ws == null || _closed) return;
    try {
      _ws!.add(jsonEncode({
        'clientContent': {
          'turns': [{
            'role': 'user',
            'parts': [{'text': text}],
          }],
          'turnComplete': true,
        },
      }));
    } catch (_) {}
  }

  // ── Shared setup payload ───────────────────────────────────────────────────
  Map<String, dynamic> _setupPayload({required String city, String? email, String? phone}) => {
    'setup': {
      'model': 'models/$_audioModel',
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'temperature': 0.25,
        'topP': 0.75,
        'topK': 25,
        'maxOutputTokens': 500,
        'candidateCount': 1,
        'speechConfig': {
          'voiceConfig': {'prebuiltVoiceConfig': {'voiceName': _voice}},
        },
      },
      'inputAudioTranscription': {},
      'outputAudioTranscription': {},
      'realtimeInputConfig': {
        'automaticActivityDetection': {
          'disabled': false,
          'startOfSpeechSensitivity': 'START_SENSITIVITY_HIGH',
          'endOfSpeechSensitivity': 'END_SENSITIVITY_LOW',
          'prefixPaddingMs': 200,
          'silenceDurationMs': 1000,
        },
      },
      'systemInstruction': {
        'parts': [{'text': _prompt(userName: _userName, city: city, email: email, phone: phone)}],
      },
    },
  };

  // ── Start ─────────────────────────────────────────────────────────────────
  Future<bool> startCall({
    required String userName, 
    required String city,
    String? email,
    String? phone,
  }) async {
    // Force complete cleanup first
    _closed = true;
    await stopCall();
    await Future.delayed(const Duration(milliseconds: 500));
    
    _closed = false;
    _userName = userName.trim().isEmpty ? 'ji' : userName.trim();
    _lastCity = city;
    _conv.reset();

    final key = await GeminiLiveCallService.getApiKey();
    if (key == null || key.isEmpty) { 
      onStatus?.call('Gemini key missing'); 
      return false; 
    }

    await _setupPcm();

    try {
      _setupDone = Completer();
      debugPrint('[GeminiAudio] Connecting to Gemini...');
      _ws = await WebSocket.connect('$_endpoint&key=$key').timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );
      
      debugPrint('[GeminiAudio] WebSocket connected');
      _wsSub = _ws!.listen(_onMsg, onDone: _onDone, onError: _onErr, cancelOnError: false);

      debugPrint('[GeminiAudio] Sending setup payload...');
      _ws!.add(jsonEncode(_setupPayload(city: city, email: email, phone: phone)));

      await _setupDone!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Setup timeout'),
      );
      debugPrint('[GeminiAudio] Setup complete');

      onConnected?.call(true);
      onStatus?.call('Connected');

      _greetingDone = false;
      // Welcome message — warm, short, friendly
      _ws!.add(jsonEncode({
        'clientContent': {
          'turns': [{
            'role': 'user',
            'parts': [{'text': '[Say this greeting warmly: "Hellooo! Namaste ji! Main Priya, JANHELP helpline se. Batao, Hindi, English, Gujarati, ya Hinglish mein baat karein?" STOP. WAIT for answer. Say nothing else.]'}],
          }],
          'turnComplete': true,
        },
      }));
      debugPrint('[GeminiAudio] Friendly greeting sent');

      unawaited(_showNotif());
      _startKeepAlive();
      return true;
    } catch (e) {
      debugPrint('[GeminiAudio] startCall error: $e');
      _lastErr = e.toString();
      onStatus?.call(_friendly(_lastErr!));
      await stopCall();
      return false;
    }
  }

  // ── Stop ──────────────────────────────────────────────────────────────────
  Future<void> stopCall() async {
    _closed = true;
    _keepAlive?.cancel(); _keepAlive = null;
    _silenceTimer?.cancel(); _silenceTimer = null;
    _echoGraceTimer?.cancel(); _echoGraceTimer = null;
    _micGated = false;
    await _stopMic();
    try { await _wsSub?.cancel(); } catch (_) {}
    try { await _ws?.close(); } catch (_) {}
    _ws = null; _wsSub = null; _setupDone = null;
    _buf.clear(); _setSpeaking(false);
    onListening?.call(false); onConnected?.call(false);
    _userTx = ''; _aiTx = ''; _lastErr = null; _greetingDone = false;
    _wasInterrupted = false; _lastAIUtterance = '';
    _conversationHistory.clear();
    _conv.reset(); _userName = '';
    unawaited(_cancelNotif());
    if (_pcmReady) {
      try { await pcm.FlutterPcmSound.release(); } catch (_) {}
      _pcmReady = false;
    }
  }

  // ── Mute / Speaker ────────────────────────────────────────────────────────
  Future<void> setMuted(bool v) async {
    _muted = v;
    if (v) { await _stopMic(); onListening?.call(false); onStatus?.call('Mic muted'); }
    else   { await _startMic(); onListening?.call(true);  onStatus?.call('Mic on'); }
  }

  Future<void> setSpeakerEnabled(bool v) async {
    _speakerOn = v;
    if (!v) { _buf.clear(); _setSpeaking(false); }
  }

  Future<void> startMicCapture() async => _startMic();
  Future<void> stopMicCapture()  async => _stopMic();
  Future<void> sendUserTurn(String t) async {}
  Future<void> sendContextHint(String t) async {}

  // ── Hmm tone (thinking sound played while AI processes) ────────────────
  // Generates a soft 180ms voiced hum at ~180Hz — sounds like "hmmm"
  static List<int> _buildHmmTone() {
    const rate = 24000;
    const durationMs = 180;
    const samples = rate * durationMs ~/ 1000; // 4320 samples
    const freq = 180.0;
    const amp = 2800; // soft, not loud
    final out = <int>[];
    for (var i = 0; i < samples; i++) {
      final t = i / rate;
      // fundamental + slight 2nd harmonic for warmth
      final v = (amp * (0.7 * _sin(2 * 3.14159265 * freq * t) +
                        0.3 * _sin(2 * 3.14159265 * freq * 2 * t))).round().clamp(-32768, 32767);
      out.add(v);
    }
    // 40ms fade-out
    const fadeStart = samples - rate * 40 ~/ 1000;
    for (var i = fadeStart; i < samples; i++) {
      out[i] = (out[i] * (samples - i) / (samples - fadeStart)).round();
    }
    return out;
  }

  static double _sin(double x) {
    // Taylor series sin — avoids dart:math import just for this
    x = x % (2 * 3.14159265);
    if (x > 3.14159265) x -= 2 * 3.14159265;
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }

  void _playHmm() {
    if (!_pcmReady || !_speakerOn || _closed) return;
    _buf.addAll(_buildHmmTone());
    _setSpeaking(true);
    unawaited(_feed());
  }

  Future<void> _setupPcm() async {
    if (_pcmReady) return;
    await pcm.FlutterPcmSound.setup(
      sampleRate: _outRate, channelCount: 1,
      iosAudioCategory: pcm.IosAudioCategory.playAndRecord,
    );
    await pcm.FlutterPcmSound.setFeedThreshold(_outChunk);
    pcm.FlutterPcmSound.setFeedCallback((_) async { await _feed(); });
    pcm.FlutterPcmSound.start();
    _pcmReady = true;
  }

  Future<void> _feed() async {
    if (!_pcmReady || _buf.isEmpty) { 
      if (_speaking) {
        _setSpeaking(false);
        // AI finished speaking — gate mic for 300ms to let echo decay
        _micGated = true;
        _echoGraceTimer?.cancel();
        _echoGraceTimer = Timer(const Duration(milliseconds: 300), () {
          _micGated = false;
          _echoGraceTimer = null;
          debugPrint('[GeminiAudio] Mic gate opened — listening');
        });
        debugPrint('[GeminiAudio] AI done — mic gated 300ms for echo decay');
      }
      return; 
    }
    final n = _buf.length < _outChunk ? _buf.length : _outChunk;
    final chunk = _buf.sublist(0, n);
    _buf.removeRange(0, n);
    try { await pcm.FlutterPcmSound.feed(pcm.PcmArrayInt16.fromList(chunk)); }
    catch (e) { debugPrint('[GeminiAudio] feed error: $e'); }
  }

  // ── Mic ───────────────────────────────────────────────────────────────────
  Future<void> _startMic() async {
    if (_micOn || _closed || _muted) return;
    try {
      if (!(await Permission.microphone.isGranted)) {
        if (!(await Permission.microphone.request()).isGranted) return;
      }
      await _mic.init();
      await _mic.start((dynamic raw) {
        if (_ws == null || _closed) return;
        // SIMPLE & CLEAN: Don't send audio while AI speaks or during echo grace.
        // When mic is open, send audio with basic noise floor filter.
        if (_speaking || _buf.isNotEmpty || _micGated) return;
        try {
          final floats = _toFloats(raw);
          if (floats == null || floats.isEmpty) return;
          // Basic noise floor: skip chunks where max amplitude < 0.005
          // Only filters complete dead silence — lets ALL speech through
          double maxAmp = 0.0;
          for (final s in floats) {
            final a = s < 0 ? -s : s;
            if (a > maxAmp) maxAmp = a;
          }
          if (maxAmp < 0.005) return; // absolute silence — don't send
          final i16 = Int16List(floats.length);
          for (var i = 0; i < floats.length; i++) {
            i16[i] = (floats[i] * 32767).round().clamp(-32768, 32767);
          }
          _ws!.add(jsonEncode({
            'realtimeInput': {
              'mediaChunks': [{'mimeType': 'audio/pcm;rate=$_inRate', 'data': base64Encode(i16.buffer.asUint8List())}],
            },
          }));
        } catch (_) {}
      }, (_) {}, sampleRate: _inRate, bufferSize: _inBuf);
      _micOn = true;
      debugPrint('[GeminiAudio] mic started — simple gate mode');
    } catch (e) {
      debugPrint('[GeminiAudio] mic start error: $e');
    }
  }

  Future<void> _stopMic() async {
    if (!_micOn) return;
    try { await _mic.stop(); } catch (_) {}
    _micOn = false;
  }

  Float32List? _toFloats(dynamic raw) {
    if (raw is Float32List) return raw;
    if (raw is List) return Float32List.fromList(raw.map((e) => (e as num).toDouble()).toList());
    if (raw is Uint8List) return raw.buffer.asFloat32List();
    return null;
  }

  // ── Socket ────────────────────────────────────────────────────────────────
  void _onMsg(dynamic raw) async {
    try {
      final s = raw is String ? raw : utf8.decode(raw as List<int>);
      final m = jsonDecode(s) as Map<String, dynamic>?;
      if (m == null) return;

      if (m.containsKey('setupComplete')) {
        if (_setupDone != null && !_setupDone!.isCompleted) _setupDone!.complete();
        _setupDone = null;
        return;
      }

      if (m.containsKey('goAway')) {
        final r = m['goAway'];
        _lastErr = (r is Map ? (r['reason'] ?? r['message'] ?? '') : '$r').toString();
        _setupDone?.completeError(_lastErr!);
        onStatus?.call(_friendly(_lastErr!));
        return;
      }

      final sc = m['serverContent'];
      if (sc is! Map<String, dynamic>) return;

      _rxTranscript(sc['inputTranscription'] ?? sc['input_transcription'], 'user');
      _rxTranscript(sc['outputTranscription'] ?? sc['output_transcription'], 'assistant');

      // If Gemini detects overlapping user speech while AI is talking,
      // keep the current assistant audio playing instead of cutting it off.
      if (sc['interrupted'] == true) {
        _wasInterrupted = true;
        _lastAIUtterance = _aiTx; // Save what AI was saying when interrupted
        onInterrupted?.call(true);
        debugPrint('[GeminiAudio] Overlap detected while AI speaking - continuing playback');
      }

      final mt = sc['modelTurn'];
      if (mt is Map<String, dynamic>) {
        final parts = mt['parts'];
        if (parts is List) {
          for (final p in parts) {
            if (p is! Map<String, dynamic>) continue;

            final id = p['inlineData'];
            if (id is Map<String, dynamic>) {
              final mime = (id['mimeType'] ?? '').toString();
              final data = (id['data'] ?? '').toString();
              if (mime.startsWith('audio/pcm') && data.isNotEmpty) _rxAudio(data);
            }
          }
        }
      }

      if (sc['turnComplete'] == true) {
        final wasUserTurn = _userTx.isNotEmpty;
        await _finalize(); // Run synchronously — stage must change before AI responds
        if (!_greetingDone && !_closed && !_muted) {
          _greetingDone = true;
          // Short delay for greeting echo to decay, then start mic
          await Future.delayed(const Duration(milliseconds: 800));
          if (!_closed && !_muted) {
            unawaited(_startMic());
            onListening?.call(true);
          }
        }
        // Play hmm tone only if:
        // - User spoke AND it wasn't an interruption
        // - NOT a language switch turn (hmm interferes with AI's language response)
        final isLangSwitch = _conv.stage == VoiceCallStage.problem && wasUserTurn;
        if (_greetingDone && !_closed && wasUserTurn && !_wasInterrupted && !isLangSwitch) _playHmm();
        // Reset interruption flag after processing
        if (_wasInterrupted) {
          _wasInterrupted = false;
          onInterrupted?.call(false);
        }
        // AI finished speaking — start silence watch
        if (_greetingDone && !_closed) _resetSilenceTimer();
      }
    } catch (e) {
      debugPrint('[GeminiAudio] parse error: $e');
    }
  }

  void _rxTranscript(dynamic src, String role) {
    final t = _readTranscriptText(src, role);
    if (t == null) return;
    if (role == 'user') {
      _silenceTimer?.cancel();
      _userTx = _mergeUserTranscriptCandidate(_userTx, t);
      onTranscript?.call('user', _userTx, false);
      debugPrint('[GeminiAudio] 🎤 USER SAID: "$t" | current stage: ${_conv.stage}');
      // IMMEDIATELY process stage transition when user transcript arrives
      _processStageNow(_userTx);
    } else {
      // Append streaming chunks, but prevent duplication if full string arrives
      if ((t.length >= _aiTx.length && t.contains(_aiTx)) || _aiTx.isEmpty) {
        _aiTx = t;
      } else if (!_aiTx.endsWith(t)) {
        _aiTx += t;
      }
      onTranscript?.call('assistant', _aiTx, false);
    }
  }

  /// Process stage transition immediately — called when user transcript arrives.
  /// This ensures UI buttons appear before AI's response mentions them.
  void _processStageNow(String tx) {
    // Check if this is a follow-up question
    final isFollowUp = _conv.isFollowUpQuestion(tx);
    if (isFollowUp) {
      debugPrint('[GeminiAudio] Follow-up question: "$tx" — stage stays at ${_conv.stage}');
      return;
    }
    // Process transcript for stage advancement (synchronous for instant UI)
    final prev = _conv.stage;
    _conv.processUserTranscriptSync(tx);
    if (_conv.stage != prev) {
      debugPrint('[GeminiAudio] ✅ STAGE CHANGED: $prev → ${_conv.stage} (instant)');
      onStageChanged?.call(_conv.stage);
    }
  }

  void _rxAudio(String b64) {
    if (!_speakerOn) return;
    final bytes = base64Decode(b64);
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) _buf.add(bd.getInt16(i, Endian.little));
    if (_buf.isNotEmpty) { _setSpeaking(true); unawaited(_feed()); }
  }

  Future<void> _finalize() async {
    if (_userTx.isNotEmpty) {
      final tx = _userTx;
      _userTx = ''; // clear FIRST — prevent double-processing
      
      // Save to conversation history
      _conversationHistory.add({'role': 'user', 'text': tx});
      if (_conversationHistory.length > 20) _conversationHistory.removeRange(0, 2);
      
      // Stage was already processed in _processStageNow — just update display
      onTranscript?.call('user', tx, true);
    }
    if (_aiTx.isNotEmpty) {
      // Save AI response to conversation history
      _conversationHistory.add({'role': 'assistant', 'text': _aiTx});
      if (_conversationHistory.length > 20) _conversationHistory.removeRange(0, 2);
      _lastAIUtterance = _aiTx;
      onTranscript?.call('assistant', _aiTx, true);
      _aiTx = '';
    }
  }

  // ── Socket events ─────────────────────────────────────────────────────────
  void _onDone() {
    final code = _ws?.closeCode; final reason = _ws?.closeReason ?? '';
    final d = [if (code != null) 'code $code', if (reason.isNotEmpty) reason].join(': ');
    debugPrint('[GeminiAudio] socket done: $d');
    
    if (_setupDone != null && !_setupDone!.isCompleted) {
      _setupDone!.completeError(d.isEmpty ? 'Socket closed' : d);
    }
    
    // Only reconnect if call was active and not intentionally closed
    if (!_closed && _greetingDone) {
      debugPrint('[GeminiAudio] Unexpected disconnect, reconnecting...');
      onStatus?.call('Reconnecting...');
      unawaited(_reconnect());
    } else {
      debugPrint('[GeminiAudio] Call ended normally');
      onStatus?.call('Call ended');
      onConnected?.call(false);
      _setSpeaking(false);
    }
  }

  void _onErr(Object e) {
    debugPrint('[GeminiAudio] socket error: $e');
    _lastErr = e.toString();
    
    if (_setupDone != null && !_setupDone!.isCompleted) {
      _setupDone!.completeError(_lastErr!);
    }
    
    // Only reconnect if call was active and not intentionally closed
    if (!_closed && _greetingDone) {
      debugPrint('[GeminiAudio] Error during active call, reconnecting...');
      onStatus?.call('Reconnecting...');
      unawaited(_reconnect());
    } else {
      debugPrint('[GeminiAudio] Error during setup: $_lastErr');
      onStatus?.call('Connection failed');
      onConnected?.call(false);
      _setSpeaking(false);
    }
  }

  Future<void> _reconnect() async {
    _keepAlive?.cancel(); _keepAlive = null;
    _echoGraceTimer?.cancel(); _echoGraceTimer = null;
    _micGated = false;
    try { await _wsSub?.cancel(); } catch (_) {}
    try { await _ws?.close(); } catch (_) {}
    _ws = null; _wsSub = null;
    _buf.clear(); _setSpeaking(false);
    await _stopMic();
    _greetingDone = false;

    await Future.delayed(const Duration(seconds: 2));
    if (_closed) return;

    final key = await GeminiLiveCallService.getApiKey();
    if (key == null || key.isEmpty || _closed) return;

    try {
      _setupDone = Completer();
      _ws = await WebSocket.connect('$_endpoint&key=$key');
      _wsSub = _ws!.listen(_onMsg, onDone: _onDone, onError: _onErr, cancelOnError: false);
      _ws!.add(jsonEncode(_setupPayload(
        city: _lastCity, 
        email: _conv.draft.contactEmail, 
        phone: _conv.draft.contactPhone,
      )));
      await _setupDone!.future.timeout(const Duration(seconds: 12));
      onStatus?.call('Reconnected');
      _ws!.add(jsonEncode({
        'clientContent': {
          'turns': [{
            'role': 'user',
            'parts': [{'text': '[Reconnected. Continue. NO re-greet.]'}],
          }],
          'turnComplete': true,
        },
      }));
      _startKeepAlive();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_muted && !_closed) { await _startMic(); onListening?.call(true); }
      _greetingDone = true;
    } catch (e) {
      debugPrint('[GeminiAudio] reconnect failed: $e');
      onStatus?.call('Call disconnected');
      onConnected?.call(false);
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    if (_closed || !_greetingDone || _ws == null) return;
    // Don't fire silence check during UI-action stages or after submission
    final stage = _conv.stage;
    if (stage == VoiceCallStage.locationMap ||
        stage == VoiceCallStage.proof ||
        stage == VoiceCallStage.submitting ||
        stage == VoiceCallStage.done) return;
    // Shorter timeout for faster flow
    final timeoutSec = 10;
    _silenceTimer = Timer(Duration(seconds: timeoutSec), () {
      if (_closed || _ws == null) return;
      // Don't interrupt if AI is still speaking
      if (_speaking) { _resetSilenceTimer(); return; }
      final name = _userName.trim().isEmpty ? 'ji' : _userName.trim();
      _ws!.add(jsonEncode({
        'clientContent': {
          'turns': [{
            'role': 'user',
            'parts': [{'text': '[Silent. Say: "$name ji, sab theek?" ONLY.]'}],
          }],
          'turnComplete': true,
        },
      }));
    });
  }

  void _startKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_ws == null || _closed) return;
      try {
        final silence = Uint8List(640); // 20ms silence at 16kHz
        _ws!.add(jsonEncode({
          'realtimeInput': {
            'mediaChunks': [{'mimeType': 'audio/pcm;rate=$_inRate', 'data': base64Encode(silence)}],
          },
        }));
      } catch (_) {}
    });
  }

  void _setSpeaking(bool v) {
    if (_speaking == v) return;
    _speaking = v;
    // Throttle UI callback — at most once per 100ms to prevent BLASTBufferQueue overflow
    final now = DateTime.now();
    if (_lastSpeakingUpdate == null ||
        now.difference(_lastSpeakingUpdate!) >= const Duration(milliseconds: 100)) {
      _lastSpeakingUpdate = now;
      onSpeaking?.call(v);
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  static Future<void> _initNotifs() async {
    if (_notifsReady) return;
    await _notifs.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _notifsReady = true;
  }

  Future<void> _showNotif() async {
    await _initNotifs();
    await _notifs.show(_notifId, 'JANHELP AI Call', 'Call in progress — tap to return',
      const NotificationDetails(android: AndroidNotificationDetails(
        'janhelp_call', 'AI Voice Call',
        channelDescription: 'JANHELP live AI call',
        importance: Importance.low, priority: Priority.low,
        ongoing: true, autoCancel: false,
      )));
  }

  Future<void> _cancelNotif() async { await _notifs.cancel(_notifId); }

  // ── System prompt ─────────────────────────────────────────────────────────
  String _prompt({required String userName, required String city, String? email, String? phone}) {
    final hasEmail = (email?.isNotEmpty ?? false) && email != 'Not Provided';
    final hasPhone = (phone?.isNotEmpty ?? false) && phone != 'Not Provided';
    
    return '''
You are Priya — a warm, caring female assistant at JANHELP helpline in $city.

CURRENT USER PROFILE:
- Name: $userName
- Email: ${hasEmail ? email : 'MISSING'}
- Phone: ${hasPhone ? phone : 'MISSING'}

PERSONALITY:
- Speak naturally like a real Indian girl — warm, empathetic, conversational
- Use natural pauses and expressions: "Hmmm...", "Achha...", "Arre...", "Haan ji..."
- Show genuine concern: "Ohh! Yeh toh serious hai!", "Arre baap re!", "Haan samajh gayi!"
- Speak at NATURAL HUMAN PACE — not too fast, not robotic
- ALWAYS complete full sentences — never cut mid-word
- Be empathetic but efficient
- Never reveal internal analysis, planning, markdown headings, or hidden notes
- Speak only the exact sentence the caller should hear

━━━ PROFILE AWARENESS & CONTACT DETAILS ━━━
BEFORE confirming the complaint:
1. If Name or Phone is missing in the profile, ask for them one by one.
2. Email is helpful but OPTIONAL for voice complaints.
3. If a detail is already available in the profile, do not ask for it again.
4. Never block complaint submission only because email is missing.

━━━ OVERLAP HANDLING ━━━
If the user starts speaking while you are already speaking:
1. FINISH your current sentence naturally. Do not cut yourself off mid-response.
2. Keep your reply concise and complete.
3. After you finish, listen to the user's latest point and answer it.
4. Then continue the complaint flow from the same stage if needed.

NEVER restart the whole flow because of overlapping speech.
Treat overlap naturally, but prioritize completing your current sentence first.

━━━ FOLLOW-UP QUESTIONS (ANYTIME) ━━━
User may ask questions at ANY point during the complaint flow:
- "Kitne din mein solve hoga?" → Answer: "Usually 3-7 din mein department action leta hai."
- "Kaunsa department dekhega?" → Answer based on complaint category
- "Kya complaint anonymous ho sakti hai?" → Answer: "Haan, name optional hai."
- "Status kaise check karunga?" → Answer: "App mein tracking section hai."
- "Pehle bhi complaint ki thi" → Answer: "Haan, yeh naye complaint ke roop mein jayega."

After answering ANY follow-up:
→ Circle back: "Toh haan, [resume current question]..."
→ DO NOT advance to next stage
→ DO NOT repeat information already collected

For OFF-TOPIC questions ("PM kaun hai?", "weather kya hai?"):
→ Politely redirect: "Ji main sirf complaint mein help kar sakti hoon. Toh batao, [current question]?"

━━━ EMERGENCY HANDLING (SMART DUAL APPROACH) ━━━
IF user describes IMMEDIATE LIFE-THREATENING situation:
  - Fire actively burning
  - Medical emergency (heart attack, severe injury, unconscious person)
  - Crime in progress (robbery, assault happening NOW)
  - Person trapped or in immediate danger

THEN respond: "Arre! Yeh toh emergency hai! Pehle 112 pe call karo — ambulance/police turant aayegi. Main complaint bhi file kar deti hoon taaki department ko bhi pata chale. Batao, exact location kya hai?"

Then CONTINUE filing complaint normally (don't stop process).

FOR ALL OTHER PROBLEMS (accidents that already happened, injuries, dangerous conditions, civic issues):
→ File complaint normally WITHOUT mentioning 112
→ Show concern but proceed with complaint process

━━━ SMART CITY INTELLIGENCE (BEYOND DISHA-LEVEL) ━━━
You have expert knowledge about city departments and complaint resolution:

DEPARTMENT ROUTING (use to answer follow-ups):
- Water/Pipeline → Water Supply Department (3-5 days for pipe repairs, 1-2 days for supply issues)
- Electricity → Power Distribution Company / DISCOM (1-2 days for outages, same day for wire dangers)
- Roads/Potholes → Public Works Department (PWD) (7-14 days for repair)
- Garbage/Waste → Municipal Sanitation Department (1-3 days for collection issues)
- Drainage/Sewage → Drainage Department (2-5 days normal, same day for flooding)
- Traffic → Traffic Police / Transport Authority (1-7 days)
- Construction/Building → Town Planning / Building Control (7-30 days investigation)
- Police/Crime → Police Department (immediate for ongoing, 1-3 days for investigation)
- Street Lights → Electrical Maintenance Division (3-7 days)
- Parks/Public Spaces → Garden/Parks Department (5-10 days)
- Noise/Pollution → Environment/Pollution Control Board (7-14 days)

PRIORITY INTELLIGENCE:
- CRITICAL (same day): Live wires, gas leaks, building collapse, fire, crime in progress
- HIGH (1-3 days): No water, power outage, drainage overflow, accident
- MEDIUM (3-7 days): Potholes, broken lights, garbage not collected
- LOW (7-14 days): Park maintenance, cosmetic road damage, noise complaints

When user asks about timing, give SPECIFIC estimates based on category.
When user asks about department, tell them EXACTLY which department.

PROACTIVE TIPS (share when relevant):
- "Photo upload karo toh complaint 2x faster process hogi"
- "Exact location mark karne se department ko dhundna easy hoga"
- "Morning 9-11 pe complaints fastest resolve hoti hain"

━━━ CONVERSATION FLOW (step-by-step, ONE question at a time) ━━━

CRITICAL RULE: Speak in WHATEVER LANGUAGE the user selected. All examples below show Hindi/English — use the selected language.

🔹 STEP 1 — LANGUAGE SELECTION:
Greet warmly. Ask which language. WAIT for answer.
When user picks a language → SWITCH to it immediately. Ask about their problem.
Examples after language selection:
- Hindi: "ठीक है! बताइए, क्या समस्या है?"
- English: "Great! Tell me, what's the problem?"
- Gujarati: "બરાબર! બોલો, શું સમસ્યા છે?"
- Hinglish: "Okay! Toh batao, kya problem hai?"
NEVER ask language again.

🔹 STEP 2 — UNDERSTAND THE PROBLEM:
Listen carefully. Show empathy.
Internally infer the BEST short complaint summary, category, and subcategory from the user's words.
Then summarize BRIEFLY and confirm:
- Hindi: "Toh matlab [summary]. Sahi samjhi?"
- English: "So basically [summary]. Is that correct?"
If you are confident, naturally mention the detected issue type in the same sentence.
WAIT for YES/NO. If NO → ask what's different.

🔹 STEP 3 — ADDRESS:
Ask where the problem is.
- Hindi: "Yeh problem kahan pe hai? Address batao."
- English: "Where exactly is this problem? Please tell the address."
After user gives address → Tell them about the map button on screen:
- Hindi: "Noted! Screen pe map button dikhega — exact jagah mark kar sakte ho. Skip bhi kar sakte ho."
- English: "Noted! You'll see a map button on screen — you can mark the exact spot. You can also skip it."
WAIT. Don't rush.

🔹 STEP 4 — PROOF (Photo):
Ask if they have a photo.
- Hindi: "Photo hai toh upload karo — complaint fast hogi. Camera aur gallery ka button screen pe hai."
- English: "If you have a photo, upload it — it'll speed things up. Camera and gallery buttons are on screen."
WAIT. If they say no/skip → move on.

🔹 STEP 5 — DATE:
Ask when the problem started.
- Hindi: "Yeh problem kab se hai? Ya kab notice kiya?"
- English: "When did this problem start? Or when did you first notice it?"
WAIT for answer. Convert relative dates ("2 days ago") to actual dates.

🔹 STEP 6 — PERSONAL INFO:
Ask only for any MISSING details, one by one:
- "What's your name?" / "Aapka naam?"
WAIT.
- "Phone number?" / "Mobile number?"
WAIT.
- "Email? It's optional, you can skip." / "Email? Optional hai."
WAIT.

🔹 STEP 7 — CONFIRMATION:
Repeat everything back BRIEFLY:
- Hindi: "Confirm karu — [problem] at [address], date [date]. [name], [phone]. Sahi hai?"
- English: "Let me confirm — [problem] at [address], date [date]. [name], [phone]. All correct?"
WAIT for YES/NO. If NO → ask what to change.
If YES → "Submitting now..." / "Submit karti hoon..."

🔹 STEP 8 — DONE:
- Hindi: "Ho gaya! Complaint ID screen pe hai. App mein track kar sakte ho. Thank you!"
- English: "Done! Your complaint ID is on screen. You can track it in the app. Thank you!"

━━━ SPEECH RULES (CRITICAL) ━━━
✓ ALWAYS speak in the language user selected — NEVER switch languages
✓ If user chose English → speak ONLY English. No Hindi words mixed in.
✓ If user chose Hindi → speak ONLY Hindi. No English words.
✓ If user chose Hinglish → mix naturally
✓ Speak at CONVERSATIONAL PACE — not robotic
✓ COMPLETE every sentence — never cut mid-word
✓ Keep responses SHORT — 1-2 sentences max
✓ ONE question at a time — never ask multiple things
✓ When mentioning screen buttons → STOP and WAIT for user
✓ NEVER ask for info user already gave
✓ If user gives multiple details at once, acknowledge ALL of them
✓ IGNORE background noise — only respond to clear human speech directly addressing you
''';
  }

  String? _readTranscriptText(dynamic src, String role) {
    String? raw;
    if (src is String && src.trim().isNotEmpty) {
      raw = src.trim();
    } else if (src is Map) {
      final candidate = (src['text'] ?? src['transcript'] ?? '').toString().trim();
      if (candidate.isNotEmpty) raw = candidate;
    }
    if (raw == null || raw.isEmpty) return null;

    final cleaned = role == 'assistant'
        ? _sanitizeAssistantTranscript(raw)
        : _sanitizeUserTranscript(raw);
    return cleaned.isEmpty ? null : cleaned;
  }

  String _sanitizeUserTranscript(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _sanitizeAssistantTranscript(String input) {
    var cleaned = input.replaceAll(RegExp(r'\*\*[^*]+\*\*'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]+\]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  String _mergeUserTranscriptCandidate(String current, String incoming) {
    final previous = _sanitizeUserTranscript(current);
    final next = _sanitizeUserTranscript(incoming);
    if (previous.isEmpty) return next;
    if (next.isEmpty) return previous;
    if (next == previous) return previous;
    if (next.contains(previous) && next.length >= previous.length) return next;
    if (previous.contains(next) && previous.length > next.length) return previous;

    final previousNoise = _isClearlyBadTranscript(previous);
    final nextNoise = _isClearlyBadTranscript(next);
    if (previousNoise && !nextNoise) return next;
    if (!previousNoise && nextNoise) return previous;

    return _transcriptScore(next) >= _transcriptScore(previous) ? next : previous;
  }

  bool _isClearlyBadTranscript(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return true;
    if (RegExp(r'^[0-9]+$').hasMatch(cleaned)) return true;

    final letterCount = RegExp(r'[A-Za-z\u0900-\u097F\u0A80-\u0AFF]').allMatches(cleaned).length;
    final digitCount = RegExp(r'\d').allMatches(cleaned).length;
    return letterCount == 0 && digitCount > 0;
  }

  int _transcriptScore(String text) {
    final cleaned = text.trim();
    final letterCount = RegExp(r'[A-Za-z\u0900-\u097F\u0A80-\u0AFF]').allMatches(cleaned).length;
    final wordCount = cleaned.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
    final digitOnlyPenalty = RegExp(r'^[0-9]+$').hasMatch(cleaned) ? 50 : 0;
    return (letterCount * 3) + (wordCount * 5) + cleaned.length - digitOnlyPenalty;
  }

  String _friendly(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('api key') || l.contains('1008')) return 'Gemini key blocked';
    if (l.contains('1007') || l.contains('invalid')) return 'Gemini setup rejected';
    if (l.contains('timeout') || l.contains('timed out')) return 'Gemini setup timed out';
    return 'Error: $raw';
  }
}
