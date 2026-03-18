import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceConfigService {
  static const String _voiceConfigKey = 'voice_config';
  static const String _elevenLabsApiKey = 'elevenlabs_api_key';
  
  // Default ElevenLabs voice configurations
  static const Map<String, dynamic> defaultVoiceConfig = {
    'provider': 'elevenlabs', // 'elevenlabs' or 'flutter_tts'
    'voice_id': '21m00Tcm4TlvDq8ikWAM', // Rachel - warm female voice
    'model': 'eleven_multilingual_v2',
    'stability': 0.8,
    'similarity_boost': 0.8,
    'style': 0.5,
    'use_speaker_boost': true,
    'optimize_streaming_latency': 2,
    'output_format': 'mp3_44100_128',
  };

  // Available voice personalities
  static const Map<String, Map<String, dynamic>> voicePersonalities = {
    'maya_caring': {
      'voice_id': '21m00Tcm4TlvDq8ikWAM', // Rachel
      'name': 'Maya (Caring)',
      'description': 'Warm, empathetic voice perfect for customer support',
      'stability': 0.85,
      'similarity_boost': 0.8,
      'style': 0.4,
    },
    'maya_professional': {
      'voice_id': 'AZnzlk1XvdvUeBnXmlld', // Domi
      'name': 'Maya (Professional)',
      'description': 'Clear, professional voice for urgent matters',
      'stability': 0.9,
      'similarity_boost': 0.85,
      'style': 0.3,
    },
    'maya_friendly': {
      'voice_id': 'EXAVITQu4vr4xnSDxMaL', // Bella
      'name': 'Maya (Friendly)',
      'description': 'Cheerful, approachable voice for general conversations',
      'stability': 0.75,
      'similarity_boost': 0.9,
      'style': 0.7,
    },
    'maya_calm': {
      'voice_id': 'ErXwobaYiN019PkySvjV', // Antoni
      'name': 'Maya (Calm)',
      'description': 'Soothing, calm voice for stressful situations',
      'stability': 0.95,
      'similarity_boost': 0.75,
      'style': 0.2,
    },
  };

  // Emotional voice modulations
  static const Map<String, Map<String, double>> emotionalModulations = {
    'happy': {
      'stability': 0.75,
      'similarity_boost': 0.85,
      'style': 0.8,
      'speed_modifier': 1.1,
    },
    'excited': {
      'stability': 0.65,
      'similarity_boost': 0.9,
      'style': 0.9,
      'speed_modifier': 1.2,
    },
    'concerned': {
      'stability': 0.85,
      'similarity_boost': 0.75,
      'style': 0.3,
      'speed_modifier': 0.9,
    },
    'urgent': {
      'stability': 0.7,
      'similarity_boost': 0.8,
      'style': 0.7,
      'speed_modifier': 1.15,
    },
    'sad': {
      'stability': 0.9,
      'similarity_boost': 0.7,
      'style': 0.2,
      'speed_modifier': 0.8,
    },
    'angry': {
      'stability': 0.6,
      'similarity_boost': 0.85,
      'style': 0.8,
      'speed_modifier': 1.0,
    },
    'calm': {
      'stability': 0.9,
      'similarity_boost': 0.8,
      'style': 0.4,
      'speed_modifier': 0.95,
    },
    'neutral': {
      'stability': 0.8,
      'similarity_boost': 0.8,
      'style': 0.5,
      'speed_modifier': 1.0,
    },
  };

  static Future<Map<String, dynamic>> getVoiceConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_voiceConfigKey);
    
    if (configJson != null) {
      return jsonDecode(configJson);
    }
    
    return Map<String, dynamic>.from(defaultVoiceConfig);
  }

  static Future<void> saveVoiceConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceConfigKey, jsonEncode(config));
  }

  static Future<String?> getElevenLabsApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_elevenLabsApiKey);
  }

  static Future<void> setElevenLabsApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_elevenLabsApiKey, apiKey);
  }

  static Future<void> setVoicePersonality(String personalityKey) async {
    if (voicePersonalities.containsKey(personalityKey)) {
      final config = await getVoiceConfig();
      final personality = voicePersonalities[personalityKey]!;
      
      config['voice_id'] = personality['voice_id'];
      config['stability'] = personality['stability'];
      config['similarity_boost'] = personality['similarity_boost'];
      config['style'] = personality['style'];
      
      await saveVoiceConfig(config);
    }
  }

  static Map<String, dynamic> getEmotionalModulation(String emotion) {
    return emotionalModulations[emotion] ?? emotionalModulations['neutral']!;
  }

  static Future<void> setVoiceProvider(String provider) async {
    final config = await getVoiceConfig();
    config['provider'] = provider;
    await saveVoiceConfig(config);
  }

  static Future<bool> isElevenLabsEnabled() async {
    final config = await getVoiceConfig();
    final apiKey = await getElevenLabsApiKey();
    
    return config['provider'] == 'elevenlabs' && 
           apiKey != null && 
           apiKey.isNotEmpty && 
           apiKey != 'YOUR_ELEVENLABS_API_KEY';
  }

  // Voice quality presets
  static const Map<String, Map<String, dynamic>> qualityPresets = {
    'high_quality': {
      'model': 'eleven_multilingual_v2',
      'optimize_streaming_latency': 0,
      'output_format': 'mp3_44100_192',
    },
    'balanced': {
      'model': 'eleven_multilingual_v2',
      'optimize_streaming_latency': 2,
      'output_format': 'mp3_44100_128',
    },
    'fast': {
      'model': 'eleven_turbo_v2',
      'optimize_streaming_latency': 4,
      'output_format': 'mp3_22050_32',
    },
  };

  static Future<void> setQualityPreset(String preset) async {
    if (qualityPresets.containsKey(preset)) {
      final config = await getVoiceConfig();
      final presetConfig = qualityPresets[preset]!;
      
      config.addAll(presetConfig);
      await saveVoiceConfig(config);
    }
  }

  // Custom voice settings
  static Future<void> updateVoiceSettings({
    double? stability,
    double? similarityBoost,
    double? style,
    bool? useSpeakerBoost,
  }) async {
    final config = await getVoiceConfig();
    
    if (stability != null) config['stability'] = stability;
    if (similarityBoost != null) config['similarity_boost'] = similarityBoost;
    if (style != null) config['style'] = style;
    if (useSpeakerBoost != null) config['use_speaker_boost'] = useSpeakerBoost;
    
    await saveVoiceConfig(config);
  }

  // Reset to defaults
  static Future<void> resetToDefaults() async {
    await saveVoiceConfig(Map<String, dynamic>.from(defaultVoiceConfig));
  }

  // Get available voices list (for UI)
  static List<Map<String, dynamic>> getAvailableVoices() {
    return voicePersonalities.entries.map((entry) {
      final personality = Map<String, dynamic>.from(entry.value);
      personality['key'] = entry.key;
      return personality;
    }).toList();
  }

  // Voice testing
  static const String testPhrase = "Hello! I'm Maya, your AI assistant. I'm here to help you with any city-related problems you're facing. How can I assist you today?";
  
  static String getTestPhrase() => testPhrase;
}