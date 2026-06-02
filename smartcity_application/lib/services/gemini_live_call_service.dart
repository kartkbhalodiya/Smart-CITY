import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiLiveCallService {
  static const String _endpoint =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const String _apiKeyPref = 'gemini_api_key';
  static const String _modelPref = 'gemini_live_model';
  static const String _embeddedApiKey = '';
  static const String _runtimeApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _defaultModel = 'gemini-3.1-flash-live-preview';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const List<String> _candidateApiKeyPrefs = [
    'gemini_api_key',
    'ai_assistant_gemini_api_key',
    'ai_assistance_gemini_api_key',
    'google_ai_api_key',
    'google_api_key',
    'gemini_key',
    'GEMINI_API_KEY',
  ];

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _setupCompleter;
  Completer<String>? _turnCompleter;
  StringBuffer _turnBuffer = StringBuffer();
  bool _isConnecting = false;
  String _sessionUserName = 'Citizen';
  String _sessionCity = 'Smart City';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();

    for (final keyName in _candidateApiKeyPrefs) {
      final sharedValue = prefs.getString(keyName)?.trim();
      if (sharedValue != null && sharedValue.isNotEmpty) {
        return sharedValue;
      }
    }

    for (final keyName in _candidateApiKeyPrefs) {
      final secureValue = (await _secureStorage.read(key: keyName))?.trim();
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    }

    if (_runtimeApiKey.trim().isNotEmpty) {
      return _runtimeApiKey.trim();
    }
    if (_embeddedApiKey.trim().isNotEmpty) {
      return _embeddedApiKey.trim();
    }
    return null;
  }

  static Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = apiKey.trim();
    await prefs.setString(_apiKeyPref, normalized);
    await _secureStorage.write(key: _apiKeyPref, value: normalized);
  }

  static Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString(_modelPref)?.trim();
    if (savedModel != null &&
        savedModel.isNotEmpty &&
        savedModel == _defaultModel) {
      return savedModel;
    }
    return _defaultModel;
  }

  static Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = model.trim().isEmpty ? _defaultModel : model.trim();
    await prefs.setString(_modelPref, normalized);
  }

  static Future<bool> isConfigured() async {
    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  Future<bool> connect({
    required String userName,
    required String city,
  }) async {
    _sessionUserName = userName.trim().isEmpty ? 'Citizen' : userName.trim();
    _sessionCity = city.trim().isEmpty ? 'Smart City' : city.trim();

    if (_socket != null) {
      return true;
    }

    if (_isConnecting) {
      try {
        final pendingSetup = _setupCompleter;
        if (pendingSetup != null) {
          await pendingSetup.future;
        }
        return _socket != null;
      } catch (_) {
        return false;
      }
    }

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return false;
    }

    _isConnecting = true;
    _setupCompleter = Completer<void>();

    try {
      _socket = await WebSocket.connect(
        _endpoint,
        headers: {'x-goog-api-key': apiKey},
      );

      _subscription = _socket!.listen(
        _handleSocketMessage,
        onDone: _handleSocketDone,
        onError: _handleSocketError,
        cancelOnError: false,
      );

      final model = await getModel();
      final setupPayload = {
        'setup': {
          'model': 'models/$model',
          'generationConfig': {
            'responseModalities': ['TEXT'],
            'temperature': 0.35,
            'maxOutputTokens': 160,
          },
          'systemInstruction': _buildSystemInstruction(
            userName: _sessionUserName,
            city: _sessionCity,
          ),
        },
      };

      _socket!.add(jsonEncode(setupPayload));
      await _setupCompleter!.future.timeout(const Duration(seconds: 8));
      return true;
    } catch (error) {
      debugPrint('Gemini Live connect error: $error');
      await close();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<String?> rewriteAssistantReply({
    required String userTranscript,
    required String assistantReply,
    required String step,
    required Map<String, dynamic> complaintData,
    required String userName,
    required String city,
  }) async {
    final connected = await connect(userName: userName, city: city);
    if (!connected || _socket == null) {
      return null;
    }

    final prompt = _buildRewritePrompt(
      userTranscript: userTranscript,
      assistantReply: assistantReply,
      step: step,
      complaintData: complaintData,
    );

    try {
      _turnBuffer = StringBuffer();
      _turnCompleter = Completer<String>();

      final payload = {
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'turnComplete': true,
        },
      };

      _socket!.add(jsonEncode(payload));

      final response = await _turnCompleter!.future.timeout(
        const Duration(seconds: 12),
      );

      final cleaned = sanitizeForSpeech(response);
      return cleaned.isEmpty ? null : cleaned;
    } catch (error) {
      debugPrint('Gemini Live rewrite error: $error');
      _turnCompleter = null;
      return null;
    }
  }

  Future<void> close() async {
    try {
      final activeSubscription = _subscription;
      if (activeSubscription != null) {
        await activeSubscription.cancel();
      }
    } catch (_) {}

    try {
      final activeSocket = _socket;
      if (activeSocket != null) {
        await activeSocket.close();
      }
    } catch (_) {}

    _subscription = null;
    _socket = null;
    _setupCompleter = null;
    _turnCompleter = null;
    _turnBuffer = StringBuffer();
  }

  void _handleSocketMessage(dynamic rawMessage) {
    try {
      final messageString = rawMessage is String
          ? rawMessage
          : utf8.decode(rawMessage as List<int>);
      final message = jsonDecode(messageString);
      if (message is! Map<String, dynamic>) {
        return;
      }

      if (message.containsKey('setupComplete')) {
        _setupCompleter?.complete();
        _setupCompleter = null;
        return;
      }

      final serverContent = message['serverContent'];
      if (serverContent is! Map<String, dynamic>) {
        return;
      }

      final modelTurn = serverContent['modelTurn'];
      if (modelTurn is Map<String, dynamic>) {
        final parts = modelTurn['parts'];
        if (parts is List) {
          for (final part in parts) {
            if (part is Map<String, dynamic> && part['text'] is String) {
              _turnBuffer.write(part['text'] as String);
            }
          }
        }
      }

      if (serverContent['turnComplete'] == true ||
          serverContent['generationComplete'] == true) {
        final reply = _turnBuffer.toString().trim();
        if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
          _turnCompleter!.complete(reply);
        }
        _turnCompleter = null;
      }
    } catch (error) {
      debugPrint('Gemini Live message parse error: $error');
      if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
        _turnCompleter!.completeError(error);
      }
      _turnCompleter = null;
    }
  }

  void _handleSocketDone() {
    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.complete(_turnBuffer.toString().trim());
    }
    _turnCompleter = null;
    _socket = null;
    _subscription = null;
  }

  void _handleSocketError(Object error) {
    debugPrint('Gemini Live socket error: $error');
    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.completeError(error);
    }
    _turnCompleter = null;
  }

  String _buildSystemInstruction({
    required String userName,
    required String city,
  }) {
    return '''
You are JANHELP's live phone-call speaking layer for citizens in $city.
You are speaking to $userName.

Your job:
- Turn structured complaint-assistant replies into natural spoken phone responses.
- Sound warm, calm, respectful, and kind.
- Ask only one question at a time.
- Keep each reply brief and easy to say out loud.
- Preserve the original complaint workflow and facts.
- Never invent complaint details.
- If there is immediate danger, tell the citizen to call 112 right away.
- Return plain spoken text only.
''';
  }

  String _buildRewritePrompt({
    required String userTranscript,
    required String assistantReply,
    required String step,
    required Map<String, dynamic> complaintData,
  }) {
    final snapshot = {
      if ((complaintData['category'] ?? '').toString().isNotEmpty)
        'category': complaintData['category'],
      if ((complaintData['subcategory'] ?? '').toString().isNotEmpty)
        'subcategory': complaintData['subcategory'],
      if ((complaintData['description'] ?? '').toString().isNotEmpty)
        'description': complaintData['description'],
      if ((complaintData['date_noticed'] ?? '').toString().isNotEmpty)
        'date_noticed': complaintData['date_noticed'],
      if ((complaintData['location'] ?? '').toString().isNotEmpty)
        'location': complaintData['location'],
      if ((complaintData['contact_name'] ?? '').toString().isNotEmpty)
        'contact_name': complaintData['contact_name'],
    };

    return '''
Rewrite the structured assistant reply below into a natural phone-call response.

Rules:
- Keep the meaning exactly the same.
- Sound caring and professional.
- Maximum 2 short sentences.
- Ask only the next needed question.
- No markdown.
- No bullet points.
- No labels.
- No emojis.

Current workflow step: $step
Citizen just said: "$userTranscript"
Known complaint data: ${jsonEncode(snapshot)}
Structured assistant reply: "${assistantReply.replaceAll('\n', ' ')}"

Return only the final spoken response.
''';
  }

  static String sanitizeForSpeech(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) {
      return cleaned;
    }

    cleaned = cleaned
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1')
        .replaceAll(String.fromCharCode(0x2022), ' ')
        .replaceAll(RegExp(r'[#>*]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.')
        .trim();

    if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
        (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }

    return cleaned;
  }
}
