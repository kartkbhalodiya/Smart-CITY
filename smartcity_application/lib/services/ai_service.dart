import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/ai_training_data.dart';
import '../config/api_config.dart';
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

  static const int _cacheMaxEntries = 200;

  final List<Map<String, String>> _history = [];
  final Map<String, dynamic> _complaintData = {};
  final LinkedHashMap<String, AssistantReply> _responseCache = LinkedHashMap();
  String _currentLanguage = 'en';
  String _userMood = 'neutral';
  String _sessionId = ''; // Start empty to generate unique session

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

    // Generate unique session ID if not exists
    if (_sessionId.isEmpty || _sessionId == 'default') {
      _sessionId = 'flutter_${DateTime.now().millisecondsSinceEpoch}_${input.hashCode.abs()}';
      print('Generated new session ID: $_sessionId');
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
      reply = await _replyFromBackend(input, analysis);
    } catch (e) {
      print('Backend failed, using offline: $e');
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
        en: '👋 Tell me what issue you want to report. I will guide you step by step.',
        hi: '👋 कृपया समस्या बताइए, मैं आपको चरण-दर-चरण मदद करूंगी।',
        gu: '👋 કૃપા કરીને સમસ્યા કહો, હું તમને પગલા પ્રમાણે મદદ કરીશ.',
        hinglish: '👋 Problem bataiye, main step-by-step help karunga.',
      ),
      language: _currentLanguage,
      mood: 'calm',
      urgency: 'medium',
      category: _complaintData['category'],
      subcategory: _complaintData['subcategory'],
      missingFields: const ['issue_category', 'exact_location'],
      actionChecklist: const ['📝 Describe issue', '📍 Share exact location'],
      isEmergency: false,
      confidence: 0.3,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: _localized(
        en: '📝 What issue should I register?',
        hi: '📝 मैं कौन सी समस्या दर्ज करूं?',
        gu: '📝 હું કઈ સમસ્યા નોંધાવું?',
        hinglish: '📝 Kaunsi problem register karun?',
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
        en: '🚨 Your safety comes first! If there is immediate danger, call 112 now.',
        hi: '🚨 Suraksha sabse pehle hai! Turant khatra ho to abhi 112 call karein.',
        gu: '🚨 Suraksha pehla chhe! Turant jokham hoy to 112 par call karo.',
        hinglish: '🚨 Safety first! Immediate danger ho to abhi 112 call kariye.',
      );
    }
    if (analysis.category == null && analysis.alternatives.isNotEmpty) {
      final options = analysis.alternatives.take(3).join(', ');
      return _localized(
        en: '🔍 I found close matches: $options. Please confirm the best one.',
        hi: '🔍 Mujhe close matches mile: $options. Sahi option confirm kijiye.',
        gu: '🔍 Mane close matches malya: $options. Sacho option confirm karo.',
        hinglish: '🔍 Close matches mile: $options. Sahi option confirm karo.',
      );
    }
    if (analysis.category != null) {
      final emoji = _getCategoryEmoji(analysis.category!);
      return _localized(
        en: '$emoji Detected: ${analysis.subcategory ?? analysis.category}. I will help you file this correctly.',
        hi: '$emoji Detected: ${analysis.subcategory ?? analysis.category}. Main ise sahi tarike se file karunga.',
        gu: '$emoji Detected: ${analysis.subcategory ?? analysis.category}. Hu aa ne sachi rite file karish.',
        hinglish: '$emoji Detected: ${analysis.subcategory ?? analysis.category}. Main proper filing mein help karunga.',
      );
    }
    return _localized(
      en: '👋 I am here to help. Tell me the exact issue in one line.',
      hi: '👋 Main madad ke liye yahan hoon. Kripya issue ek line mein batayein.',
      gu: '👋 Hu madad mate chhu. Krupaya issue ek line ma kaho.',
      hinglish: '👋 Main help ke liye hoon. Problem ek line mein batao.',
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

  Future<AssistantReply> _replyFromBackend(
    String userInput,
    _OfflineAnalysis analysis,
  ) async {
    // Don't use cache for dynamic conversations
    // final cacheKey = _buildCacheKey(userInput, analysis);
    // if (_responseCache.containsKey(cacheKey)) return _responseCache[cacheKey]!;

    try {
      print('Sending to backend: $userInput with session: $_sessionId');
      
      final response = await http.post(
        Uri.parse(ApiConfig.aiChat),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': userInput,
          'session_id': _sessionId,
          'preferred_language': _mapLanguageCode(_currentLanguage),
          'user_name': 'User', // You can get this from storage
        }),
      ).timeout(const Duration(seconds: 15));

      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final reply = _buildReplyFromBackend(data, analysis);
          // Don't cache dynamic responses
          // return _cacheHelper(cacheKey, reply);
          return reply;
        } else {
          print('Backend error: ${data['message']}');
        }
      }
    } catch (e) {
      print('Backend request failed: $e');
    }

    print('Falling back to offline reply');
    return _offlineReply(analysis);
  }

  AssistantReply _buildReplyFromBackend(
    Map<String, dynamic> data,
    _OfflineAnalysis analysis,
  ) {
    final category = (data['detected_category'] as String?) ?? analysis.category;
    final urgency = _normalizeUrgency((data['urgency'] as String?) ?? analysis.urgency);
    final language = _normalizeLanguage((data['language'] as String?) ?? analysis.language);
    final response = (data['response'] as String?)?.trim() ?? _offlineReply(analysis).response;
    final nextStep = (data['next_step'] as String?) ?? 'COLLECT_INFO';

    final draft = Map<String, dynamic>.from(_complaintData);
    if (category != null) draft['category'] = category;
    draft['urgency'] = urgency;

    final missing = _missingFields(analysis);
    return AssistantReply(
      response: response,
      language: language,
      mood: _normalizeMood((data['emotion'] as String?) ?? analysis.mood),
      urgency: urgency,
      category: category,
      subcategory: analysis.subcategory,
      missingFields: missing,
      actionChecklist: _actions(analysis),
      isEmergency: analysis.isEmergency,
      confidence: _confidence(analysis.confidence, missing.length),
      complaintDraft: draft,
      nextQuestion: _nextQuestion(analysis, missing),
      action: nextStep,
    );
  }

  String _buildCacheKey(String userInput, _OfflineAnalysis analysis) {
    final normalizedInput = _normalize(userInput);
    return '$normalizedInput|${analysis.category ?? 'NA'}|${analysis.subcategory ?? 'NA'}|${analysis.locationHint ?? 'NA'}|${analysis.isEmergency ? '1' : '0'}|${analysis.urgency}';
  }

  AssistantReply _cacheHelper(String key, AssistantReply reply) {
    if (_responseCache.length >= _cacheMaxEntries) {
      _responseCache.remove(_responseCache.keys.first);
    }
    _responseCache[key] = reply;
    return reply;
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
        '🚨 Call emergency helpline 112 if danger is immediate',
        '⚠️ Stay at safe distance',
        '📍 Share exact location for quick response',
      ];
    }
    if (analysis.category == null && analysis.alternatives.isNotEmpty) {
      return [
        '📝 Choose: ${analysis.alternatives.take(3).join(', ')}',
        '📍 Share exact location and landmark',
        '📷 Add photo if possible',
      ];
    }
    return [
      if (analysis.category != null)
        '✅ Tagged as ${analysis.subcategory ?? analysis.category}'
      else
        '📝 Confirm issue category',
      '📍 Share exact location and landmark',
      '📷 Add photo/video evidence if available',
    ];
  }

  String _nextQuestion(_OfflineAnalysis analysis, List<String> missing) {
    if (analysis.isEmergency && missing.contains('exact_location')) {
      return _localized(
        en: '📍 Please share exact location right now.',
        hi: '📍 कृपया तुरंत सही लोकेशन बताएं।',
        gu: '📍 કૃપા કરીને તરત ચોક્કસ લોકેશન આપો.',
        hinglish: '📍 Please abhi exact location bataiye.',
      );
    }
    if (missing.isEmpty) {
      return _localized(
        en: '✅ Ready to submit! Should I prepare the final summary?',
        hi: '✅ Submit ke liye ready! Kya main final summary banaun?',
        gu: '✅ Submit mate ready! Shu hu final summary banavu?',
        hinglish: '✅ Ready hai! Kya main summary bana kar submit karun?',
      );
    }

    switch (missing.first) {
      case 'issue_category':
        if (analysis.alternatives.isNotEmpty) {
          final options = analysis.alternatives.take(3).join(', ');
          return _localized(
            en: '📝 Choose closest: $options',
            hi: '📝 Sabse close option: $options',
            gu: '📝 Najik no option: $options',
            hinglish: '📝 Closest option: $options',
          );
        }
        return _localized(
          en: '📝 What type of issue? (Road, Water, Electricity, Garbage, Traffic, Police, etc.)',
          hi: '📝 Kis type ki problem hai? (Sadak, Pani, Bijli, Kachra, Traffic, Police, etc.)',
          gu: '📝 Kai type ni samasya chhe? (Rasto, Pani, Vijli, Kachro, Traffic, Police, etc.)',
          hinglish: '📝 Kis type ki problem hai? (Road, Water, Bijli, Kachra, Traffic, Police, etc.)',
        );
      case 'exact_location':
        return _localized(
          en: '📍 Please share exact area, street, and nearby landmark.',
          hi: '📍 कृपया सही एरिया, सड़क और पास का लैंडमार्क बताएं।',
          gu: '📍 કૃપા કરીને ચોક્કસ વિસ્તાર, રસ્તો અને નજીકનો લૅન્ડમાર્ક કહો.',
          hinglish: '📍 Please exact area, street aur nearby landmark bataiye.',
        );
      default:
        return _localized(
          en: '❓ One more detail needed to file correctly.',
          hi: '❓ Ek aur detail chahiye sahi filing ke liye.',
          gu: '❓ Ek hor detail joiye sachi filing mate.',
          hinglish: '❓ Ek aur detail chahiye proper filing ke liye.',
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

    // First pass: Detect primary issue keywords (crime, theft, etc.)
    final crimeKeywords = ['chori', 'theft', 'चोरी', 'લૂંટ', 'steal', 'stolen', 'purse', 'wallet', 'mobile', 'robbery', 'loot', 'चोरी हुआ', 'चोरी हो गया'];
    final hasCrimeKeyword = crimeKeywords.any((kw) => normalized.contains(_normalize(kw)));
    
    // Location-only keywords that should not trigger Road category
    final locationOnlyKeywords = ['road', 'sadak', 'रोड', 'સડક', 'street', 'gali', 'lane', 'pise', 'paas', 'samne', 'near', 'behind', 'front'];
    
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
        
        // If crime detected, heavily penalize non-Police categories
        if (hasCrimeKeyword && categoryName != 'Police') {
          score -= 20;
        }
        
        // If crime detected, heavily boost Police category
        if (hasCrimeKeyword && categoryName == 'Police') {
          score += 15;
          signals.add('crime detected');
        }
        
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
          
          // Skip location-only keywords for Road category if crime is detected
          if (hasCrimeKeyword && categoryName == 'Road/Pothole' && 
              locationOnlyKeywords.any((loc) => normalizedAlias.contains(_normalize(loc)))) {
            continue;
          }
          
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
          isCrimeContext: hasCrimeKeyword,
          currentCategory: categoryName,
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
    bool isCrimeContext = false,
    String? currentCategory,
  }) {
    int score = 0;
    final locationOnlyKeywords = ['road', 'sadak', 'रोड', 'સડક', 'street', 'gali', 'lane', 'pise', 'paas', 'samne', 'near', 'behind', 'front'];
    
    for (final keyword in keywords) {
      final key = _normalize(keyword);
      if (key.isEmpty) continue;
      
      // Skip location keywords for Road category if crime context detected
      if (isCrimeContext && currentCategory == 'Road/Pothole' && 
          locationOnlyKeywords.any((loc) => key.contains(_normalize(loc)))) {
        continue;
      }
      
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

  String _mapLanguageCode(String flutterLang) {
    switch (flutterLang) {
      case 'hi':
        return 'hindi';
      case 'gu':
        return 'gujarati';
      case 'hinglish':
        return 'hindi'; // Map hinglish to hindi for backend
      default:
        return 'english';
    }
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

  String _getCategoryEmoji(String category) {
    const emojiMap = {
      'Road/Pothole': '🛣️',
      'Drainage/Sewage': '🚰',
      'Garbage/Sanitation': '🗑️',
      'Electricity': '⚡',
      'Water Supply': '💧',
      'Traffic': '🚦',
      'Cyber Crime': '💻',
      'Construction': '🏗️',
      'Police': '👮',
      'Street Light': '💡',
      'Public Toilet': '🚻',
      'Stray Animals': '🐕',
    };
    return emojiMap[category] ?? '📝';
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
    _sessionId = ''; // Reset session ID to generate new one
    _responseCache.clear(); // Clear cache
    print('AI Service reset - new session will be created');
  }
}
