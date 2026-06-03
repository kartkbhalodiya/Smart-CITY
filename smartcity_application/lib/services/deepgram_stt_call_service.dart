import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

typedef DeepgramStatusCallback = void Function(String status);
typedef DeepgramBoolCallback = void Function(bool value);
typedef DeepgramTranscriptCallback = void Function(String text, bool isFinal);

class DeepgramSttCallService {
  static const int _sampleRate = 16000;
  static const int _bufferSize = 512;
  static const String _apiKey = String.fromEnvironment(
    'DEEPGRAM_API_KEY',
    defaultValue: '',
  );

  final FlutterAudioCapture _mic = FlutterAudioCapture();

  WebSocket? _socket;
  StreamSubscription? _socketSub;
  Timer? _keepAliveTimer;
  bool _closed = true;
  bool _micOn = false;
  bool _muted = false;
  String _currentTranscript = '';

  DeepgramStatusCallback? onStatus;
  DeepgramBoolCallback? onConnected;
  DeepgramBoolCallback? onListening;
  DeepgramTranscriptCallback? onTranscript;

  bool get isListening => _micOn && !_muted && !_closed;
  bool get isMuted => _muted;
  String get currentTranscript => _currentTranscript;

  Future<bool> start() async {
    await stop();
    _closed = false;
    _muted = false;
    _currentTranscript = '';
    onStatus?.call('Connecting Deepgram');

    final key = _apiKey.trim();
    if (key.isEmpty) {
      onStatus?.call('Deepgram key missing');
      return false;
    }

    try {
      final uri = Uri.https('api.deepgram.com', '/v1/listen', {
        'model': 'nova-3-general',
        'language': 'multi',
        'encoding': 'linear16',
        'sample_rate': _sampleRate.toString(),
        'channels': '1',
        'interim_results': 'true',
        'smart_format': 'true',
        'punctuate': 'true',
        'endpointing': '600',
        'utterance_end_ms': '1000',
        'vad_events': 'true',
      }).replace(scheme: 'wss');

      _socket = await WebSocket.connect(
        uri.toString(),
        headers: {'Authorization': 'Token $key'},
      ).timeout(const Duration(seconds: 15));

      _socketSub = _socket!.listen(
        _handleSocketMessage,
        onDone: _handleSocketDone,
        onError: _handleSocketError,
        cancelOnError: false,
      );

      _startKeepAlive();
      onConnected?.call(true);
      onStatus?.call('Deepgram connected');
      await _startMic();
      return true;
    } catch (error) {
      debugPrint('[DeepgramSTT] start error: $error');
      onStatus?.call(_friendlyError(error));
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    _closed = true;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    await _stopMic();

    try {
      _socket?.add(jsonEncode({'type': 'CloseStream'}));
    } catch (_) {}
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    onListening?.call(false);
    onConnected?.call(false);
  }

  Future<void> setMuted(bool muted) async {
    if (_closed) return;
    _muted = muted;
    if (muted) {
      await _stopMic();
      onStatus?.call('Muted');
      return;
    }

    onStatus?.call('Listening');
    await _startMic();
  }

  Future<void> _startMic() async {
    if (_micOn || _closed || _muted) return;

    try {
      if (!(await Permission.microphone.isGranted)) {
        final permission = await Permission.microphone.request();
        if (!permission.isGranted) {
          onStatus?.call('Microphone permission denied');
          return;
        }
      }

      await _mic.init();
      await _mic.start(
        (dynamic raw) {
          if (_closed || _muted || _socket == null) return;
          final pcmBytes = _rawAudioToLinear16(raw);
          if (pcmBytes == null || pcmBytes.isEmpty) return;
          try {
            _socket!.add(pcmBytes);
          } catch (error) {
            debugPrint('[DeepgramSTT] audio send error: $error');
          }
        },
        (_) {},
        sampleRate: _sampleRate,
        bufferSize: _bufferSize,
      );
      _micOn = true;
      onListening?.call(true);
      onStatus?.call('Listening');
    } catch (error) {
      debugPrint('[DeepgramSTT] mic start error: $error');
      onStatus?.call('Mic start failed');
    }
  }

  Future<void> _stopMic() async {
    if (!_micOn) return;
    try {
      await _mic.stop();
    } catch (_) {}
    _micOn = false;
    onListening?.call(false);
  }

  Uint8List? _rawAudioToLinear16(dynamic raw) {
    final floats = _toFloats(raw);
    if (floats == null || floats.isEmpty) return null;

    var maxAmp = 0.0;
    for (final sample in floats) {
      final amplitude = sample < 0 ? -sample : sample;
      if (amplitude > maxAmp) maxAmp = amplitude;
    }
    if (maxAmp < 0.004) return null;

    final bytes = Uint8List(floats.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < floats.length; i++) {
      final value = (floats[i] * 32767).round().clamp(-32768, 32767);
      data.setInt16(i * 2, value, Endian.little);
    }
    return bytes;
  }

  Float32List? _toFloats(dynamic raw) {
    if (raw is Float32List) return raw;
    if (raw is List) {
      return Float32List.fromList(
        raw.map((value) => (value as num).toDouble()).toList(),
      );
    }
    if (raw is Uint8List) {
      return raw.buffer.asFloat32List();
    }
    return null;
  }

  void _handleSocketMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic>) return;

      final type = (data['type'] ?? '').toString();
      if (type == 'SpeechStarted') {
        onStatus?.call('Speech detected');
        return;
      }
      if (type == 'UtteranceEnd') {
        if (_currentTranscript.isNotEmpty) {
          onTranscript?.call(_currentTranscript, true);
        }
        onStatus?.call('Listening');
        return;
      }
      if (type != 'Results') return;

      final channel = data['channel'];
      final alternatives = channel is Map ? channel['alternatives'] : null;
      if (alternatives is! List || alternatives.isEmpty) return;

      final first = alternatives.first;
      if (first is! Map) return;

      final transcript = (first['transcript'] ?? '').toString().trim();
      if (transcript.isEmpty) return;

      _currentTranscript = transcript;
      final isFinal = data['is_final'] == true || data['speech_final'] == true;
      onTranscript?.call(transcript, isFinal);
      onStatus?.call(isFinal ? 'Listening' : 'Transcribing');
    } catch (error) {
      debugPrint('[DeepgramSTT] message parse error: $error');
    }
  }

  void _handleSocketDone() {
    if (_closed) return;
    debugPrint('[DeepgramSTT] socket closed');
    onStatus?.call('Deepgram disconnected');
    onConnected?.call(false);
    onListening?.call(false);
  }

  void _handleSocketError(Object error) {
    debugPrint('[DeepgramSTT] socket error: $error');
    if (_closed) return;
    onStatus?.call(_friendlyError(error));
    onConnected?.call(false);
    onListening?.call(false);
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_closed || _socket == null) return;
      try {
        _socket!.add(jsonEncode({'type': 'KeepAlive'}));
      } catch (_) {}
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('401') || text.contains('unauthorized')) {
      return 'Deepgram key rejected';
    }
    if (text.contains('timeout')) {
      return 'Deepgram connection timeout';
    }
    if (text.contains('permission')) {
      return 'Microphone permission needed';
    }
    return 'Deepgram STT failed';
  }
}
