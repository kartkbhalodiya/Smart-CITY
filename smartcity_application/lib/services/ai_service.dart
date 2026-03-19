import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/ai_training_data.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AssistantReply {
  final String response;
  final String language;
  final String mood;
  final String urgency;
  final String? category;
  final String? subcategory;
  final List<String> missingFields;
  final List<String> actionChecklist;
  final bool isEmergency;
  final double confidence;
  final Map<String, dynamic> complaintDraft;
  final String nextQuestion;

  const AssistantReply({
    required this.response,
    required this.language,
    required this.mood,
    required this.urgency,
    required this.missingFields,
    required this.actionChecklist,
    required this.isEmergency,
    required this.confidence,
    required this.complaintDraft,
    required this.nextQuestion,
    this.category,
    this.subcategory,
  });

  Map<String, dynamic> toMap() => {
        'response': response,
        'language': language,
        'mood': mood,
        'urgency': urgency,
        'category': category,
        'subcategory': subcategory,
        'missingFields': List<String>.from(missingFields),
        'actionChecklist': List<String>.from(actionChecklist),
        'isEmergency': isEmergency,
        'confidence': confidence,
        'complaintDraft': Map<String, dynamic>.from(complaintDraft),
        'nextQuestion': nextQuestion,
      };

  AssistantReply copyWith({
    String? response,
    String? language,
    String? mood,
    String? urgency,
    String? category,
    String? subcategory,
    List<String>? missingFields,
    List<String>? actionChecklist,
    bool? isEmergency,
    double? confidence,
    Map<String, dynamic>? complaintDraft,
    String? nextQuestion,
  }) {
    return AssistantReply(
      response: response ?? this.response,
      language: language ?? this.language,
      mood: mood ?? this.mood,
      urgency: urgency ?? this.urgency,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      missingFields: missingFields ?? this.missingFields,
      actionChecklist: actionChecklist ?? this.actionChecklist,
      isEmergency: isEmergency ?? this.isEmergency,
      confidence: confidence ?? this.confidence,
      complaintDraft: complaintDraft ?? this.complaintDraft,
      nextQuestion: nextQuestion ?? this.nextQuestion,
    );
  }
}

class _OfflineAnalysis {
  final String language;
  final String mood;
  final String urgency;
  final bool isEmergency;
  final String? category;
  final String? subcategory;
  final double confidence;
  final String? locationHint;
  final String? timeHint;
  final List<String> alternatives;
  final List<String> matchedSignals;

  const _OfflineAnalysis({
    required this.language,
    required this.mood,
    required this.urgency,
    required this.isEmergency,
    required this.confidence,
    this.category,
    this.subcategory,
    this.locationHint,
    this.timeHint,
    this.alternatives = const [],
    this.matchedSignals = const [],
  });
}

class _CategoryCandidate {
  final String category;
  final String subcategory;
  final int score;
  final List<String> signals;

  const _CategoryCandidate({
    required this.category,
    required this.subcategory,
    required this.score,
    this.signals = const [],
  });
}

