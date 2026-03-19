import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/ai_training_data.dart';
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
  final String action;
  final bool showConfirmation;
  final String? confirmationQuestion;

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
    this.action = 'COLLECT_INFO',
    this.showConfirmation = false,
    this.confirmationQuestion,
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
        'action': action,
        'showConfirmation': showConfirmation,
        'confirmationQuestion': confirmationQuestion,
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
    String? action,
    bool? showConfirmation,
    String? confirmationQuestion,
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
      action: action ?? this.action,
      showConfirmation: showConfirmation ?? this.showConfirmation,
      confirmationQuestion: confirmationQuestion ?? this.confirmationQuestion,
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
  AIService._internal();
  static final AIService instance = AIService._internal();
  factory AIService() => instance;

  static const String _groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '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',
  );
  // Using smaller, faster model to avoid rate limits
  static const String _groqModel = 'llama-3.1-8b-instant';
  static const int _groqMaxRetries = 3;
  static const Duration _groqTimeout = Duration(seconds: 25);
  static const Duration _groqInitialBackoff = Duration(milliseconds: 600);
  static const int _groqCacheMaxEntries = 120;

  final List<Map<String, String>> _history = [];
  final Map<String, dynamic> _complaintData = {};
  final LinkedHashMap<String, AssistantReply> _groqResponseCache = LinkedHashMap();
  String _currentLanguage = 'en';
  String _userMood = 'neutral';

  static const Map<String, List<String>> _categoryAliases = {
    'Road/Pothole': [
      'road issue',
      'road damage',
      'sadak',
      'rasta',
      'gadda',
      'pothole',
      'waterlogging',
      'broken road',
      'crack',
      'hole in road',
      'damaged road',
      'crater',
      'pit',
      'road cavity',
      'road flooded',
      'standing water',
      'road blocked',
      'obstruction',
      'cracked road',
      'रोड',
      'रस्ता',
      'गड्ढा',
      'सड़क',
      'टूटी',
      'પાણી',
      'ખાડો',
      'રસ્તો',
      'તૂટેલો'
    ],
    'Drainage/Sewage': [
      'drain',
      'nali',
      'sewer',
      'gutter',
      'manhole',
      'bad smell',
      'overflow',
      'blockage',
      'blocked drain',
      'clogged drain',
      'drain jam',
      'sewer overflow',
      'sewage leak',
      'foul odor',
      'stink',
      'open manhole',
      'manhole cover missing',
      'नाली',
      'गटर',
      'बदबू',
      'मैनहोल',
      'નાળી',
      'ગટર',
      'દુર્ગંધ'
    ],
    'Garbage/Sanitation': [
      'garbage',
      'kachra',
      'kooda',
      'dustbin',
      'sanitation',
      'waste',
      'trash',
      'dirty',
      'gandagi',
      'garbage not collected',
      'trash not picked',
      'overflowing bin',
      'dustbin full',
      'dead animal',
      'littering',
      'dumping waste',
      'कचरा',
      'कूड़ा',
      'गंदगी',
      'डस्टबिन',
      'કચરો',
      'ગંદકી'
    ],
    'Electricity': [
      'bijli',
      'light',
      'power',
      'wire',
      'transformer',
      'street light',
      'power cut',
      'no electricity',
      'blackout',
      'power outage',
      'street lamp',
      'pole light',
      'exposed wire',
      'hanging wire',
      'dangerous wire',
      'transformer problem',
      'बिजली',
      'लाइट',
      'पावर',
      'तार',
      'વીજળી',
      'લાઇટ'
    ],
    'Water Supply': [
      'water',
      'pani',
      'tap',
      'pipeline',
      'leakage',
      'pressure',
      'no water',
      'water not coming',
      'tap dry',
      'water leak',
      'pipe leak',
      'dirty water',
      'contaminated water',
      'muddy water',
      'low pressure',
      'weak water flow',
      'पानी',
      'नल',
      'લીક',
      'પાણી'
    ],
    'Traffic': [
      'traffic',
      'signal',
      'parking',
      'overspeeding',
      'wrong side',
      'accident',
      'illegal parking',
      'wrong parking',
      'blocking road',
      'broken signal',
      'traffic light broken',
      'signal off',
      'one way violation',
      'fast driving',
      'rash driving',
      'ટ્રાફિક',
      'સિગ્નલ',
      'પાર્કિંગ',
      'यातायात',
      'सिग्नल'
    ],
    'Cyber Crime': [
      'cyber',
      'online fraud',
      'upi',
      'scam',
      'phishing',
      'hacked',
      'digital fraud',
      'fraud',
      'cheating',
      'money lost',
      'upi fraud',
      'payment scam',
      'phonepe fraud',
      'paytm fraud',
      'fake link',
      'suspicious link',
      'spam message',
      'identity theft',
      'account hacked',
      'data stolen',
      'धोखा',
      'ठगी',
      'फ्रॉड',
      'છેતરપિંડી'
    ],
    'Construction': [
      'construction',
      'illegal building',
      'debris',
      'malba',
      'noise pollution',
      'unauthorized',
      'illegal construction',
      'unauthorized construction',
      'construction waste',
      'rubble',
      'construction noise',
      'loud noise',
      'drilling sound',
      'निर्माण',
      'मलबा',
      'शोर',
      'બાંધકામ',
      'મલબો',
      'ઘોંઘાટ'
    ],
  };

  Future<String> processUserInput(String userInput) async {
    return (await processUserInputAdvanced(userInput)).response;
  }

  Future<Map<String, String>?> fetchReengagementNudge() async {
    // Nudge is generated locally — no backend call needed
    return {
      'title': 'Your complaint is almost ready 📝',
      'body': 'Come back and finish filing your complaint with JanHelp.',
    };
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
      _history.add({'role': 'assistant', 'content': intentReply.response});
      _trimHistory();
      return intentReply;
    }

    final analysis = _analyzeOffline(input);
    _mergeDraft(analysis, input);

    AssistantReply reply;
    try {
      reply = _groqApiKey.isEmpty
          ? _offlineReply(analysis)
          : await _replyFromGroq(input, analysis);
    } catch (_) {
      reply = _offlineReply(analysis);
    }

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

  Future<AssistantReply> _replyFromGroq(
    String userInput,
    _OfflineAnalysis analysis,
  ) async {
    // Skip internet check - let HTTP request handle connectivity
    // if (!await _hasInternetConnection()) {
    //   return _offlineReply(
    //     analysis,
    //     modelTextFallback:
    //         'Internet not available. This is an offline fallback response.',
    //   );
    // }

    final cacheKey = _buildCacheKey(userInput, analysis);
    if (_groqResponseCache.containsKey(cacheKey)) {
      return _groqResponseCache[cacheKey]!;
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final body = jsonEncode({
      'model': _groqModel,
      'messages': [
        {'role': 'user', 'content': _buildCompactPrompt(userInput, analysis)}
      ],
      'temperature': 0.6,
      'max_tokens': 600,
      'top_p': 0.9,
      'frequency_penalty': 0.0,
      'presence_penalty': 0.1,
    });

    http.Response response;
    try {
      response = await _postWithRetry(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: body,
      );
    } catch (e) {
      print('Groq API connection error: $e');
      return _offlineReply(
        analysis,
        modelTextFallback:
            'Unable to connect to the Groq API. Working offline for now.',
      );
    }

    if (response.statusCode != 200) {
      print('Groq API error: ${response.statusCode} - ${response.body}');
      final errorMsg = response.statusCode == 429
          ? 'Rate limit reached. Using offline mode with smart detection.'
          : 'Unable to reach AI server. Using local assistant mode.';
      return _offlineReply(analysis, modelTextFallback: errorMsg);
    }

    final payload = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) payload.addAll(decoded);
    } catch (_) {
      return _offlineReply(
        analysis,
        modelTextFallback:
            'Unable to parse AI response. Using local assistant mode.',
      );
    }

    final text = _extractGroqText(payload);
    final jsonText = _extractJson(text);

    if (jsonText == null) {
      final cleanText = text.trim();
      return _cacheHelper(
        cacheKey,
        _offlineReply(
          analysis,
          modelTextFallback: cleanText.isNotEmpty ? cleanText : null,
        ),
      );
    }

    try {
      final obj = jsonDecode(jsonText) as Map<String, dynamic>;
      final reply = _fromModelObject(obj, analysis);
      return _cacheHelper(cacheKey, reply);
    } catch (_) {
      return _cacheHelper(cacheKey, _offlineReply(analysis));
    }
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
    final action = _asString(obj['action']) ?? 'COLLECT_INFO';
    final showConfirmation = obj['showConfirmation'] == true;
    final confirmationQuestion = _asString(obj['confirmationQuestion']);

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
      action: action,
      showConfirmation: showConfirmation,
      confirmationQuestion: confirmationQuestion,
    );
  }

  AssistantReply _offlineReply(_OfflineAnalysis analysis,
      {String? modelTextFallback}) {
    final missing = _missingFields(analysis);
    final nextQuestion = _nextQuestion(analysis, missing);
    final actions = _actions(analysis);

    final content = modelTextFallback?.trim().isNotEmpty == true
        ? modelTextFallback!.trim()
        : '${_baseMessage(analysis)}\n\n$nextQuestion';

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
      response: _humanize(content, analysis.mood, analysis.urgency),
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

  String _buildCompactPrompt(String userInput, _OfflineAnalysis analysis) {
    final draft = Map<String, dynamic>.from(_complaintData);
    if (analysis.category != null) draft['category'] = analysis.category;
    if (analysis.subcategory != null) draft['subcategory'] = analysis.subcategory;
    if (analysis.locationHint != null) draft['location_hint'] = analysis.locationHint;
    draft['urgency'] = analysis.urgency;
    draft['is_emergency'] = analysis.isEmergency;

    return '''
You are JanHelp - Smart City complaint assistant for India.

🎯 TASK: Analyze user input and extract complaint details instantly.

📋 CATEGORIES: Police, Traffic, Construction, Electricity, Water Supply, Garbage/Sanitation, Road/Pothole, Drainage/Sewage, Cyber Crime, Street Light, Public Toilet, Stray Animals

🧠 RULES:
1. Extract category, location, description from user message
2. If complete info provided → confirm and ask for location picker
3. If partial info → ask for missing details naturally
4. Respond in user's language (en/hi/gu/hinglish)
5. Handle emergencies with safety-first approach

📊 CURRENT STATE:
Draft: ${jsonEncode(draft)}
Detected: category=${analysis.category ?? 'none'}, location=${analysis.locationHint ?? 'none'}, urgency=${analysis.urgency}

User: "$userInput"

📤 RESPOND IN JSON:
{
  "language": "en|hi|gu|hinglish",
  "mood": "neutral|calm|concerned|urgent",
  "urgency": "low|medium|high|critical",
  "category": "exact category or null",
  "subcategory": "exact subcategory or null",
  "missing_fields": ["list missing"],
  "action_checklist": ["next actions"],
  "next_question": "follow-up question",
  "response_text": "natural response in user's language",
  "safety_alert": true/false,
  "action": "COLLECT_INFO|REQUEST_LOCATION|REQUEST_PROOF|SUBMIT_COMPLAINT",
  "showConfirmation": true/false,
  "confirmationQuestion": "question or null"
}
''';
  }

  String _buildGeminiPrompt(String userInput, _OfflineAnalysis analysis) {
    final historyText = _history
        .map((h) => '${h['role'] == 'user' ? 'Citizen' : 'JanHelp'}: ${h['content']}')
        .join('\n');
    final categoryCatalog = _buildCategoryCatalogForPrompt();
    final draft = Map<String, dynamic>.from(_complaintData);
    if (analysis.category != null) draft['category'] = analysis.category;
    if (analysis.subcategory != null) draft['subcategory'] = analysis.subcategory;
    if (analysis.locationHint != null) draft['location_hint'] = analysis.locationHint;
    if (analysis.timeHint != null) draft['time_hint'] = analysis.timeHint;
    draft['urgency'] = analysis.urgency;
    draft['is_emergency'] = analysis.isEmergency;
    final userName = _loadUserName();

    return '''
You are JanHelp — an ADVANCED AI assistant for Smart City complaint registration in India.

🧠 ADVANCED INTELLIGENCE RULES:

1. **INSTANT FULL ANALYSIS** - If user provides complete info in ONE message, extract EVERYTHING:
   Example: "mere ghar ke paas MG Road par bahut kachra pada hai, koi nahi uthata"
   → Extract: category=Garbage/Sanitation, location="MG Road", description="garbage piling up, not being collected"
   → Respond: "Got it! Garbage issue at MG Road. Should I register this complaint now?"
   → Set: showConfirmation=true, action=COLLECT_INFO (ready for location picker next)

2. **SEMANTIC UNDERSTANDING** (not just keywords):
   - "बहुत गंदगी है" = "lot of dirt" = "very dirty" = "kachra bahut hai" → Garbage
   - "रास्ता टूटा है" = "road broken" = "sadak kharab" = "pothole" → Road/Pothole
   - "बिजली नहीं आ रही" = "no electricity" = "power cut" = "light nahi" → Electricity
   - "पानी नहीं आता" = "no water" = "tap dry" = "pani nahi" → Water Supply
   - "शोर बहुत है" = "too much noise" = "construction shor" → Construction/Noise
   - "चोरी हो गई" = "theft happened" = "someone stole" → Police/Crime
   - "accident हो गया" = "गाड़ी टकरा गई" = "car crash" → Traffic
   - "कुत्ता काटा" = "dog bite" = "stray dog" → Stray Animals
   - "toilet गंदा है" = "washroom dirty" → Public Toilet
   - "light नहीं जल रही" = "street light not working" → Street Light

3. **CONTEXT INFERENCE FROM VAGUE INPUT**:
   - "my area is very dirty" → Garbage/Sanitation
   - "can't sleep at night" + mentions "construction" → Noise Pollution
   - "kids getting sick" + mentions "water" → Water Quality
   - "road is bad" → Road/Pothole
   - "no light" → Electricity or Street Light
   - "smell is terrible" → Drainage/Sewage
   - "dog attacked" → Stray Animals
   - "toilet is dirty" → Public Toilet

4. **EXTRACT LOCATION FROM NATURAL SPEECH**:
   - "mere ghar ke paas" → location_hint: "near my house"
   - "MG Road par" → location_hint: "MG Road"
   - "Satellite area mein" → location_hint: "Satellite area"
   - "school ke samne" → location_hint: "in front of school"
   - "market ke piche" → location_hint: "behind market"

5. **HANDLE TYPOS & SLANG**:
   - "gabage" = garbage, "bijly" = bijli, "rasta" = road
   - "panni" = pani, "thif" = thief, "acident" = accident
   - "bhai", "yaar", "boss" = casual tone, respond casually

6. **SMART STEP DETECTION**:
   - If category detected but no location → ask for location OR set action=REQUEST_LOCATION
   - If category + location detected → ask for more details OR set action=REQUEST_PROOF
   - If everything collected → show summary with showConfirmation=true
   - If user confirms summary → set action=SUBMIT_COMPLAINT

7. **MULTILINGUAL RESPONSE MATCHING**:
   - User speaks Hindi → respond in Hindi
   - User speaks Hinglish → respond in Hinglish
   - User speaks Gujarati → respond in Gujarati
   - User mixes languages → mix languages in response

📚 TRAINING EXAMPLES:

**Example 1: Complete info in one message**
User: "bhai mere ghar ke samne Satellite area mein bahut kachra pada hai, 2 hafte se koi nahi uthata"
AI Analysis:
- category: "Garbage/Sanitation"
- subcategory: "Waste Collection"
- location_hint: "Satellite area, in front of my house"
- description: "Garbage piling up for 2 weeks, not being collected"
- language: "hinglish"
AI Response: "Samajh gaya bhai! Satellite area mein 2 hafte se kachra jama hai aur koi collect nahi kar raha. Ye Garbage/Sanitation complaint hai. Kya main exact location ke liye map dikhaun? 📍"
Action: REQUEST_LOCATION
showConfirmation: false

**Example 2: Vague input**
User: "problem hai mere area me"
AI Response: "Main help karna chahta hoon! Problem kis type ki hai?
- Kachra/safai 🗑️
- Sadak/gadda 🛣️
- Pani 💧
- Bijli ⚡
- Traffic 🚦
- Construction shor 🏗️
- Police/safety 👮
- Street light 💡
- Stray animals 🐕
- Public toilet 🚻
Bataiye kaunsi problem hai?"
Action: COLLECT_INFO

**Example 3: Only category mentioned**
User: "garbage problem"
AI Response: "Got it! Garbage issue. Can you tell me the exact location? Like which area, street, or landmark? 📍"
Action: COLLECT_INFO

**Example 4: Category + location**
User: "MG Road par pothole hai"
AI Response: "Samajh gaya! MG Road par pothole ki problem hai. Ye Road/Pothole complaint hai. Kya main location confirm karne ke liye map dikhaun? 📍"
Action: REQUEST_LOCATION
showConfirmation: false

**Example 5: Everything provided**
User: "મારા ઘર આગળ Vastrapur lake પાસે કચરો પડ્યો છે, 1 મહિનાથી કોઈ સાફ નથી કરતું"
AI Analysis:
- category: "Garbage/Sanitation"
- location_hint: "Vastrapur lake, in front of my house"
- description: "Garbage for 1 month, not cleaned"
- language: "gu"
AI Response: "સમજાયું! Vastrapur lake પાસે 1 મહિનાથી કચરો જમા છે. આ Garbage/Sanitation ફરિયાદ છે. શું હું exact location માટે map બતાવું? 📍"
Action: REQUEST_LOCATION

**Example 6: Emergency**
User: "bijli ka wire toot gaya hai, bahut dangerous hai"
AI Response: "⚠️ DANGER! Broken wire is emergency. Please stay away and call 112 immediately for safety! ⚡🚨\n\nShould I also register an Electricity complaint for repair? This will help get it fixed."
Action: COLLECT_INFO
showConfirmation: true
confirmationQuestion: "Should I register Electricity complaint for wire repair?"

**Example 7: Stray Animals**
User: "mere ghar ke paas ek kutta hai jo sabko darta hai"
AI Response: "Samajh gaya! Aapke area mein stray dog ki problem hai. Ye Stray Animals complaint hai. Exact location bataiye? 📍"
Action: COLLECT_INFO

**Example 8: Street Light**
User: "raat ko rasta andhera rehta hai light nahi jalti"
AI Response: "Samajh gaya! Street light nahi jal rahi hai aur raat ko andhera rehta hai. Ye Street Light complaint hai. Kaunse area ki baat kar rahe ho? 📍"
Action: COLLECT_INFO

**Example 9: Public Toilet**
User: "public toilet bahut ganda hai, koi saaf nahi karta"
AI Response: "Got it! Public toilet dirty hai aur maintenance nahi ho rahi. Ye Public Toilet complaint hai. Toilet kahan hai? 📍"
Action: COLLECT_INFO

🎯 ALL 12 COMPLAINT CATEGORIES:
1. **Police**: crime, theft, चोरी, લૂંટ, safety, violence, harassment, मारपीट, દબાણ
2. **Traffic**: accident, signal, parking, અકસ્માત, ટ્રાફિક, सड़क, road rage, challan
3. **Construction**: illegal building, noise, કચરો, कूड़ा, debris, અવાજ, शोर, safety hazards
4. **Electricity**: bijli, વીજળી, बिजली, wire, transformer, power cut
5. **Water Supply**: pani, પાણી, पानी, tap, pipeline, leakage, pressure
6. **Garbage/Sanitation**: kachra, કચરો, कूड़ा, dustbin, sanitation, waste, gandagi
7. **Road/Pothole**: sadak, રસ્તો, सड़क, gadda, pothole, waterlogging, broken road
8. **Drainage/Sewage**: nali, નાળી, नाली, sewer, gutter, manhole, bad smell, overflow
9. **Cyber Crime**: online fraud, UPI scam, phishing, hacking, digital fraud
10. **Street Light**: street light, lamp, pole light, રસ્તાની લાઇટ, सड़क की बत्ती, dark
11. **Public Toilet**: toilet, washroom, શૌચાલય, शौचालय, dirty toilet, public toilet
12. **Stray Animals**: stray dog, dog bite, આવારા કૂતરા, आवारा कुत्ता, cattle, cow

📊 CURRENT STATE:
Complaint Data: ${jsonEncode(draft)}
Conversation: $historyText

🎯 YOUR TASK:
1. Analyze user input deeply - extract category, location, description
2. If user gives complete info → extract everything, confirm, move to location picker
3. If user gives partial info → ask for missing pieces naturally
4. If user is vague → give options with emojis
5. Always respond in user's language
6. Be smart, empathetic, and efficient

📤 RESPONSE FORMAT (JSON only):
{
  "language": "en|hi|gu|hinglish",
  "mood": "neutral|calm|concerned|frustrated|angry|urgent",
  "urgency": "low|medium|high|critical",
  "category": "exact category name or null",
  "subcategory": "exact subcategory name or null",
  "missing_fields": ["list missing info"],
  "action_checklist": ["next 1-2 actions"],
  "next_question": "natural follow-up",
  "response_text": "warm natural response in user's language",
  "safety_alert": true/false,
  "action": "COLLECT_INFO|REQUEST_LOCATION|REQUEST_PROOF|SUBMIT_COMPLAINT",
  "showConfirmation": true/false,
  "confirmationQuestion": "question for Yes/No/Maybe or null"
}

Category catalog:
$categoryCatalog

Analysis context:
- Language: ${analysis.language}
- Mood: $_userMood
- Urgency: ${analysis.urgency}
- Emergency: ${analysis.isEmergency}
- Detected category: ${analysis.category ?? 'not detected'}
- Detected subcategory: ${analysis.subcategory ?? 'not detected'}
- Location hint: ${analysis.locationHint ?? 'not provided'}
- Alternatives: ${analysis.alternatives.join(', ')}
- Signals: ${analysis.matchedSignals.join(', ')}

User: $userName

Citizen said: "$userInput"

Analyze deeply and respond intelligently with appropriate action.
''';
  }

  String _loadUserName() {
    try {
      final raw = StorageService.getUserData();
      if (raw == null || raw.trim().isEmpty) return 'Citizen';
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      final firstName = _asString(obj['first_name'])?.trim();
      if (firstName != null && firstName.isNotEmpty) return firstName;
      final username = _asString(obj['username'])?.trim();
      return username ?? 'Citizen';
    } catch (_) {
      return 'Citizen';
    }
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

  String _extractGroqText(Map<String, dynamic> payload) {
    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final choice = choices.first;
    if (choice is! Map) return '';
    final message = choice['message'];
    if (message is! Map) return '';
    return (message['content'] as String?)?.trim() ?? '';
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

  String _buildCacheKey(String userInput, _OfflineAnalysis analysis) {
    final normalizedInput = _normalize(userInput);
    return '$normalizedInput|${analysis.category ?? 'NA'}|${analysis.subcategory ?? 'NA'}|${analysis.locationHint ?? 'NA'}|${analysis.isEmergency ? '1' : '0'}|${analysis.urgency}';
  }

  AssistantReply _cacheHelper(String key, AssistantReply reply) {
    if (_groqResponseCache.length >= _groqCacheMaxEntries) {
      _groqResponseCache.remove(_groqResponseCache.keys.first);
    }
    _groqResponseCache[key] = reply;
    return reply;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      // Fallback: try alternative DNS
      try {
        final result = await InternetAddress.lookup('1.1.1.1')
            .timeout(const Duration(seconds: 2));
        return result.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  Future<http.Response> _postWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    int maxAttempts = _groqMaxRetries,
  }) async {
    var attempt = 0;
    var backoff = _groqInitialBackoff;
    http.Response? lastResponse;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        print('Groq API attempt $attempt/$maxAttempts...');
        final response = await http
            .post(uri, headers: headers, body: body)
            .timeout(_groqTimeout);

        print('Groq API response: ${response.statusCode}');
        if (response.statusCode == 200) return response;
        lastResponse = response;
      } catch (error) {
        print('Groq API attempt $attempt failed: $error');
        if (attempt >= maxAttempts) {
          return http.Response('Network unavailable for Groq run', 503);
        }
      }

      if (attempt < maxAttempts) {
        print('Retrying in ${backoff.inMilliseconds}ms...');
        await Future.delayed(backoff);
        backoff *= 2;
      }
    }

    return lastResponse ?? http.Response('Network unavailable for Groq run', 503);
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

  // _humanize is kept for offline fallback only — Groq handles its own tone
  String _humanize(String text, String mood, String urgency) {
    return text.trim();
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
    
    // Advanced: Extract description from user input if it's detailed
    if (userInput.split(' ').length > 5 && _complaintData['description'] == null) {
      _complaintData['description'] = userInput;
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
    // Enhanced location extraction patterns
    final patterns = [
      // "at/near/in location" pattern
      RegExp(r'\b(?:at|near|in|on|around|beside|opposite|samne|piche|paas|aage)\s+([a-z0-9 ,.-]{3,80})', caseSensitive: false),
      // "location par/mein" pattern (Hinglish/Hindi)
      RegExp(r'([a-z0-9 ]+)\s+(?:par|mein|me|ma|પર|માં|में)', caseSensitive: false),
      // "mere ghar ke paas location" pattern
      RegExp(r'(?:ghar|घर|ઘર)\s+(?:ke|ka)?\s*(?:paas|samne|piche|aage|પાસે|સામે|પાછળ|आगे|पास|सामने)\s+([a-z0-9 ]+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        final location = match.group(1)?.trim();
        if (location != null && location.length > 2) {
          return location.replaceAll(RegExp(r'[.,;!?]+$'), '').trim();
        }
      }
    }
    
    return null;
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
