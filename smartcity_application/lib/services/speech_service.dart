import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool isListening = false;
  String _currentMood = 'neutral';
  bool _useElevenLabs = false; // Disabled for now, will use enhanced Flutter TTS
  
  // ElevenLabs API configuration (for future use)
  static const String _elevenLabsApiKey = 'YOUR_ELEVENLABS_API_KEY';
  static const String _elevenLabsBaseUrl = 'https://api.elevenlabs.io/v1';
  
  // Voice IDs for different personalities (ElevenLabs)
  final Map<String, String> _voiceIds = {
    'maya_caring': '21m00Tcm4TlvDq8ikWAM',
    'maya_professional': 'AZnzlk1XvdvUeBnXmlld',
    'maya_friendly': 'EXAVITQu4vr4xnSDxMaL',
    'maya_calm': 'ErXwobaYiN019PkySvjV',
  };
  
  // Current voice personality
  String _currentVoice = 'maya_caring';

  // Voice parameters for different emotions with ElevenLabs settings
  final Map<String, Map<String, dynamic>> _emotionalVoiceSettings = {
    'happy': {
      'rate': 0.6, 'pitch': 1.2, 'volume': 0.9,
      'stability': 0.75, 'similarity_boost': 0.85, 'style': 0.8
    },
    'excited': {
      'rate': 0.7, 'pitch': 1.3, 'volume': 1.0,
      'stability': 0.65, 'similarity_boost': 0.9, 'style': 0.9
    },
    'concerned': {
      'rate': 0.4, 'pitch': 0.9, 'volume': 0.8,
      'stability': 0.85, 'similarity_boost': 0.75, 'style': 0.3
    },
    'urgent': {
      'rate': 0.8, 'pitch': 1.1, 'volume': 1.0,
      'stability': 0.7, 'similarity_boost': 0.8, 'style': 0.7
    },
    'sad': {
      'rate': 0.3, 'pitch': 0.8, 'volume': 0.7,
      'stability': 0.9, 'similarity_boost': 0.7, 'style': 0.2
    },
    'angry': {
      'rate': 0.6, 'pitch': 0.9, 'volume': 0.9,
      'stability': 0.6, 'similarity_boost': 0.85, 'style': 0.8
    },
    'calm': {
      'rate': 0.5, 'pitch': 1.0, 'volume': 0.8,
      'stability': 0.9, 'similarity_boost': 0.8, 'style': 0.4
    },
    'neutral': {
      'rate': 0.5, 'pitch': 1.0, 'volume': 0.9,
      'stability': 0.8, 'similarity_boost': 0.8, 'style': 0.5
    },
  };

  // Natural speech patterns and fillers
  final List<String> _naturalFillers = [
    "Hmm, ", "Let me see, ", "Well, ", "You know, ", "Actually, ",
    "I mean, ", "So, ", "Okay, ", "Right, ", "Now, "
  ];

  final List<String> _empathyPhrases = [
    "I understand, ", "I can imagine, ", "That sounds tough, ",
    "I hear you, ", "I get it, ", "That must be frustrating, "
  ];

  Future<void> initialize() async {
    if (!_isInitialized) {
      _isInitialized = true;
      
      // Initialize both TTS systems
      await _initializeFlutterTTS();
      await _initializeElevenLabs();
    }
  }

  Future<void> _initializeFlutterTTS() async {
    await _tts.setLanguage("en-IN");
    await _setEmotionalVoice('neutral');
    
    // Set voice to female for more natural sound
    await _tts.setVoice({"name": "en-IN-language", "locale": "en-IN"});
    
    // Enable SSML for better expression control
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(0.9);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeElevenLabs() async {    // ElevenLabs integration disabled for now - using enhanced Flutter TTS
    _useElevenLabs = false;
    print('Using enhanced Flutter TTS with emotional voice modulation');
  }

  Future<void> _setEmotionalVoice(String mood) async {
    _currentMood = mood;
    final settings = _emotionalVoiceSettings[mood] ?? _emotionalVoiceSettings['neutral']!;
    
    // Apply to Flutter TTS
    await _tts.setSpeechRate(settings['rate']!);
    await _tts.setPitch(settings['pitch']!);
    await _tts.setVolume(settings['volume']!);
  }

  String _addNaturalExpression(String text, String mood) {
    Random random = Random();
    String processedText = text;
    
    // Add natural fillers occasionally
    if (random.nextDouble() < 0.3) {
      String filler = _naturalFillers[random.nextInt(_naturalFillers.length)];
      processedText = filler + processedText;
    }
    
    // Add empathy phrases for emotional situations
    if (['sad', 'angry', 'frustrated', 'worried'].contains(mood) && random.nextDouble() < 0.4) {
      String empathy = _empathyPhrases[random.nextInt(_empathyPhrases.length)];
      processedText = empathy + processedText;
    }
    
    // Add natural pauses and emphasis
    processedText = _addNaturalPauses(processedText);
    
    return processedText;
  }

  String _addNaturalPauses(String text) {
    // Add pauses after certain phrases for more natural speech
    text = text.replaceAll(', ', ', <break time="300ms"/> ');
    text = text.replaceAll('. ', '. <break time="500ms"/> ');
    text = text.replaceAll('! ', '! <break time="400ms"/> ');
    text = text.replaceAll('? ', '? <break time="400ms"/> ');
    
    // Add emphasis on important words
    text = text.replaceAllMapped(
      RegExp(r'\b(urgent|emergency|important|critical|serious)\b', caseSensitive: false),
      (match) => '<emphasis level="strong">${match.group(0)}</emphasis>'
    );
    
    return '<speak>$text</speak>';
  }

 // Enhanced Flutter TTS with ElevenLabs-like features
  Future<void> _speakWithElevenLabs(String text, String mood) async {
    // For now, use enhanced Flutter TTS with emotional modulation
    await _speakWithFlutterTTS(text, mood);
  }

  Future<void> _speakWithFlutterTTS(String text, String mood) async {
    await _setEmotionalVoice(mood);
    String naturalText = _addNaturalExpression(text, mood);
    await _tts.speak(naturalText);
  }

  Future<void> startListening(Function(String) onResult) async {
    await initialize();
    isListening = true;
    // Simulated listening - user will type instead
  }

  Future<void> stopListening() async {
    isListening = false;
  }

  Future<void> speak(String text, {String? language, String mood = 'neutral'}) async {
    await initialize();
    
    if (language != null) {
      await _tts.setLanguage(language);
    }
    
    // Use ElevenLabs if available, otherwise Flutter TTS
    if (_useElevenLabs && language == null) {
      await _speakWithElevenLabs(text, mood);
    } else {
      await _speakWithFlutterTTS(text, mood);
    }
  }

  Future<void> speakWithEmotion(String text, String emotion) async {
    await initialize();
    
    // Map emotions to voice settings
    String mood = _mapEmotionToMood(emotion);
    await speak(text, mood: mood);
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

  // Voice personality switching
  Future<void> setVoicePersonality(String personality) async {
    if (_voiceIds.containsKey(personality)) {
      _currentVoice = personality;
    }
  }

  Future<void> speakHindi(String text, {String mood = 'neutral'}) async {
    await _tts.setLanguage("hi-IN");
    await _setEmotionalVoice(mood);
    
    // Add Hindi natural expressions
    String naturalText = _addHindiExpressions(text, mood);
    await _tts.speak(naturalText);
  }

  Future<void> speakGujarati(String text, {String mood = 'neutral'}) async {
    await _tts.setLanguage("gu-IN");
    await _setEmotionalVoice(mood);
    
    // Add Gujarati natural expressions
    String naturalText = _addGujaratiExpressions(text, mood);
    await _tts.speak(naturalText);
  }

  String _addHindiExpressions(String text, String mood) {
    Random random = Random();
    List<String> hindiFillers = ["अच्छा, ", "देखिए, ", "समझिए, ", "हाँ, ", "ठीक है, "];
    
    if (random.nextDouble() < 0.3) {
      String filler = hindiFillers[random.nextInt(hindiFillers.length)];
      text = filler + text;
    }
    
    return _addNaturalPauses(text);
  }

  String _addGujaratiExpressions(String text, String mood) {
    Random random = Random();
    List<String> gujaratiFillers = ["સાચું, ", "જુઓ, ", "સમજો, ", "હા, ", "ઠીક છે, "];
    
    if (random.nextDouble() < 0.3) {
      String filler = gujaratiFillers[random.nextInt(gujaratiFillers.length)];
      text = filler + text;
    }
    
    return _addNaturalPauses(text);
  }

  // Method to speak with contextual emotion based on complaint type
  Future<void> speakContextual(String text, String complaintType, String urgency) async {
    String mood = 'neutral';
    
    // Determine mood based on complaint urgency and type
    switch (urgency.toLowerCase()) {
      case 'critical':
        mood = 'urgent';
        _currentVoice = 'maya_professional'; // More serious voice
        break;
      case 'high':
        mood = 'concerned';
        _currentVoice = 'maya_caring';
        break;
      case 'medium':
        mood = 'calm';
        _currentVoice = 'maya_friendly';
        break;
      case 'low':
        mood = 'neutral';
        _currentVoice = 'maya_calm';
        break;
    }
    
    // Adjust mood based on complaint type
    if (complaintType.toLowerCase().contains('emergency') || 
        complaintType.toLowerCase().contains('safety')) {
      mood = 'urgent';
      _currentVoice = 'maya_professional';
    }
    
    await speak(text, mood: mood);
  }

  // Advanced voice cloning (if user provides sample)
  Future<void> cloneVoice(String audioFilePath, String voiceName) async {
    // This would integrate with ElevenLabs voice cloning API
    // Implementation depends on specific requirements
    try {
      // Voice cloning implementation here
      print('Voice cloning feature - would implement ElevenLabs voice cloning');
    } catch (e) {
      print('Voice cloning error: $e');
    }
  }

  // Real-time voice modulation
  Future<void> adjustVoiceInRealTime(double stability, double clarity, double style) async {
    // Update current voice settings
    _emotionalVoiceSettings[_currentMood]!['stability'] = stability;
    _emotionalVoiceSettings[_currentMood]!['similarity_boost'] = clarity;
    _emotionalVoiceSettings[_currentMood]!['style'] = style;
  }

  Future<void> stop() async {
    await stopListening();
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