class AIService {
  static const String _geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyAim_9cK7zrtRe0UfNnf3b_wiwugHlOIjc',
  );
  static const String _geminiModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');

  final List<Map<String, String>> _history = [];
  final Map<String, dynamic> _complaintData = {};
  final List<String> _recentResponseFingerprints = [];
  final Random _random = Random();
  final String _sessionId =
      'mobile_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  String _currentLanguage = 'en';
  String _userMood = 'neutral';

  final List<String> _responseOpeners = const [
    'Thanks for sharing this.',
    'I understand your concern.',
    'I am with you on this.',
    'You did the right thing by reporting this.',
    'Let us handle this properly.',
  ];

  final List<String> _responseClosers = const [
    'I will keep this structured and quick.',
    'We can complete this in a few steps.',
    'Share the next detail and I will continue.',
    'I am ready for your next input.',
    'I will guide you till submission.',
  ];

  static const Map<String, List<String>> _categoryAliases = {
    'Road/Pothole': [
      'road issue',
      'road damage',
      'sadak',
      'gadda',
      'pothole',
      'waterlogging'
    ],
    'Drainage/Sewage': [
      'drain',
      'nali',
      'sewer',
      'gutter',
      'manhole',
      'bad smell'
    ],
    'Garbage/Sanitation': [
      'garbage',
      'kachra',
      'kooda',
      'dustbin',
      'sanitation',
      'waste'
    ],
    'Electricity': [
      'bijli',
      'light',
      'power',
      'wire',
      'transformer',
      'street light'
    ],
    'Water Supply': ['water', 'pani', 'tap', 'pipeline', 'leakage', 'pressure'],
    'Traffic': ['traffic', 'signal', 'parking', 'overspeeding', 'wrong side'],
    'Cyber Crime': [
      'cyber',
      'online fraud',
      'upi',
      'scam',
      'phishing',
      'hacked'
    ],
    'Construction': [
      'construction',
      'illegal building',
      'debris',
      'malba',
      'noise pollution'
    ],
  };

  Future<String> processUserInput(String userInput) async {
    return (await processUserInputAdvanced(userInput)).response;
  }

  Future<Map<String, String>?> fetchReengagementNudge() async {
    try {
      final userContext = _loadUserContext();
      final payload = await ApiService.post(
        ApiConfig.aiNudge,
        {
          'session_id': _sessionId,
          'user_name': userContext['user_name'],
          'preferred_language': StorageService.getLocale(),
        },
        includeAuth: false,
      );
      if (payload['success'] != true) return null;
      final title = _asString(payload['title']);
      final body = _asString(payload['body']);
      if (title == null || body == null) return null;
      return {'title': title, 'body': body};
    } catch (_) {
      return null;
    }
  }

  Future<AssistantReply> processUserInputAdvanced(String userInput) async {
    final input = userInput.trim();
    if (input.isEmpty) {
      return _emptyReply();
    }

    _history.add({'role': 'user', 'content': input});
    _currentLanguage = _detectLanguage(input);
    _userMood = _detectMood(input);

    final intentReply = _handleKnowledgeIntent(input);
    if (intentReply != null) {
      final output = _applyResponseVariation(intentReply);
      _history.add({'role': 'assistant', 'content': output.response});
      _trimHistory();
      return output;
    }

    final analysis = _analyzeOffline(input);
    _mergeDraft(analysis, input);

    AssistantReply reply;
    try {
      reply = await _replyFromBackend(input, analysis) ??
          (_geminiApiKey.isEmpty
              ? _offlineReply(analysis)
              : await _replyFromGemini(input, analysis));
    } catch (_) {
      reply = _offlineReply(analysis);
    }

    reply = _applyResponseVariation(reply);

    _currentLanguage = reply.language;
    _userMood = reply.mood;
    _complaintData.addAll(reply.complaintDraft);
    _history.add({'role': 'assistant', 'content': reply.response});
    _trimHistory();
    return reply;
  }

  AssistantReply _emptyReply() {
    return AssistantReply(
      response: _localized(
        en: 'Tell me what issue you want to report. I will guide you step by step.',
        hi: 'कृपया समस्या बताइए, मैं आपको चरण-दर-चरण मदद करूंगी।',
        gu: 'કૃપા કરીને સમસ્યા કહો, હું તમને પગલા પ્રમાણે મદદ કરીશ.',
        hinglish: 'Problem bataiye, main step-by-step help karunga.',
      ),
      language: _currentLanguage,
      mood: 'calm',
      urgency: 'medium',
      category: _complaintData['category'],
      subcategory: _complaintData['subcategory'],
      missingFields: const ['issue_category', 'exact_location'],
      actionChecklist: const ['Describe issue', 'Share exact location'],
      isEmergency: false,
      confidence: 0.3,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: _localized(
        en: 'What issue should I register?',
        hi: 'मैं कौन सी समस्या दर्ज करूं?',
        gu: 'હું કઈ સમસ્યા નોંધાવું?',
        hinglish: 'Kaunsi problem register karun?',
      ),
    );
  }

  _OfflineAnalysis _analyzeOffline(String input) {
    final language = _detectLanguage(input);
    final mood = _detectMood(input);
    final urgency = _detectUrgency(input);
    final emergency = _isEmergency(input, urgency);
    final categoryResult = _detectCategory(input, language);
    final alternatives = (categoryResult['alternatives'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final matchedSignals = (categoryResult['matched_signals'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];

    return _OfflineAnalysis(
      language: language,
      mood: mood,
      urgency: urgency,
      isEmergency: emergency,
      category: categoryResult['category'] as String?,
      subcategory: categoryResult['subcategory'] as String?,
      confidence: categoryResult['confidence'] as double,
      locationHint: _extractLocation(input),
      timeHint: _extractTime(input),
      alternatives: alternatives,
      matchedSignals: matchedSignals,
    );
  }

  Future<AssistantReply?> _replyFromBackend(
    String userInput,
    _OfflineAnalysis analysis,
  ) async {
    final userContext = _loadUserContext();
    final payload = await ApiService.post(
      ApiConfig.aiChat,
      {
        'message': userInput,
        'session_id': _sessionId,
        'user_name': userContext['user_name'],
        'user_email': userContext['user_email'],
        'preferred_language': StorageService.getLocale(),
      },
      includeAuth: false,
    );
    if (payload['success'] != true) return null;

    final responseText = _asString(payload['response']);
    if (responseText == null) return null;

    final language = _normalizeLanguage(
      _mapBackendLanguage(_asString(payload['language']) ?? analysis.language),
    );
    final mood = _normalizeMood(_asString(payload['emotion']) ?? analysis.mood);
    final urgency =
        _normalizeUrgency(_asString(payload['urgency']) ?? analysis.urgency);
    final category =
        _asString(payload['detected_category']) ?? analysis.category;
    final subcategory =
        _asString(payload['subcategory']) ?? analysis.subcategory;
    final isEmergency = payload['analysis'] is Map &&
            (payload['analysis'] as Map)['is_emergency'] == true ||
        analysis.isEmergency;

    final missingFields = _asStringList(payload['missing_fields']);
    final safeMissing =
        missingFields.isEmpty ? _missingFields(analysis) : missingFields;
    final actionChecklist = _asStringList(payload['action_checklist']);
    final safeActions =
        actionChecklist.isEmpty ? _actions(analysis) : actionChecklist;

    final draft = Map<String, dynamic>.from(_complaintData);
    if (category != null) draft['category'] = category;
    if (subcategory != null) draft['subcategory'] = subcategory;
    if (analysis.locationHint != null) {
      draft['location_hint'] = analysis.locationHint;
    }
    if (analysis.timeHint != null) draft['time_hint'] = analysis.timeHint;
    draft['urgency'] = urgency;
    draft['is_emergency'] = isEmergency;

    final nextQuestion = _asString(payload['next_question']) ??
        _nextQuestion(
          analysis,
          safeMissing,
        );

    return AssistantReply(
      response: _humanize(responseText, mood, urgency),
      language: language,
      mood: mood,
      urgency: urgency,
      category: category,
      subcategory: subcategory,
      missingFields: safeMissing,
      actionChecklist: safeActions,
      isEmergency: isEmergency,
      confidence: _confidence(analysis.confidence, safeMissing.length),
      complaintDraft: draft,
      nextQuestion: nextQuestion,
    );
  }

  Map<String, String?> _loadUserContext() {
    try {
      final raw = StorageService.getUserData();
      if (raw == null || raw.trim().isEmpty) {
        return {'user_name': null, 'user_email': null};
      }
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      final firstName = _asString(obj['first_name'])?.trim();
      final lastName = _asString(obj['last_name'])?.trim();
      final fullName = [firstName, lastName]
          .where((part) => part != null && part.isNotEmpty)
          .join(' ')
          .trim();
      return {
        'user_name': fullName.isEmpty ? _asString(obj['username']) : fullName,
        'user_email': _asString(obj['email']),
      };
    } catch (_) {
      return {'user_name': null, 'user_email': null};
    }
  }

  String _mapBackendLanguage(String value) {
    switch (value.trim().toLowerCase()) {
      case 'hindi':
        return 'hi';
      case 'gujarati':
        return 'gu';
      case 'hinglish':
        return 'hinglish';
      case 'english':
      default:
        return 'en';
    }
  }

  Future<AssistantReply> _replyFromGemini(
    String userInput,
    _OfflineAnalysis analysis,
  ) async {
    final response = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1/models/$_geminiModel:generateContent?key=$_geminiApiKey',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': _buildGeminiPrompt(userInput, analysis),
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.6,
              'topK': 32,
              'topP': 0.9,
              'maxOutputTokens': 800
            }
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      return _offlineReply(analysis);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractModelText(payload);
    final jsonText = _extractJson(text);
    if (jsonText == null) {
      return _offlineReply(analysis, modelTextFallback: text);
    }

    final obj = jsonDecode(jsonText) as Map<String, dynamic>;
    return _fromModelObject(obj, analysis);
  }

  AssistantReply _fromModelObject(
    Map<String, dynamic> obj,
    _OfflineAnalysis analysis,
  ) {
    final language =
        _normalizeLanguage(_asString(obj['language']) ?? analysis.language);
    final mood = _normalizeMood(_asString(obj['mood']) ?? analysis.mood);
    final urgency =
        _normalizeUrgency(_asString(obj['urgency']) ?? analysis.urgency);
    final category = _asString(obj['category']) ?? analysis.category;
    final subcategory = _asString(obj['subcategory']) ?? analysis.subcategory;

    final missing = _asStringList(obj['missing_fields']);
    final safeMissing = missing.isEmpty ? _missingFields(analysis) : missing;
    final actions = _asStringList(obj['action_checklist']);
    final safeActions = actions.isEmpty ? _actions(analysis) : actions;

    final response =
        _asString(obj['response_text']) ?? _offlineReply(analysis).response;
    final nextQuestion =
        _asString(obj['next_question']) ?? _nextQuestion(analysis, safeMissing);

    final draft = Map<String, dynamic>.from(_complaintData);
    if (category != null) {
      draft['category'] = category;
    }
    if (subcategory != null) {
      draft['subcategory'] = subcategory;
    }
    if (analysis.locationHint != null) {
      draft['location_hint'] = analysis.locationHint;
    }
    if (analysis.timeHint != null) {
      draft['time_hint'] = analysis.timeHint;
    }
    draft['urgency'] = urgency;
    draft['is_emergency'] = obj['safety_alert'] == true || analysis.isEmergency;

    return AssistantReply(
      response: _humanize(response, mood, urgency),
      language: language,
      mood: mood,
      urgency: urgency,
      category: category,
      subcategory: subcategory,
      missingFields: safeMissing,
      actionChecklist: safeActions,
      isEmergency: draft['is_emergency'] == true,
      confidence: _confidence(analysis.confidence, safeMissing.length),
      complaintDraft: draft,
      nextQuestion: nextQuestion,
    );
  }

  AssistantReply _offlineReply(_OfflineAnalysis analysis,
      {String? modelTextFallback}) {
    final missing = _missingFields(analysis);
    final nextQuestion = _nextQuestion(analysis, missing);
    final actions = _actions(analysis);

    final content = modelTextFallback?.trim().isNotEmpty == true
        ? modelTextFallback!.trim()
        : _baseMessage(analysis);

    final draft = Map<String, dynamic>.from(_complaintData);
    if (analysis.category != null) {
      draft['category'] = analysis.category;
    }
    if (analysis.subcategory != null) {
      draft['subcategory'] = analysis.subcategory;
    }
    if (analysis.locationHint != null) {
      draft['location_hint'] = analysis.locationHint;
    }
    if (analysis.timeHint != null) {
      draft['time_hint'] = analysis.timeHint;
    }
    draft['urgency'] = analysis.urgency;
    draft['is_emergency'] = analysis.isEmergency;
    if (analysis.alternatives.isNotEmpty) {
      draft['category_alternatives'] = analysis.alternatives;
    }
    if (analysis.matchedSignals.isNotEmpty) {
      draft['matched_signals'] = analysis.matchedSignals;
    }

    return AssistantReply(
      response: _humanize(
          '$content\n\n$nextQuestion', analysis.mood, analysis.urgency),
      language: analysis.language,
      mood: _normalizeMood(analysis.mood),
      urgency: _normalizeUrgency(analysis.urgency),
      category: analysis.category,
      subcategory: analysis.subcategory,
      missingFields: missing,
      actionChecklist: actions,
      isEmergency: analysis.isEmergency,
      confidence: _confidence(analysis.confidence, missing.length),
      complaintDraft: draft,
      nextQuestion: nextQuestion,
    );
  }

  String _baseMessage(_OfflineAnalysis analysis) {
    if (analysis.isEmergency) {
      return _localized(
        en: 'Your safety comes first. If there is immediate danger, call 112 now.',
        hi: 'Suraksha sabse pehle hai. Turant khatra ho to abhi 112 call karein.',
        gu: 'Suraksha pehla chhe. Turant jokham hoy to 112 par call karo.',
        hinglish: 'Safety first. Immediate danger ho to abhi 112 call kariye.',
      );
    }
    if (analysis.category == null && analysis.alternatives.isNotEmpty) {
      final options = analysis.alternatives.take(3).join(', ');
      return _localized(
        en: 'I found close matches: $options. Please confirm the best one so I can file correctly.',
        hi: 'Mujhe close matches mile: $options. Sahi option confirm kijiye.',
        gu: 'Mane close matches malya: $options. Sacho option confirm karo.',
        hinglish:
            'Mujhe close matches mile: $options. Sahi option confirm karo.',
      );
    }
    if (analysis.category != null) {
      final confidenceLabel = analysis.confidence < 0.5
          ? 'Likely'
          : analysis.confidence < 0.75
              ? 'Probable'
              : 'Detected';
      final signalText = analysis.matchedSignals.isNotEmpty
          ? ' (signals: ${analysis.matchedSignals.take(3).join(', ')})'
          : '';
      return _localized(
        en: '$confidenceLabel match: ${analysis.subcategory ?? analysis.category}$signalText. I will file this correctly with you.',
        hi: '$confidenceLabel match: ${analysis.subcategory ?? analysis.category}$signalText. Main ise sahi tarike se file karunga.',
        gu: '$confidenceLabel match: ${analysis.subcategory ?? analysis.category}$signalText. Hu aa ne sachi rite file karish.',
        hinglish:
            '$confidenceLabel match: ${analysis.subcategory ?? analysis.category}$signalText. Main proper filing mein help karunga.',
      );
    }
    return _localized(
      en: 'I am here to help. Tell me the exact issue in one line.',
      hi: 'Main madad ke liye yahan hoon. Kripya issue ek line mein batayein.',
      gu: 'Hu madad mate chhu. Krupaya issue ek line ma kaho.',
      hinglish: 'Main help ke liye hoon. Problem ek line mein batao.',
    );
  }

  AssistantReply? _handleKnowledgeIntent(String input) {
    if (_isFullCatalogIntent(input)) {
      return _fullCategoryHierarchyReply();
    }
    if (_isCategoryCatalogIntent(input)) {
      return _categoryCatalogReply();
    }
    if (_isSubcategoryIntent(input)) {
      final category = _extractRequestedCategory(input);
      if (category != null) {
        return _subcategoryCatalogReply(category);
      }
      return _subcategoryNeedCategoryReply();
    }
    return null;
  }

  bool _isCategoryCatalogIntent(String input) {
    final lower = input.toLowerCase();
    return RegExp(
      r'\b(category|categories|catagory|catogory|catgory|issue type|types of issue|what can i report|show categories|list categories|issue categories)\b',
    ).hasMatch(lower);
  }

  bool _isSubcategoryIntent(String input) {
    final lower = input.toLowerCase();
    return RegExp(
      r'\b(subcategory|subcategories|sub category|subcatgory|sub catgory|under|inside|issues in|types in)\b',
    ).hasMatch(lower);
  }

  bool _isFullCatalogIntent(String input) {
    final lower = input.toLowerCase();
    return RegExp(
      r'\b(full list|complete list|all categories|all subcategories|entire catalog|full catalog|all category and subcategory)\b',
    ).hasMatch(lower);
  }

  String? _extractRequestedCategory(String input) {
    final matches = _rankCategoryMatches(input, limit: 3);
    if (matches.isEmpty) return null;
    final top = matches.first;
    if ((top['score'] as int) < 2) return null;
    return top['category'] as String;
  }

  List<Map<String, dynamic>> _rankCategoryMatches(
    String input, {
    int limit = 3,
  }) {
    final normalized = _normalize(input);
    final scored = <Map<String, dynamic>>[];
    for (final raw in complaintCategories.keys) {
      final category = raw.toString();
      final catKey = _normalize(category);
      int score = 0;
      if (normalized.contains(catKey)) {
        score += 8;
      }
      for (final token in catKey.split(' ')) {
        if (token.length < 4) continue;
        if (normalized.contains(token)) score += 1;
      }
      for (final alias in _categoryAliases[category] ?? const <String>[]) {
        final a = _normalize(alias);
        if (a.isNotEmpty && normalized.contains(a)) {
          score += 3;
        }
      }
      if (score > 0) {
        scored.add({'category': category, 'score': score});
      }
    }
    scored.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );
    return scored.take(limit).toList();
  }

  AssistantReply _categoryCatalogReply() {
    final categories = complaintCategories.entries
        .map(
          (entry) => {
            'name': entry.key.toString(),
            'count': entry.value is Map ? (entry.value as Map).length : 0,
          },
        )
        .toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final lines = categories
        .map((entry) => '- ${entry['name']} (${entry['count']} subcategories)')
        .join('\n');
    final response = _localized(
      en: 'You can report complaints in these categories:\n$lines\n\nSay any category name and I will show all subcategories.',
      hi: 'Aap in categories me complaint kar sakte hain:\n$lines\n\nKoi bhi category ka naam boliye, main subcategories dikhaunga.',
      gu: 'Tame aa categories ma fariyad kari shako cho:\n$lines\n\nCategory nu naam kaho, hu subcategories batavish.',
      hinglish:
          'Aap in categories mein complaint kar sakte ho:\n$lines\n\nCategory ka naam bolo, main subcategories dikha dunga.',
    );

    return AssistantReply(
      response: response,
      language: _currentLanguage,
      mood: 'neutral',
      urgency: 'medium',
      category: _complaintData['category'],
      subcategory: _complaintData['subcategory'],
      missingFields: const ['issue_description'],
      actionChecklist: const ['Share issue details and location'],
      isEmergency: false,
      confidence: 0.96,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: _localized(
        en: 'Tell me your exact issue; I will map the right subcategory.',
        hi: 'Apni exact problem batayein, main sahi subcategory map karunga.',
        gu: 'Tamari exact samasya kaho, hu sachi subcategory map karish.',
        hinglish: 'Exact issue batao, main sahi subcategory map kar dunga.',
      ),
    );
  }

  AssistantReply _subcategoryCatalogReply(String category) {
    final subs = complaintCategories[category];
    if (subs is! Map) {
      return _subcategoryNeedCategoryReply();
    }

    final lines = <String>[];
    for (final entry in subs.entries) {
      final subName = entry.key.toString();
      final detail = entry.value;
      if (detail is Map && detail['keywords'] is Map) {
        final kwMap = detail['keywords'] as Map;
        final sample = (kwMap['en'] is List)
            ? (kwMap['en'] as List).whereType<String>().take(2).join(', ')
            : '';
        if (sample.isNotEmpty) {
          lines.add('- $subName -> $sample');
          continue;
        }
      }
      lines.add('- $subName');
    }

    final response = _localized(
      en: '$category includes these subcategories:\n${lines.join('\n')}',
      hi: '$category ke under ye subcategories aati hain:\n${lines.join('\n')}',
      gu: '$category ma aa subcategories aave chhe:\n${lines.join('\n')}',
      hinglish:
          '$category ke under ye subcategories aati hain:\n${lines.join('\n')}',
    );

    return AssistantReply(
      response: response,
      language: _currentLanguage,
      mood: 'calm',
      urgency: 'medium',
      category: category,
      subcategory: _complaintData['subcategory'],
      missingFields: const ['issue_subcategory', 'exact_location'],
      actionChecklist: const [
        'Choose matching subcategory',
        'Share exact location and landmark'
      ],
      isEmergency: false,
      confidence: 0.94,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: _localized(
        en: 'Which subcategory best matches your issue?',
        hi: 'Inme se kaunsi subcategory aapke issue se match karti hai?',
        gu: 'Aamathi kai subcategory tamari samasya sathe match thay chhe?',
        hinglish: 'Inme se kaunsi subcategory aapke issue se match karti hai?',
      ),
    );
  }

  AssistantReply _fullCategoryHierarchyReply() {
    final buffer = StringBuffer();
    final categories = complaintCategories.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    for (final categoryEntry in categories) {
      final category = categoryEntry.key.toString();
      final subs = categoryEntry.value;
      if (subs is! Map) continue;
      buffer.writeln('- $category');
      for (final subEntry in subs.entries) {
        final subcategory = subEntry.key.toString();
        final detail = subEntry.value;
        String keywordSample = '';
        if (detail is Map && detail['keywords'] is Map) {
          final keywordMap = detail['keywords'] as Map;
          if (keywordMap['en'] is List) {
            keywordSample = (keywordMap['en'] as List)
                .whereType<String>()
                .take(2)
                .join(', ');
          }
        }
        if (keywordSample.isEmpty) {
          buffer.writeln('  • $subcategory');
        } else {
          buffer.writeln('  • $subcategory -> $keywordSample');
        }
      }
    }

    final response = _localized(
      en: 'Complete category and subcategory catalog:\n${buffer.toString().trim()}',
      hi: 'Complete category and subcategory catalog:\n${buffer.toString().trim()}',
      gu: 'Complete category and subcategory catalog:\n${buffer.toString().trim()}',
      hinglish:
          'Complete category and subcategory catalog:\n${buffer.toString().trim()}',
    );

    return AssistantReply(
      response: response,
      language: _currentLanguage,
      mood: 'calm',
      urgency: 'medium',
      category: _complaintData['category'],
      subcategory: _complaintData['subcategory'],
      missingFields: const ['issue_description'],
      actionChecklist: const ['Share exact issue so I can map it'],
      isEmergency: false,
      confidence: 0.98,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: _localized(
        en: 'Now tell me your exact complaint in one line.',
        hi: 'Ab apni exact complaint ek line me batayein.',
        gu: 'Have tamari exact complaint ek line ma kaho.',
        hinglish: 'Ab exact complaint ek line me batao.',
      ),
    );
  }

  AssistantReply _subcategoryNeedCategoryReply() {
    final categories =
        complaintCategories.keys.map((e) => e.toString()).toList()..sort();
    final categoryText = categories.join(', ');
    return AssistantReply(
      response: _localized(
        en: 'Please tell me the category name first. Available categories: $categoryText.',
        hi: 'Pehle category ka naam batayein. Available categories: $categoryText.',
        gu: 'Pehla category nu naam kaho. Available categories: $categoryText.',
        hinglish:
            'Pehle category ka naam batao. Available categories: $categoryText.',
      ),
      language: _currentLanguage,
      mood: 'neutral',
      urgency: 'medium',
      category: _complaintData['category'],
      subcategory: _complaintData['subcategory'],
      missingFields: const ['issue_category'],
      actionChecklist: const ['Choose a category first'],
      isEmergency: false,
      confidence: 0.85,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: _localized(
        en: 'Which category do you want details for?',
        hi: 'Aap kis category ki details chahte hain?',
        gu: 'Tamne kai category ni details joiye chhe?',
        hinglish: 'Aap kis category ki details chahte ho?',
      ),
    );
  }

  AssistantReply _applyResponseVariation(AssistantReply reply) {
    final fingerprint =
        reply.response.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final alreadySeen = _recentResponseFingerprints.contains(fingerprint);

    var output = reply;
    if (alreadySeen || _random.nextDouble() < 0.35) {
      final opener = _responseOpeners[_random.nextInt(_responseOpeners.length)];
      final closer = _responseClosers[_random.nextInt(_responseClosers.length)];
      output = reply.copyWith(response: '$opener ${reply.response}\n\n$closer');
    }

    _recentResponseFingerprints.add(fingerprint);
    if (_recentResponseFingerprints.length > 8) {
      _recentResponseFingerprints.removeAt(0);
    }

    return output;
  }

  String _buildGeminiPrompt(String userInput, _OfflineAnalysis analysis) {
    final historyText =
        _history.map((h) => "${h['role']}: ${h['content']}").join('\n');
    final categoryCatalog = _buildCategoryCatalogForPrompt();
    final draft = Map<String, dynamic>.from(_complaintData);
    if (analysis.category != null) {
      draft['category'] = analysis.category;
    }
    if (analysis.subcategory != null) {
      draft['subcategory'] = analysis.subcategory;
    }
    if (analysis.locationHint != null) {
      draft['location_hint'] = analysis.locationHint;
    }
    if (analysis.timeHint != null) {
      draft['time_hint'] = analysis.timeHint;
    }
    draft['urgency'] = analysis.urgency;
    draft['is_emergency'] = analysis.isEmergency;

    return '''
You are JanHelp, a compassionate Smart City civic assistant.
Reply with JSON only using fields:
language, mood, urgency, category, subcategory, missing_fields, action_checklist, next_question, response_text, safety_alert

Rules:
- Mirror user language (en/hi/gu/hinglish)
- Keep response friendly and human
- Keep response context-rich and informative, not generic
- Avoid repeating the same wording from prior turns
- Ask only one next question
- For danger, advise emergency safety first
- Use the exact category and subcategory names from the catalog below when possible
- If user asks for categories/subcategories/full catalog, answer directly from catalog with complete coverage
- If detection is ambiguous, mention top alternatives and ask user to confirm one option

Category catalog:
$categoryCatalog

Detected analysis:
language=${analysis.language}, mood=${analysis.mood}, urgency=${analysis.urgency}, emergency=${analysis.isEmergency}, category=${analysis.category}, subcategory=${analysis.subcategory}, location_hint=${analysis.locationHint}, alternatives=${analysis.alternatives.join(', ')}, matched_signals=${analysis.matchedSignals.join(', ')}

Complaint draft:
${jsonEncode(draft)}

Conversation:
$historyText

Latest user message:
$userInput
''';
  }

  String _buildCategoryCatalogForPrompt() {
    final catalog = <String>[];
    complaintCategories.forEach((category, value) {
      if (value is! Map) return;
      final subs = value.keys.map((e) => e.toString()).join(', ');
      catalog.add('$category => [$subs]');
    });
    return catalog.join('\n');
  }

  String _extractModelText(Map<String, dynamic> payload) {
    final candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final candidate = candidates.first;
    if (candidate is! Map) return '';
    final content = candidate['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return '';
    final part = parts.first;
    if (part is! Map) return '';
    return (part['text'] as String?)?.trim() ?? '';
  }

  String? _extractJson(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fenced != null) {
      final inside = fenced.group(1)?.trim();
      if (inside != null && inside.startsWith('{') && inside.endsWith('}')) {
        return inside;
      }
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return text.substring(start, end + 1);
    return null;
  }

  List<String> _missingFields(_OfflineAnalysis analysis) {
    final out = <String>[];
    if ((analysis.category ?? _complaintData['category']) == null) {
      out.add('issue_category');
    }
    if ((analysis.locationHint ?? _complaintData['location_hint']) == null) {
      out.add('exact_location');
    }
    if ((analysis.timeHint ?? _complaintData['time_hint']) == null &&
        _looksRecurring()) {
      out.add('issue_timing');
    }
    return out;
  }

  List<String> _actions(_OfflineAnalysis analysis) {
    if (analysis.isEmergency) {
      return const [
        'Call emergency helpline 112 if danger is immediate',
        'Stay at safe distance',
        'Share exact location for quick response',
      ];
    }
    if (analysis.category == null && analysis.alternatives.isNotEmpty) {
      return [
        'Choose the closest issue type: ${analysis.alternatives.take(3).join(', ')}',
        'Share exact location and landmark',
        'Add one photo if possible for faster verification',
      ];
    }
    return [
      if (analysis.category != null)
        'Issue tagged as ${analysis.subcategory ?? analysis.category}'
      else
        'Confirm issue category',
      'Share exact location and landmark',
      'Add photo/video evidence if available',
    ];
  }

  String _nextQuestion(_OfflineAnalysis analysis, List<String> missing) {
    if (analysis.isEmergency && missing.contains('exact_location')) {
      return _localized(
        en: 'Please share exact location right now.',
        hi: 'कृपया तुरंत सही लोकेशन बताएं।',
        gu: 'કૃપા કરીને તરત ચોક્કસ લોકેશન આપો.',
        hinglish: 'Please abhi exact location bataiye.',
      );
    }
    if (missing.isEmpty) {
      return _localized(
        en: 'Should I summarize this and prepare it for submission?',
        hi: 'क्या मैं इसका सारांश बनाकर सबमिट के लिए तैयार करूं?',
        gu: 'શું હું આનો સાર બનાવી સબમિટ માટે તૈયાર કરું?',
        hinglish: 'Kya main summary bana kar submit ke liye ready karun?',
      );
    }

    switch (missing.first) {
      case 'issue_category':
        if (analysis.alternatives.isNotEmpty) {
          final options = analysis.alternatives.take(3).join(', ');
          return _localized(
            en: 'Please choose the closest option: $options. If none match, tell me your issue in different words.',
            hi: 'Kripya sabse close option chuniye: $options. Agar match na ho to issue alag shabdon me batayein.',
            gu: 'Krupaya najik no option pasand karo: $options. Match na thay to issue bija shabdo ma kaho.',
            hinglish:
                'Please sabse close option choose karo: $options. Match na ho to issue alag words me batao.',
          );
        }
        return _localized(
          en: 'Is this related to police, traffic, construction, water, electricity, garbage, road, drainage, illegal activity, transportation, cyber crime, or other?',
          hi: 'क्या यह सड़क, ड्रेनेज, पानी, बिजली, कचरा या ट्रैफिक से जुड़ा है?',
          gu: 'શું આ રસ્તા, ડ્રેનેજ, પાણી, વીજળી, કચરો કે ટ્રાફિક સાથે સંબંધિત છે?',
          hinglish:
              'Yeh police, traffic, construction, water, electricity, garbage, road, drainage, illegal activity, transportation, cyber crime ya other se related hai?',
        );
      case 'exact_location':
        return _localized(
          en: 'Please share exact area, street, and nearby landmark.',
          hi: 'कृपया सही एरिया, सड़क और पास का लैंडमार्क बताएं।',
          gu: 'કૃપા કરીને ચોક્કસ વિસ્તાર, રસ્તો અને નજીકનો લૅન્ડમાર્ક કહો.',
          hinglish: 'Please exact area, street aur nearby landmark bataiye.',
        );
      default:
        return _localized(
          en: 'Please share one more detail so I can file this correctly.',
          hi: 'कृपया एक और जानकारी दें ताकि शिकायत सही दर्ज हो सके।',
          gu: 'કૃપા કરીને એક વધુ માહિતી આપો જેથી ફરિયાદ યોગ્ય રીતે નોંધાય.',
          hinglish:
              'Please ek aur detail share karein taki complaint sahi file ho.',
        );
    }
  }

  String _humanize(String text, String mood, String urgency) {
    final body = text.trim();
    if (body.isEmpty) return body;
    if (urgency == 'critical') {
      return '${_localized(en: 'I am with you right now.', hi: 'मैं अभी आपके साथ हूं।', gu: 'હું અત્યારે તમારી સાથે છું.', hinglish: 'Main abhi aapke saath hoon.')} $body';
    }
    if (mood == 'angry' || mood == 'frustrated') {
      return '${_localized(en: 'I hear your frustration.', hi: 'मैं आपकी परेशानी समझ रही हूं।', gu: 'હું તમારી તકલીફ સમજી રહી છું.', hinglish: 'Main aapki frustration samajh raha hoon.')} $body';
    }
    if (mood == 'sad') {
      return '${_localized(en: 'I am sorry this happened.', hi: 'मुझे अफसोस है कि यह हुआ।', gu: 'મને દુઃખ છે કે આવું થયું.', hinglish: 'Mujhe afsos hai ki yeh hua.')} $body';
    }
    return body;
  }

  void _mergeDraft(_OfflineAnalysis analysis, String userInput) {
    if (analysis.category != null) {
      _complaintData['category'] = analysis.category;
    }
    if (analysis.subcategory != null) {
      _complaintData['subcategory'] = analysis.subcategory;
    }
    if (analysis.locationHint != null) {
      _complaintData['location_hint'] = analysis.locationHint;
    }
    if (analysis.timeHint != null) {
      _complaintData['time_hint'] = analysis.timeHint;
    }
    if (analysis.alternatives.isNotEmpty) {
      _complaintData['category_alternatives'] = analysis.alternatives;
    }
    if (analysis.matchedSignals.isNotEmpty) {
      _complaintData['matched_signals'] = analysis.matchedSignals;
    }
    _complaintData['urgency'] = analysis.urgency;
    _complaintData['is_emergency'] = analysis.isEmergency;
    _complaintData['last_user_message'] = userInput;
    _complaintData['updated_at'] = DateTime.now().toIso8601String();
  }

  Map<String, Object?> _detectCategory(String input, String language) {
    final normalized = _normalize(input);
    final keys = _langKeys(language);
    final candidates = <_CategoryCandidate>[];

    complaintCategories.forEach((category, subs) {
      if (subs is! Map) return;
      final categoryName = category.toString();
      subs.forEach((subcategory, detail) {
        if (detail is! Map) return;
        final subcategoryName = subcategory.toString();
        final keywordMap = detail['keywords'];
        if (keywordMap is! Map) return;

        final signals = <String>[];
        int score = 0;

        final normalizedCategory = _normalize(categoryName);
        final normalizedSubcategory = _normalize(subcategoryName);
        if (normalized.contains(normalizedCategory)) {
          score += 4;
          signals.add(categoryName);
        }
        if (normalized.contains(normalizedSubcategory)) {
          score += 6;
          signals.add(subcategoryName);
        }

        final aliases = _categoryAliases[categoryName] ?? const <String>[];
        for (final alias in aliases) {
          final normalizedAlias = _normalize(alias);
          if (normalizedAlias.isEmpty) continue;
          if (normalized.contains(normalizedAlias)) {
            score += normalizedAlias.contains(' ') ? 4 : 2;
            signals.add(alias);
          }
        }

        final keywords = <String>[];
        for (final key in keys) {
          final list = keywordMap[key];
          if (list is List) {
            keywords.addAll(list.whereType<String>());
          }
        }
        score += _keywordScore(
          normalized,
          keywords,
          matchedSignals: signals,
        );

        if (score <= 0) return;
        final cleanSignals = signals
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .take(6)
            .toList();
        candidates.add(
          _CategoryCandidate(
            category: categoryName,
            subcategory: subcategoryName,
            score: score,
            signals: cleanSignals,
          ),
        );
      });
    });

    if (candidates.isEmpty) {
      final rankedCategories = _rankCategoryMatches(input);
      return {
        'category': null,
        'subcategory': null,
        'confidence': 0.0,
        'alternatives':
            rankedCategories.map((e) => e['category'] as String).toList(),
        'matched_signals': const <String>[],
      };
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    final second = candidates.length > 1 ? candidates[1].score : 0;
    final confidence =
        max(0.24, min(0.96, best.score / max(1, best.score + second)));
    final alternatives = candidates
        .skip(1)
        .where((candidate) => candidate.score >= max(2, best.score - 3))
        .map(_formatCandidateLabel)
        .toSet()
        .take(3)
        .toList();

    return {
      'category': best.category,
      'subcategory': best.subcategory,
      'confidence': confidence,
      'alternatives': alternatives,
      'matched_signals': best.signals.take(4).toList(),
    };
  }

  String _formatCandidateLabel(_CategoryCandidate candidate) {
    return '${candidate.subcategory} (${candidate.category})';
  }

  int _keywordScore(
    String input,
    List<String> keywords, {
    List<String>? matchedSignals,
  }) {
    int score = 0;
    for (final keyword in keywords) {
      final key = _normalize(keyword);
      if (key.isEmpty) continue;
      if (input.contains(key)) {
        score += key.contains(' ') ? 4 : 2;
        matchedSignals?.add(keyword);
      } else {
        final overlap = _tokenOverlap(input, key);
        if (overlap >= 0.75) {
          score += 1;
          matchedSignals?.add(keyword);
        }
      }
    }
    return score;
  }

  double _tokenOverlap(String input, String keyword) {
    final i = input.split(' ').where((e) => e.length > 2).toSet();
    final k = keyword.split(' ').where((e) => e.length > 2).toSet();
    if (i.isEmpty || k.isEmpty) return 0;
    return k.where(i.contains).length / k.length;
  }

  String _detectLanguage(String input) {
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(input)) return 'gu';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(input)) return 'hi';
    if (_looksHinglish(input)) return 'hinglish';
    return 'en';
  }

  bool _looksHinglish(String input) {
    final lower = input.toLowerCase();
    const words = ['aap', 'mujhe', 'nahi', 'kya', 'problem', 'pani', 'bijli'];
    return RegExp(r'[a-z]').hasMatch(lower) &&
        words.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(lower));
  }

  String _detectMood(String input) {
    final lower = input.toLowerCase();
    if (RegExp(r'\b(angry|mad|furious|annoyed|gussa)\b').hasMatch(lower)) {
      return 'angry';
    }
    if (RegExp(r'\b(frustrated|irritated|pareshan)\b').hasMatch(lower)) {
      return 'frustrated';
    }
    if (RegExp(r'\b(sad|disappointed|upset)\b').hasMatch(lower)) {
      return 'sad';
    }
    if (RegExp(r'\b(urgent|emergency|asap|jaldi)\b').hasMatch(lower)) {
      return 'urgent';
    }
    return 'neutral';
  }

  String _detectUrgency(String input) {
    final lower = input.toLowerCase();
    if (RegExp(r'\b(fire|electrocution|accident|explosion|serious injury)\b')
        .hasMatch(lower)) {
      return 'critical';
    }
    if (RegExp(r'\b(emergency|urgent|danger|unsafe|immediate)\b')
        .hasMatch(lower)) {
      return 'high';
    }
    return 'medium';
  }

  bool _isEmergency(String input, String urgency) {
    if (urgency == 'critical') return true;
    final lower = input.toLowerCase();
    return RegExp(r'\b(help now|not safe|live wire|gas leak)\b')
        .hasMatch(lower);
  }

  String? _extractLocation(String input) {
    final lower = input.toLowerCase();
    final m = RegExp(
            r'\b(?:at|near|in|on|around|beside|opposite)\s+([a-z0-9 ,.-]{3,80})')
        .firstMatch(lower);
    final out = m?.group(1)?.trim();
    if (out == null || out.isEmpty) return null;
    return out.replaceAll(RegExp(r'[.,;!?]+$'), '');
  }

  String? _extractTime(String input) {
    final lower = input.toLowerCase();
    final m = RegExp(
            r'\b(today|yesterday|tonight|this morning|this evening|last night|\d+\s*(?:hour|hours|day|days|week|weeks)\s*(?:ago)?)\b')
        .firstMatch(lower);
    return m?.group(0);
  }

  bool _looksRecurring() {
    final last = (_complaintData['last_user_message'] as String?) ?? '';
    return RegExp(r'\b(every day|daily|again|still not fixed|for many days)\b')
        .hasMatch(last.toLowerCase());
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F\u0A80-\u0AFF\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _langKeys(String language) {
    switch (language) {
      case 'hi':
        return ['hi', 'en', 'hinglish', 'guj'];
      case 'gu':
        return ['guj', 'en', 'hinglish', 'hi'];
      case 'hinglish':
        return ['hinglish', 'en', 'hi', 'guj'];
      default:
        return ['en', 'hinglish', 'hi', 'guj'];
    }
  }

  String _normalizeLanguage(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'guj') return 'gu';
    if (v == 'en' || v == 'hi' || v == 'gu' || v == 'hinglish') return v;
    return 'en';
  }

  String _normalizeMood(String value) {
    final v = value.trim().toLowerCase();
    return {
      'neutral',
      'calm',
      'happy',
      'concerned',
      'frustrated',
      'sad',
      'angry',
      'urgent'
    }.contains(v)
        ? v
        : 'neutral';
  }

  String _normalizeUrgency(String value) {
    final v = value.trim().toLowerCase();
    return {'low', 'medium', 'high', 'critical'}.contains(v) ? v : 'medium';
  }

  String? _asString(dynamic value) {
    if (value is! String) return null;
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  double _confidence(double base, int missingCount) {
    final penalty = min(0.45, missingCount * 0.12);
    return max(0.2, min(0.98, base - penalty));
  }

  String _localized(
      {required String en,
      required String hi,
      required String gu,
      required String hinglish}) {
    switch (_currentLanguage) {
      case 'hi':
        return hi;
      case 'gu':
        return gu;
      case 'hinglish':
        return hinglish;
      default:
        return en;
    }
  }

  void _trimHistory() {
    if (_history.length <= 24) return;
    _history.removeRange(0, _history.length - 24);
  }

  Map<String, dynamic> getComplaintData() =>
      Map<String, dynamic>.from(_complaintData);
  String getUserMood() => _userMood;
  String getCurrentLanguage() => _currentLanguage;

  Map<String, dynamic> getSessionInsights() => {
        'language': _currentLanguage,
        'mood': _userMood,
        'complaint_data': Map<String, dynamic>.from(_complaintData),
      };

  void reset() {
    _history.clear();
    _complaintData.clear();
    _currentLanguage = 'en';
    _userMood = 'neutral';
  }
}
