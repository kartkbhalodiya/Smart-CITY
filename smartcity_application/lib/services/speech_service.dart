import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'voice_config_service.dart';

class SpeechService {
  final AudioPlayer _elevenPlayer = AudioPlayer();
  static const String _fallbackVoiceId = '21m00Tcm4TlvDq8ikWAM';
  String? _lastVoiceError;

  bool _isInitialized = false;
  bool isListening = false;
  bool _useElevenLabs = false;

  String _currentMood = 'neutral';
  String _currentVoice = 'janhelp_caring';

  final Map<String, Map<String, double>> _moodVoice = {
    'happy': {'rate': 0.55, 'pitch': 1.15, 'volume': 0.95},
    'excited': {'rate': 0.62, 'pitch': 1.2, 'volume': 1.0},
    'concerned': {'rate': 0.45, 'pitch': 0.95, 'volume': 0.9},
    'urgent': {'rate': 0.6, 'pitch': 1.08, 'volume': 1.0},
    'sad': {'rate': 0.4, 'pitch': 0.88, 'volume': 0.86},
    'angry': {'rate': 0.52, 'pitch': 0.92, 'volume': 0.95},
    'calm': {'rate': 0.43, 'pitch': 1.0, 'volume': 0.9},
    'neutral': {'rate': 0.5, 'pitch': 1.0, 'volume': 0.92},
  };

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _refreshProviderState();
  }

  Future<void> startListening(Function(String) onResult) async {
    await initialize();
    isListening = true;
    // Current app uses typed input; method retained for future STT integration.
  }

  Future<void> stopListening() async {
    isListening = false;
  }

  Future<void> speak(
    String text, {
    String? language,
    String mood = 'neutral',
    String urgency = 'medium',
  }) async {
    await initialize();
    await speakAdvanced(
      text: text,
      language: language ?? 'en',
      mood: mood,
      urgency: urgency,
      isEmergency: urgency == 'critical',
    );
  }

  Future<void> speakAdvanced({
    required String text,
    required String language,
    required String mood,
    required String urgency,
    bool isEmergency = false,
  }) async {
    await initialize();
    await _refreshProviderState();

    final normalizedMood = _normalizeMood(mood);
    final normalizedUrgency = _normalizeUrgency(urgency);

    _currentMood = normalizedMood;

    final speakText = _prepareSpeechText(
      text,
      mood: normalizedMood,
      urgency: normalizedUrgency,
    );

    if (!_useElevenLabs) {
      throw Exception('ElevenLabs API key is missing.');
    }

    _lastVoiceError = null;
    final played = await _speakWithElevenLabs(
      text: speakText,
      language: language,
      mood: normalizedMood,
      urgency: normalizedUrgency,
      isEmergency: isEmergency,
    );

    if (!played) {
      final detail = _lastVoiceError ?? 'unknown error';
      throw Exception('ElevenLabs voice generation failed: $detail');
    }
  }

  Future<void> speakWithEmotion(String text, String emotion) async {
    await speakAdvanced(
      text: text,
      language: 'en',
      mood: _mapEmotionToMood(emotion),
      urgency: 'medium',
    );
  }

  Future<void> speakHindi(String text, {String mood = 'neutral'}) async {
    await speakAdvanced(
      text: text,
      language: 'hi',
      mood: mood,
      urgency: 'medium',
    );
  }

  Future<void> speakGujarati(String text, {String mood = 'neutral'}) async {
    await speakAdvanced(
      text: text,
      language: 'gu',
      mood: mood,
      urgency: 'medium',
    );
  }

  Future<void> speakContextual(
    String text,
    String complaintType,
    String urgency,
  ) async {
    var mood = 'neutral';

    switch (_normalizeUrgency(urgency)) {
      case 'critical':
        mood = 'urgent';
        _currentVoice = 'janhelp_professional';
        break;
      case 'high':
        mood = 'concerned';
        _currentVoice = 'janhelp_caring';
        break;
      case 'medium':
        mood = 'calm';
        _currentVoice = 'janhelp_friendly';
        break;
      case 'low':
        mood = 'neutral';
        _currentVoice = 'janhelp_calm';
        break;
    }

    if (complaintType.toLowerCase().contains('emergency') ||
        complaintType.toLowerCase().contains('safety')) {
      mood = 'urgent';
    }

    await speakAdvanced(
      text: text,
      language: 'en',
      mood: mood,
      urgency: urgency,
      isEmergency: urgency.toLowerCase() == 'critical',
    );
  }

  Future<void> setVoicePersonality(String personality) async {
    if (VoiceConfigService.voicePersonalities.containsKey(personality)) {
      _currentVoice = personality;
    }
  }

  Future<void> cloneVoice(String audioFilePath, String voiceName) async {
    // Placeholder for future provider implementation.
  }

  Future<void> adjustVoiceInRealTime(
    double stability,
    double clarity,
    double style,
  ) async {
    final mood = _normalizeMood(_currentMood);
    final base = _moodVoice[mood] ?? _moodVoice['neutral']!;
    _moodVoice[mood] = {
      'rate': base['rate']!,
      'pitch': (0.8 + (style * 0.4)).clamp(0.7, 1.3),
      'volume': (0.75 + (clarity * 0.25)).clamp(0.6, 1.0),
    };
  }

  Future<void> stop() async {
    await stopListening();
    await _elevenPlayer.stop();
  }

  void dispose() {
    _elevenPlayer.dispose();
  }

  Future<void> _refreshProviderState() async {
    final apiKey = await VoiceConfigService.getElevenLabsApiKey();
    final hasApiKey = apiKey != null &&
        apiKey.trim().isNotEmpty &&
        apiKey.trim() != 'YOUR_ELEVENLABS_API_KEY';

    if (!hasApiKey) {
      _useElevenLabs = false;
      return;
    }

    // Force provider to ElevenLabs when key exists to avoid accidental fallback.
    final config = await VoiceConfigService.getVoiceConfig();
    if (config['provider'] != 'elevenlabs') {
      config['provider'] = 'elevenlabs';
      await VoiceConfigService.saveVoiceConfig(config);
    }

    _useElevenLabs = true;
  }

  Future<bool> _speakWithElevenLabs({
    required String text,
    required String language,
    required String mood,
    required String urgency,
    required bool isEmergency,
  }) async {
    try {
      final apiKey = await VoiceConfigService.getElevenLabsApiKey();
      if (apiKey == null || apiKey.trim().isEmpty) {
        return false;
      }

      final config = await VoiceConfigService.getVoiceConfig();
      final modulation = VoiceConfigService.getEmotionalModulation(mood);

      final primaryVoiceId =
          (config['voice_id'] as String?)?.trim().isNotEmpty == true
              ? (config['voice_id'] as String).trim()
              : VoiceConfigService.preferredVoiceId;
      final model = (config['model'] as String?)?.trim().isNotEmpty == true
          ? (config['model'] as String).trim()
          : 'eleven_multilingual_v2';
      final latency =
          (config['optimize_streaming_latency'] as num?)?.toInt() ?? 2;
      final outputFormat =
          (config['output_format'] as String?)?.trim().isNotEmpty == true
              ? (config['output_format'] as String).trim()
              : 'mp3_44100_128';

      final baseStability = (config['stability'] as num?)?.toDouble() ?? 0.8;
      final baseSimilarity =
          (config['similarity_boost'] as num?)?.toDouble() ?? 0.8;
      final baseStyle = (config['style'] as num?)?.toDouble() ?? 0.5;
      final useSpeakerBoost = (config['use_speaker_boost'] as bool?) ?? true;

      var stability =
          (modulation['stability'] as num?)?.toDouble() ?? baseStability;
      var similarity = (modulation['similarity_boost'] as num?)?.toDouble() ??
          baseSimilarity;
      var style = (modulation['style'] as num?)?.toDouble() ?? baseStyle;

      if (isEmergency || urgency == 'critical') {
        style = (style + 0.1).clamp(0.0, 1.0);
      }

      stability = stability.clamp(0.0, 1.0);
      similarity = similarity.clamp(0.0, 1.0);
      style = style.clamp(0.0, 1.0);

      final attempts = <Map<String, dynamic>>[
        {'voiceId': primaryVoiceId, 'includeLanguageCode': true},
        {'voiceId': primaryVoiceId, 'includeLanguageCode': false},
      ];
      if (primaryVoiceId != _fallbackVoiceId) {
        attempts.addAll([
          {'voiceId': _fallbackVoiceId, 'includeLanguageCode': true},
          {'voiceId': _fallbackVoiceId, 'includeLanguageCode': false},
        ]);
      }

      Uint8List? audioBytes;
      String? usedVoiceId;
      for (final attempt in attempts) {
        final attemptVoiceId = attempt['voiceId'] as String;
        final includeLanguageCode = attempt['includeLanguageCode'] as bool;
        audioBytes = await _requestElevenLabsAudio(
          apiKey: apiKey,
          voiceId: attemptVoiceId,
          text: text,
          model: model,
          latency: latency,
          outputFormat: outputFormat,
          stability: stability,
          similarity: similarity,
          style: style,
          useSpeakerBoost: useSpeakerBoost,
          language: language,
          includeLanguageCode: includeLanguageCode,
        );
        if (audioBytes != null) {
          usedVoiceId = attemptVoiceId;
          break;
        }
      }

      if (audioBytes == null) {
        return false;
      }

      if (usedVoiceId != null && usedVoiceId != primaryVoiceId) {
        config['voice_id'] = usedVoiceId;
        await VoiceConfigService.saveVoiceConfig(config);
      }

      await _elevenPlayer.stop();
      await _elevenPlayer.play(BytesSource(audioBytes));

      // Wait for completion so next voice response does not overlap.
      await _elevenPlayer.onPlayerComplete.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () => Future.value(),
      );
      return true;
    } catch (e) {
      _lastVoiceError = 'playback_error: $e';
      debugPrint('ElevenLabs playback error: $e');
      return false;
    }
  }

  Future<Uint8List?> _requestElevenLabsAudio({
    required String apiKey,
    required String voiceId,
    required String text,
    required String model,
    required int latency,
    required String outputFormat,
    required double stability,
    required double similarity,
    required double style,
    required bool useSpeakerBoost,
    required String language,
    required bool includeLanguageCode,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$voiceId/stream'
        '?optimize_streaming_latency=$latency'
        '&output_format=$outputFormat',
      );

      final response = await http
          .post(
            uri,
            headers: {
              'xi-api-key': apiKey,
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: jsonEncode({
              'text': text,
              'model_id': model,
              'voice_settings': {
                'stability': stability,
                'similarity_boost': similarity,
                'style': style,
                'use_speaker_boost': useSpeakerBoost,
              },
              if (includeLanguageCode && language.isNotEmpty)
                'language_code': _mapToBcp47(language),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastVoiceError =
            'http_${response.statusCode}: ${response.body.toString()}';
        debugPrint(
          'ElevenLabs HTTP ${response.statusCode} for voice $voiceId '
          '(langCode=$includeLanguageCode): ${response.body}',
        );
        return null;
      }

      if (response.bodyBytes.isEmpty) {
        return null;
      }

      return response.bodyBytes;
    } catch (e) {
      _lastVoiceError = e.toString();
      debugPrint(
        'ElevenLabs request error for voice $voiceId '
        '(langCode=$includeLanguageCode): $e',
      );
      return null;
    }
  }

  String _prepareSpeechText(
    String text, {
    required String mood,
    required String urgency,
  }) {
    var cleaned = text
        .replaceAll(RegExp(r'[*_`#]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return cleaned;

    if (_currentVoice == 'janhelp_professional' &&
        !cleaned.startsWith('Please note.')) {
      cleaned = 'Please note. $cleaned';
    }

    if (urgency == 'critical') {
      cleaned = 'Important. $cleaned';
    } else if (mood == 'concerned' || mood == 'sad') {
      cleaned = 'I understand. $cleaned';
    }

    cleaned = cleaned
        .replaceAll('. ', '.  ')
        .replaceAll('? ', '?  ')
        .replaceAll('! ', '!  ');

    return cleaned;
  }

  String _mapEmotionToMood(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'frustrated':
      case 'annoyed':
        return 'concerned';
      case 'urgent':
      case 'emergency':
        return 'urgent';
      case 'happy':
      case 'pleased':
        return 'happy';
      case 'excited':
        return 'excited';
      case 'sad':
      case 'disappointed':
        return 'sad';
      case 'angry':
      case 'mad':
        return 'angry';
      case 'worried':
      case 'concerned':
        return 'concerned';
      default:
        return 'neutral';
    }
  }

  String _normalizeMood(String mood) {
    final m = mood.toLowerCase().trim();
    return _moodVoice.containsKey(m) ? m : 'neutral';
  }

  String _normalizeUrgency(String urgency) {
    final u = urgency.toLowerCase().trim();
    if (u == 'low' || u == 'medium' || u == 'high' || u == 'critical') {
      return u;
    }
    return 'medium';
  }

  String _mapToBcp47(String language) {
    switch (language.trim().toLowerCase()) {
      case 'hi':
        return 'hi';
      case 'gu':
      case 'guj':
        return 'gu';
      case 'en':
      case 'hinglish':
      default:
        return 'en';
    }
  }
}
