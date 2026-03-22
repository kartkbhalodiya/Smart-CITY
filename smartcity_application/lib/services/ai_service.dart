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
  String _appLanguage = 'en'; // Store app's selected language
  String _userMood = 'neutral';
  String _sessionId = ''; // Start empty to generate unique session
  String _conversationState = 'greeting'; // Track conversation state
  bool _categoryConfirmed = false; // Track if category was confirmed
  bool _locationProvided = false; // Track if location was provided
  bool _photoUploaded = false; // Track if photo was uploaded
  bool _dateProvided = false; // Track if date was provided
  Map<String, dynamic> _finalSummary = {}; // Store final summary

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
    'Police': [
      'theft',
      'chori',
      'चोरी',
      'લૂંટ',
      'robbery',
      'loot',
      'stolen',
      'purse snatching',
      'mobile theft',
      'chain snatching',
      'pickpocket',
      'burglary',
      'break in',
      'assault',
      'fight',
      'violence',
      'harassment',
      'molestation',
      'domestic violence',
      'missing person',
      'missing',
      'gum',
      'gum ho gaya',
      'गुम',
      'गुम हो गया',
      'ગુમ',
      'ગુમ થઈ ગયો',
      'lost person',
      'person missing',
      'bhai gum',
      'sister missing',
      'bachcha gum',
      'kidnapping',
      'murder',
      'accident',
      'hit and run',
      'drunk driving',
      'eve teasing',
      'stalking',
      'threat',
      'blackmail',
      'extortion',
      'गुंडागर्दी',
      'मारपीट',
      'लड़ाई',
      'धमकी',
      'ગુંડાગીરી',
      'મારપીટ',
      'લડાઈ',
      'ધમકી'
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

    print('Current state: $_conversationState');
    print('Input: $input');
    print('Is greeting only: ${_isGreetingOnly(input)}');

    // Check for greeting BEFORE adding to history or calling LLM
    if (_isGreetingOnly(input)) {
      print('Detected as greeting-only, showing welcome message');
      _history.add({'role': 'user', 'content': input});
      _currentLanguage = _detectLanguage(input);
      _userMood = _detectMood(input);
      final reply = _handleGreeting();
      _conversationState = 'awaiting_problem';
      _history.add({'role': 'assistant', 'content': reply.response});
      _trimHistory();
      return reply;
    }

    _history.add({'role': 'user', 'content': input});
    
    // Detect language from user input
    final detectedLanguage = _detectLanguage(input);
    
    // Use detected language ONLY if user typed in specific script/Hinglish
    // Otherwise, use app's selected language for response
    if (detectedLanguage == 'hinglish' || detectedLanguage == 'hi' || detectedLanguage == 'gu') {
      _currentLanguage = detectedLanguage;
      print('🗣️ User typed in: $detectedLanguage');
    } else {
      // User typed in English, use app's selected language for response
      _currentLanguage = _appLanguage;
      print('🌐 Using app language: $_appLanguage');
    }
    
    _userMood = _detectMood(input);

    // Advanced conversation flow
    AssistantReply reply;
    
    switch (_conversationState) {
      case 'greeting':
      case 'awaiting_problem':
        // User directly stated problem (greeting check already done above)
        reply = await _handleProblemDescription(input);
        break;
        
      case 'category_confirmation':
        // Step 3: Confirm category
        if (_isYesResponse(input)) {
          _categoryConfirmed = true;
          _conversationState = 'location_request';
          reply = _handleCategoryConfirmed();
        } else if (_isNoResponse(input)) {
          _categoryConfirmed = false;
          _conversationState = 'awaiting_problem';
          reply = _handleCategoryRejected();
        } else {
          reply = await _handleProblemDescription(input);
        }
        break;
        
      case 'location_request':
        // Step 4: Request location
        reply = _handleLocationRequest(input);
        break;
        
      case 'location_confirmation':
        // Step 5: Confirm location or skip
        if (_isYesResponse(input) || input.toLowerCase().contains('map') || input.toLowerCase().contains('location')) {
          _locationProvided = true;
          _conversationState = 'photo_request';
          reply = _handleLocationConfirmed();
        } else if (_isNoResponse(input) || input.toLowerCase().contains('skip') || input.toLowerCase().contains('no location')) {
          _locationProvided = false;
          _conversationState = 'photo_request';
          reply = _handleLocationSkipped();
        } else {
          reply = _handleLocationRequest(input);
        }
        break;
        
      case 'photo_request':
        // Step 6: Request photo
        if (_isYesResponse(input) || input.toLowerCase().contains('photo') || input.toLowerCase().contains('upload')) {
          _photoUploaded = true;
          _conversationState = 'date_request';
          reply = _handlePhotoUploaded();
        } else if (_isNoResponse(input) || input.toLowerCase().contains('skip') || input.toLowerCase().contains('no photo')) {
          _photoUploaded = false;
          _conversationState = 'date_request';
          reply = _handlePhotoSkipped();
        } else {
          reply = _requestPhoto();
        }
        break;
        
      case 'date_request':
        // Step 7: Request date of occurrence
        reply = _handleDateInput(input);
        break;
        
      case 'summary_review':
        // Step 8: Show summary with Edit/Confirm buttons
        reply = _showFinalSummary();
        break;
        
      case 'edit_mode':
        // Step 9: Handle edits
        reply = _handleEdit(input);
        break;
        
      case 'submitting':
        // Step 10: Submit to nearest department
        reply = await _handleSubmission();
        break;
        
      default:
        reply = await _handleProblemDescription(input);
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

  Future<AssistantReply> _processNormalInput(String input) async {
    // Try OpenRouter LLM first
    try {
      final llmResult = await _callOpenRouterLLM(input);
      if (llmResult != null) {
        print('OpenRouter LLM prediction successful');
        return _buildReplyFromLLM(llmResult, input);
      }
      print('OpenRouter LLM returned null, falling back to local analysis');
    } catch (e) {
      print('OpenRouter LLM failed: $e, falling back to local analysis');
    }
    
    // Fallback to local offline analysis
    final analysis = _analyzeOffline(input);
    _mergeDraft(analysis, input);
    return _offlineReply(analysis);
  }

  bool _isYesResponse(String input) {
    final lower = input.toLowerCase().trim();
    return ['yes', 'y', 'yeah', 'yep', 'correct', 'right', 'sahi', 'हां', 'हा', 'જી', 'જી હા', 'sach', 'theek'].contains(lower);
  }

  bool _isNoResponse(String input) {
    final lower = input.toLowerCase().trim();
    return ['no', 'n', 'nope', 'wrong', 'incorrect', 'nahi', 'नहीं', 'ના', 'galat', 'galt'].contains(lower);
  }

  bool _isGreetingOnly(String input) {
    final lower = input.toLowerCase().trim();
    final greetings = [
      'hi', 'hii', 'hiiii', 'hello', 'hey', 'helo', 'hii there',
      'namaste', 'namaskar', 'good morning', 'good afternoon', 'good evening',
      'नमस्ते', 'नमस्कार', 'આદાબ', 'સાત સાત',
      'sat sri akal', 'assalam alaikum', 'vanakkam', 'namaskaram'
    ];
    
    // Check if input is ONLY a greeting (exact match or very short)
    // If input has more than 3 words, it likely contains a problem description
    final wordCount = lower.split(' ').where((w) => w.isNotEmpty).length;
    if (wordCount > 3) return false;
    
    // Remove punctuation for comparison
    final cleanInput = lower.replaceAll(RegExp(r'[!.,?]'), '').trim();
    
    // Check for exact greeting match
    if (greetings.any((greeting) => cleanInput == greeting)) return true;
    
    // Check for common greeting patterns (hi, hii, hiii, etc.)
    if (RegExp(r'^h+i+$').hasMatch(cleanInput)) return true; // hi, hii, hiii, hh, hhh
    if (RegExp(r'^h+e+l+o+$').hasMatch(cleanInput)) return true; // hello, helo, heloo
    if (RegExp(r'^h+e+y+$').hasMatch(cleanInput)) return true; // hey, heyy
    
    return false;
  }

  AssistantReply _handleCategoryConfirmed() {
    final category = _complaintData['category'] as String?;
    final emoji = category != null ? _getCategoryEmoji(category) : '📝';
    
    return AssistantReply(
      response: _localized(
        en: '✅ Great! Now I need the exact location where this $category issue is happening.\n\n📍 Please share the area, street name, and nearby landmark.',
        hi: '✅ Badhiya! Ab mujhe exact location chahiye jahan ye $category problem hai.\n\n📍 Kripya area, street name aur nearby landmark bataiye.',
        gu: '✅ Saras! Have mane exact location joiye jya aa $category samasya chhe.\n\n📍 Krupaya area, street name ane najikno landmark kaho.',
        hinglish: '✅ Great! Ab exact location chahiye jahan ye $category problem hai.\n\n📍 Please area, street name aur nearby landmark batao.',
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: category,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const ['exact_location'],
      actionChecklist: const ['📍 Share exact location', '🗺️ Use map if needed'],
      isEmergency: _complaintData['is_emergency'] as bool? ?? false,
      confidence: 0.9,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'Where exactly is this issue located?',
      action: 'REQUEST_LOCATION',
    );
  }

  AssistantReply _handleCategoryRejected() {
    return AssistantReply(
      response: _localized(
        en: '🤔 No problem! Let me understand better.\n\nPlease describe your issue in more detail so I can identify the correct category.',
        hi: '🤔 Koi baat nahi! Main better samjhata hun.\n\nKripya apni problem detail mein batayiye taki main sahi category identify kar sakun.',
        gu: '🤔 Koi vaat nathi! Hu better samjhu chhu.\n\nKrupaya tamari samasya detail ma kaho ke hu sachi category identify kari shaku.',
        hinglish: '🤔 No problem! Main better samjhata hun.\n\nPlease apni issue detail mein batao taki main correct category identify kar sakun.',
      ),
      language: _currentLanguage,
      mood: 'understanding',
      urgency: 'medium',
      category: null,
      subcategory: null,
      missingFields: const ['issue_category', 'issue_description'],
      actionChecklist: const ['📝 Describe issue in detail', '🎯 Help me understand better'],
      isEmergency: false,
      confidence: 0.7,
      complaintDraft: Map<String, dynamic>.from(_complaintData)..remove('category')..remove('subcategory'),
      nextQuestion: 'Can you explain the problem in more detail?',
      action: 'COLLECT_INFO',
    );
  }

  // Step 1: Welcome greeting
  AssistantReply _handleGreeting() {
    return AssistantReply(
      response: _localized(
        en: '👋 Hello! Welcome to JanHelp - Your Smart City Assistant.\n\nI\'m here to help you file complaints quickly and efficiently.\n\n📝 Please tell me what problem you want to report today.',
        hi: '👋 Namaste! JanHelp mein aapka swagat hai - Aapka Smart City Assistant.\n\nMain aapki complaint jaldi aur aasani se file karne mein madad karunga.\n\n📝 Kripya batayiye aaj aap kya problem report karna chahte hain.',
        gu: '👋 Namaste! JanHelp ma tamaru swagat chhe - Tamaro Smart City Assistant.\n\nHu tamari complaint jaldi ane saheli rite file karvama madad karish.\n\n📝 Krupaya kaho aaje tame shu samasya report karva mangho cho.',
        hinglish: '👋 Hello! JanHelp mein aapka swagat hai - Aapka Smart City Assistant.\n\nMain aapki complaint jaldi file karne mein help karunga.\n\n📝 Please batao aaj kya problem report karni hai.',
      ),
      language: _currentLanguage,
      mood: 'welcoming',
      urgency: 'medium',
      category: null,
      subcategory: null,
      missingFields: const ['issue_description'],
      actionChecklist: const ['👋 Welcome!', '📝 Describe your problem'],
      isEmergency: false,
      confidence: 1.0,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'What problem would you like to report?',
      action: 'COLLECT_INFO',
    );
  }

  // Step 2: Handle problem description
  Future<AssistantReply> _handleProblemDescription(String input) async {
    return await _processNormalInput(input);
  }

  // Step 4: Handle location request
  AssistantReply _handleLocationRequest(String input) {
    // Extract location from input
    final location = _extractLocation(input);
    if (location != null) {
      _complaintData['location_hint'] = location;
      _locationProvided = true;
      _conversationState = 'photo_request';
      return _handleLocationConfirmed();
    }
    
    // Ask for location
    _conversationState = 'location_confirmation';
    return AssistantReply(
      response: _localized(
        en: '📍 **Location Required**\n\nPlease share the exact location where this issue is happening.\n\n🗺️ You can:\n• Click "Use Map" to pin the location\n• Type the address manually\n• Skip if location not available yet',
        hi: '📍 **Location Chahiye**\n\nKripya exact location batayiye jahan ye problem hai.\n\n🗺️ Aap:\n• "Map Use Karein" par click karke location pin kar sakte hain\n• Address manually type kar sakte hain\n• Skip kar sakte hain agar location abhi available nahi hai',
        gu: '📍 **Location Joiye**\n\nKrupaya exact location kaho jya aa samasya chhe.\n\n🗺️ Tame:\n• "Map Use Karo" par click karine location pin kari shako\n• Address manually type kari shako\n• Skip kari shako jyare location available nathi',
        hinglish: '📍 **Location Chahiye**\n\nPlease exact location batao jahan problem hai.\n\n🗺️ Aap:\n• "Use Map" click karke location pin kar sakte ho\n• Address manually type kar sakte ho\n• Skip kar sakte ho agar location nahi hai',
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const ['exact_location'],
      actionChecklist: const ['📍 Share location', '🗺️ Use map', '⏭️ Skip'],
      isEmergency: _complaintData['is_emergency'] as bool? ?? false,
      confidence: 0.8,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'Where is this issue located?',
      action: 'REQUEST_LOCATION',
    );
  }

  AssistantReply _handleLocationConfirmed() {
    return AssistantReply(
      response: _localized(
        en: '✅ Location noted!\n\n📷 **Photo Evidence (Optional)**\n\nDo you have a photo of the issue? Photos help departments resolve complaints faster.\n\n• Upload photo\n• Skip for now',
        hi: '✅ Location note kar liya!\n\n📷 **Photo Evidence (Optional)**\n\nKya aapke paas issue ki photo hai? Photos se departments complaint jaldi resolve kar sakte hain.\n\n• Photo upload karein\n• Abhi skip karein',
        gu: '✅ Location note karyu!\n\n📷 **Photo Evidence (Optional)**\n\nShu tamari paas issue ni photo chhe? Photos thi departments complaint jaldi resolve kari shake chhe.\n\n• Photo upload karo\n• Abhi skip karo',
        hinglish: '✅ Location note ho gaya!\n\n📷 **Photo Evidence (Optional)**\n\nKya aapke paas issue ki photo hai? Photos se complaint jaldi resolve hoti hai.\n\n• Photo upload karo\n• Skip karo',
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const [],
      actionChecklist: const ['📷 Upload photo', '⏭️ Skip'],
      isEmergency: _complaintData['is_emergency'] as bool? ?? false,
      confidence: 0.9,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'Do you want to upload a photo?',
      action: 'REQUEST_PHOTO',
    );
  }

  AssistantReply _handleLocationSkipped() {
    _complaintData['location_hint'] = 'Will be added later';
    return AssistantReply(
      response: _localized(
        en: '⏭️ No problem! We\'ll use your current location when you submit.\n\n📷 **Photo Evidence (Optional)**\n\nDo you have a photo of the issue?',
        hi: '⏭️ Koi baat nahi! Submit karte waqt hum aapka current location use karenge.\n\n📷 **Photo Evidence (Optional)**\n\nKya aapke paas issue ki photo hai?',
        gu: '⏭️ Koi vaat nathi! Submit karta samaye ame tamari current location use karishu.\n\n📷 **Photo Evidence (Optional)**\n\nShu tamari paas issue ni photo chhe?',
        hinglish: '⏭️ No problem! Submit karte time current location use karenge.\n\n📷 **Photo Evidence (Optional)**\n\nKya photo hai?',
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const [],
      actionChecklist: const ['📷 Upload photo', '⏭️ Skip'],
      isEmergency: _complaintData['is_emergency'] as bool? ?? false,
      confidence: 0.9,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'Upload photo?',
      action: 'REQUEST_PHOTO',
    );
  }

  // Step 6: Handle photo
  AssistantReply _requestPhoto() {
    return AssistantReply(
      response: _localized(
        en: '📷 Please upload a photo or skip to continue.',
        hi: '📷 Kripya photo upload karein ya skip karein.',
        gu: '📷 Krupaya photo upload karo ke skip karo.',
        hinglish: '📷 Photo upload karo ya skip karo.',
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const [],
      actionChecklist: const ['📷 Upload', '⏭️ Skip'],
      isEmergency: false,
      confidence: 0.9,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'Upload photo?',
      action: 'REQUEST_PHOTO',
    );
  }

  AssistantReply _handlePhotoUploaded() {
    _complaintData['photo_uploaded'] = true;
    _conversationState = 'date_request';
    return _requestDate();
  }

  AssistantReply _handlePhotoSkipped() {
    _complaintData['photo_uploaded'] = false;
    _conversationState = 'date_request';
    return _requestDate();
  }

  // Step 7: Request date
  AssistantReply _requestDate() {
    return AssistantReply(
      response: _localized(
        en: '📅 **When did this issue occur?**\n\nPlease tell me:\n• Today\n• Yesterday\n• Specific date\n• Ongoing issue',
        hi: '📅 **Ye problem kab hui?**\n\nKripya batayiye:\n• Aaj\n• Kal\n• Specific date\n• Ongoing issue',
        gu: '📅 **Aa samasya kyare thay?**\n\nKrupaya kaho:\n• Aaje\n• Gaye kal\n• Specific date\n• Ongoing issue',
        hinglish: '📅 **Problem kab hui?**\n\nBatao:\n• Aaj\n• Kal\n• Specific date\n• Ongoing',
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const [],
      actionChecklist: const ['📅 Provide date'],
      isEmergency: false,
      confidence: 0.9,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'When did this occur?',
      action: 'REQUEST_DATE',
    );
  }

  AssistantReply _handleDateInput(String input) {
    final timeHint = _extractTime(input);
    _complaintData['time_hint'] = timeHint ?? 'Today';
    _complaintData['date_of_occurrence'] = DateTime.now().toIso8601String();
    _dateProvided = true;
    _conversationState = 'summary_review';
    return _showFinalSummary();
  }

  // Step 8: Show final summary
  AssistantReply _showFinalSummary() {
    _finalSummary = Map<String, dynamic>.from(_complaintData);
    
    final summary = '''
📋 **COMPLAINT SUMMARY**

1️⃣ **Category:** ${_complaintData['category'] ?? 'Not specified'}
2️⃣ **Subcategory:** ${_complaintData['subcategory'] ?? 'Not specified'}
3️⃣ **Description:** ${_complaintData['description'] ?? _complaintData['last_user_message'] ?? 'Not provided'}
4️⃣ **Location:** ${_complaintData['location_hint'] ?? 'Current location will be used'}
5️⃣ **Date:** ${_complaintData['time_hint'] ?? 'Today'}
6️⃣ **Photo:** ${_complaintData['photo_uploaded'] == true ? 'Uploaded ✅' : 'Not uploaded'}
7️⃣ **Urgency:** ${_complaintData['urgency'] ?? 'Medium'}
8️⃣ **Emergency:** ${_complaintData['is_emergency'] == true ? 'Yes 🚨' : 'No'}

---

✏️ **Want to edit?** Reply with the number (1-8) to change that field.
✅ **Ready to submit?** Reply "Confirm" or "Submit".
''';

    return AssistantReply(
      response: _localized(
        en: summary,
        hi: summary,
        gu: summary,
        hinglish: summary,
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const [],
      actionChecklist: const ['✏️ Edit (1-8)', '✅ Confirm'],
      isEmergency: _complaintData['is_emergency'] as bool? ?? false,
      confidence: 1.0,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: 'Edit or Confirm?',
      action: 'REVIEW_SUMMARY',
      showConfirmation: true,
      confirmationQuestion: 'Do you want to submit this complaint?',
    );
  }

  // Step 9: Handle edits
  AssistantReply _handleEdit(String input) {
    final lower = input.toLowerCase();
    
    if (lower.contains('confirm') || lower.contains('submit') || _isYesResponse(input)) {
      _conversationState = 'submitting';
      return AssistantReply(
        response: _localized(
          en: '⏳ Submitting your complaint to the nearest department...\n\nPlease wait.',
          hi: '⏳ Aapki complaint nearest department ko bhej rahe hain...\n\nKripya pratiksha karein.',
          gu: '⏳ Tamari complaint najikna department ne moki raha chhe...\n\nKrupaya pratiksha karo.',
          hinglish: '⏳ Complaint nearest department ko bhej rahe hain...\n\nWait karo.',
        ),
        language: _currentLanguage,
        mood: 'processing',
        urgency: _complaintData['urgency'] as String? ?? 'medium',
        category: _complaintData['category'] as String?,
        subcategory: _complaintData['subcategory'] as String?,
        missingFields: const [],
        actionChecklist: const ['⏳ Processing...'],
        isEmergency: _complaintData['is_emergency'] as bool? ?? false,
        confidence: 1.0,
        complaintDraft: Map<String, dynamic>.from(_complaintData),
        nextQuestion: '',
        action: 'SUBMITTING',
      );
    }
    
    // Handle number-based editing
    final editNumber = int.tryParse(input.trim());
    if (editNumber != null && editNumber >= 1 && editNumber <= 8) {
      _conversationState = 'edit_mode';
      return _requestEditForField(editNumber);
    }
    
    return _showFinalSummary();
  }

  AssistantReply _requestEditForField(int fieldNumber) {
    String fieldName = '';
    String prompt = '';
    
    switch (fieldNumber) {
      case 1:
        fieldName = 'category';
        prompt = 'What should be the correct category?';
        break;
      case 2:
        fieldName = 'subcategory';
        prompt = 'What should be the correct subcategory?';
        break;
      case 3:
        fieldName = 'description';
        prompt = 'Please provide the updated description.';
        break;
      case 4:
        fieldName = 'location';
        prompt = 'Please provide the updated location.';
        break;
      case 5:
        fieldName = 'date';
        prompt = 'When did this issue occur?';
        break;
      case 6:
        fieldName = 'photo';
        prompt = 'Upload photo or skip.';
        break;
      case 7:
        fieldName = 'urgency';
        prompt = 'What is the urgency level? (Low/Medium/High/Critical)';
        break;
      case 8:
        fieldName = 'emergency';
        prompt = 'Is this an emergency? (Yes/No)';
        break;
    }
    
    return AssistantReply(
      response: _localized(
        en: '✏️ Editing field $fieldNumber: **$fieldName**\n\n$prompt',
        hi: '✏️ Field $fieldNumber edit kar rahe hain: **$fieldName**\n\n$prompt',
        gu: '✏️ Field $fieldNumber edit kari raha chhe: **$fieldName**\n\n$prompt',
        hinglish: '✏️ Field $fieldNumber edit kar rahe hain: **$fieldName**\n\n$prompt',
      ),
      language: _currentLanguage,
      mood: 'helpful',
      urgency: _complaintData['urgency'] as String? ?? 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const [],
      actionChecklist: const ['✏️ Provide new value'],
      isEmergency: false,
      confidence: 1.0,
      complaintDraft: Map<String, dynamic>.from(_complaintData),
      nextQuestion: prompt,
      action: 'EDITING',
    );
  }

  // Step 10: Submit to nearest department
  Future<AssistantReply> _handleSubmission() async {
    // This will be handled by your backend
    // For now, return success message
    final complaintId = 'CMP${DateTime.now().millisecondsSinceEpoch}';
    
    return AssistantReply(
      response: _localized(
        en: '''✅ **COMPLAINT SUBMITTED SUCCESSFULLY!**

📋 **Complaint ID:** $complaintId
🏢 **Department:** ${_complaintData['category'] ?? 'Municipal'} Department
📍 **Location:** ${_complaintData['location_hint'] ?? 'Your current location'}
⏰ **Submitted:** ${DateTime.now().toString().split('.')[0]}

---

**Next Steps:**
1️⃣ Department will review within 24 hours
2️⃣ You'll receive updates via notifications
3️⃣ Track status in "My Complaints" section

🙏 Thank you for using JanHelp!''',
        hi: '''✅ **COMPLAINT SUCCESSFULLY SUBMIT HO GAYI!**

📋 **Complaint ID:** $complaintId
🏢 **Department:** ${_complaintData['category'] ?? 'Municipal'} Department
📍 **Location:** ${_complaintData['location_hint'] ?? 'Aapka current location'}
⏰ **Submit kiya:** ${DateTime.now().toString().split('.')[0]}

---

**Aage ke steps:**
1️⃣ Department 24 hours mein review karegi
2️⃣ Aapko notifications se updates milenge
3️⃣ "My Complaints" section mein status track karein

🙏 JanHelp use karne ke liye dhanyavaad!''',
        gu: '''✅ **COMPLAINT SUCCESSFULLY SUBMIT THAY GAYI!**

📋 **Complaint ID:** $complaintId
🏢 **Department:** ${_complaintData['category'] ?? 'Municipal'} Department
📍 **Location:** ${_complaintData['location_hint'] ?? 'Tamari current location'}
⏰ **Submit karyu:** ${DateTime.now().toString().split('.')[0]}

---

**Aagad na steps:**
1️⃣ Department 24 hours ma review karshe
2️⃣ Tamne notifications thi updates malshe
3️⃣ "My Complaints" section ma status track karo

🙏 JanHelp use karvani mate aabhar!''',
        hinglish: '''✅ **COMPLAINT SUCCESSFULLY SUBMIT HO GAYI!**

📋 **Complaint ID:** $complaintId
🏢 **Department:** ${_complaintData['category'] ?? 'Municipal'} Department
📍 **Location:** ${_complaintData['location_hint'] ?? 'Current location'}
⏰ **Submitted:** ${DateTime.now().toString().split('.')[0]}

---

**Next Steps:**
1️⃣ Department 24 hours mein review karegi
2️⃣ Notifications se updates milenge
3️⃣ "My Complaints" mein status track karo

🙏 JanHelp use karne ke liye thank you!''',
      ),
      language: _currentLanguage,
      mood: 'success',
      urgency: 'medium',
      category: _complaintData['category'] as String?,
      subcategory: _complaintData['subcategory'] as String?,
      missingFields: const [],
      actionChecklist: const ['✅ Submitted!', '📱 Track in app'],
      isEmergency: false,
      confidence: 1.0,
      complaintDraft: Map<String, dynamic>.from(_complaintData)..['complaint_id'] = complaintId,
      nextQuestion: '',
      action: 'COMPLETED',
    );
  }


  AssistantReply _offlineReply(_OfflineAnalysis analysis,
      {String? modelTextFallback}) {
    final missing = _missingFields(analysis);
    final nextQuestion = _nextQuestion(analysis, missing);
    final actions = _actions(analysis);
    final autoDetected = analysis.confidence > 0.8 && analysis.category != null;

    // Update conversation state based on detection
    if (autoDetected && _conversationState == 'greeting') {
      _conversationState = 'category_confirmation';
    }

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
    draft['auto_detected'] = autoDetected;
    draft['conversation_state'] = _conversationState;

    // Determine action and confirmation
    String action = 'COLLECT_INFO';
    bool showConfirmation = false;
    String? confirmationQuestion;
    
    if (autoDetected && _conversationState == 'category_confirmation') {
      action = 'CONFIRM';
      showConfirmation = true;
      confirmationQuestion = _localized(
        en: 'Is this the correct category for your complaint?',
        hi: 'Kya ye aapki complaint ke liye sahi category hai?',
        gu: 'Aa tamari complaint mate sachi category chhe?',
        hinglish: 'Ye aapki complaint ke liye correct category hai?',
      );
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
      action: action,
      showConfirmation: showConfirmation,
      confirmationQuestion: confirmationQuestion,
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
    
    // Auto-detected category with high confidence - show confirmation
    if (analysis.category != null && analysis.confidence > 0.8) {
      final emoji = _getCategoryEmoji(analysis.category!);
      return _localized(
        en: '$emoji I detected this as: **${analysis.subcategory ?? analysis.category}**\n\nIs this correct? I can help you file this complaint quickly.',
        hi: '$emoji Maine ise detect kiya: **${analysis.subcategory ?? analysis.category}**\n\nKya ye sahi hai? Main jaldi complaint file kar sakta hun.',
        gu: '$emoji Mane aa detect karyu: **${analysis.subcategory ?? analysis.category}**\n\nAa sachu chhe? Hu jaldi complaint file kari shaku chhu.',
        hinglish: '$emoji Maine detect kiya: **${analysis.subcategory ?? analysis.category}**\n\nYe correct hai? Main quickly complaint file kar sakta hun.',
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

    // Enhanced primary issue detection
    final crimeKeywords = ['chori', 'theft', 'चोरी', 'લૂંટ', 'steal', 'stolen', 'purse', 'wallet', 'mobile', 'robbery', 'loot', 'चोरी हुआ', 'चोरी हो गया', 'fraud', 'scam', 'dhoka', 'ठगी'];
    final missingPersonKeywords = ['gum', 'missing', 'गुम', 'ગુમ', 'gum ho gaya', 'गुम हो गया', 'ગુમ થઈ ગયો', 'lost person', 'person missing', 'bhai gum', 'sister missing', 'bachcha gum', 'missing person'];
    final accidentKeywords = ['accident', 'दुर्घटना', 'અકસ્માત', 'crash', 'hit', 'injured', 'hurt', 'टक्कर', 'ટક્કર'];
    final emergencyKeywords = ['emergency', 'urgent', 'danger', 'fire', 'आपातकाल', 'તાત્કાલિક', 'jaldi', 'turant'];
    
    // Detect primary concern (what user needs help with most)
    String? primaryConcern = null;
    int maxPriorityScore = 0;
    
    // Missing person has highest priority
    if (missingPersonKeywords.any((kw) => normalized.contains(_normalize(kw)))) {
      primaryConcern = 'Police';
      maxPriorityScore = 120; // Higher than crime
    }
    // Crime has high priority
    else if (crimeKeywords.any((kw) => normalized.contains(_normalize(kw)))) {
      primaryConcern = 'Police';
      maxPriorityScore = 100;
    }
    // Emergency situations
    else if (emergencyKeywords.any((kw) => normalized.contains(_normalize(kw)))) {
      // Determine emergency type
      if (normalized.contains('fire') || normalized.contains('आग') || normalized.contains('આગ')) {
        primaryConcern = 'Fire Emergency';
        maxPriorityScore = 95;
      } else if (normalized.contains('medical') || normalized.contains('hospital') || normalized.contains('doctor')) {
        primaryConcern = 'Medical Emergency';
        maxPriorityScore = 95;
      } else {
        primaryConcern = 'Police'; // General emergency
        maxPriorityScore = 90;
      }
    }
    // Traffic accidents
    else if (accidentKeywords.any((kw) => normalized.contains(_normalize(kw)))) {
      primaryConcern = 'Traffic';
      maxPriorityScore = 85;
    }
    
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
        
        // Apply primary concern boost
        if (primaryConcern != null && categoryName == primaryConcern) {
          score += maxPriorityScore;
          signals.add('primary concern detected');
        }
        // Penalize non-primary categories when primary concern is detected
        else if (primaryConcern != null && categoryName != primaryConcern) {
          score -= 50;
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
          
          // Skip location-only keywords for Road category if primary concern is detected
          if (primaryConcern != null && categoryName == 'Road/Pothole' && 
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
          primaryConcern: primaryConcern,
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
      // Make a best guess based on common patterns
      final bestGuess = _makeBestGuess(normalized);
      if (bestGuess != null) {
        return {
          'category': bestGuess['category'],
          'subcategory': bestGuess['subcategory'],
          'confidence': 0.4, // Low but not zero
          'alternatives': const <String>[],
          'matched_signals': bestGuess['signals'] ?? const <String>[],
          'primary_concern': primaryConcern,
          'auto_detected': false,
        };
      }
      
      final rankedCategories = _rankCategoryMatches(input);
      return {
        'category': null,
        'subcategory': null,
        'confidence': 0.0,
        'alternatives':
            rankedCategories.map((e) => e['category'] as String).toList(),
        'matched_signals': const <String>[],
        'primary_concern': primaryConcern,
      };
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    final second = candidates.length > 1 ? candidates[1].score : 0;
    
    // Higher confidence when primary concern is detected
    final confidence = primaryConcern != null && best.category == primaryConcern
        ? max(0.85, min(0.98, best.score / max(1, best.score + second)))
        : max(0.24, min(0.96, best.score / max(1, best.score + second)));
    
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
      'primary_concern': primaryConcern,
      'auto_detected': primaryConcern != null,
    };
  }

  String _formatCandidateLabel(_CategoryCandidate candidate) {
    return '${candidate.subcategory} (${candidate.category})';
  }

  int _keywordScore(
    String input,
    List<String> keywords, {
    List<String>? matchedSignals,
    String? primaryConcern,
    String? currentCategory,
  }) {
    int score = 0;
    final locationOnlyKeywords = ['road', 'sadak', 'रोड', 'સડક', 'street', 'gali', 'lane', 'pise', 'paas', 'samne', 'near', 'behind', 'front'];
    
    for (final keyword in keywords) {
      final key = _normalize(keyword);
      if (key.isEmpty) continue;
      
      // Skip location keywords for Road category if primary concern detected
      if (primaryConcern != null && currentCategory == 'Road/Pothole' && 
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

  Map<String, dynamic>? _makeBestGuess(String normalized) {
    // Simple pattern matching for common issues
    if (normalized.contains('khada') || normalized.contains('khado') || normalized.contains('pothole')) {
      return {
        'category': 'Road/Pothole',
        'subcategory': 'Pothole',
        'signals': ['khada', 'pothole']
      };
    }
    if (normalized.contains('pani') || normalized.contains('water') || normalized.contains('tap')) {
      return {
        'category': 'Water Supply',
        'subcategory': 'No Water Supply',
        'signals': ['pani', 'water']
      };
    }
    if (normalized.contains('kachro') || normalized.contains('garbage') || normalized.contains('trash')) {
      return {
        'category': 'Garbage/Sanitation',
        'subcategory': 'Garbage Not Collected',
        'signals': ['kachro', 'garbage']
      };
    }
    if (normalized.contains('light') || normalized.contains('bijli')) {
      return {
        'category': 'Electricity',
        'subcategory': 'Street Light',
        'signals': ['light', 'bijli']
      };
    }
    return null;
  }

  String _detectLanguage(String input) {
    // First check if user is typing in Hinglish (Roman script with Hindi words)
    if (_looksHinglish(input)) return 'hinglish';
    
    // Check for Gujarati script
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(input)) return 'gu';
    
    // Check for Hindi/Devanagari script
    if (RegExp(r'[\u0900-\u097F]').hasMatch(input)) return 'hi';
    
    // Default to English
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

  // Call OpenRouter API with Qwen model
  Future<Map<String, dynamic>?> _callOpenRouterLLM(String text) async {
    try {
      print('Calling OpenRouter API with text: $text');
      
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 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',
          'HTTP-Referer': 'https://github.com/smartcity/janhelp', // Optional
          'X-Title': 'JanHelp Smart City', // Optional
        },
        body: jsonEncode({
          'model': 'openai/gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a complaint classification assistant for a Smart City app. Analyze the user's complaint and return ONLY a JSON object with these fields:
{
  "category": "one of: Road/Pothole, Drainage/Sewage, Garbage/Sanitation, Electricity, Water Supply, Traffic, Cyber Crime, Police, Construction",
  "subcategory": "specific issue type",
  "urgency": "low, medium, high, or critical",
  "emotion": "neutral, frustrated, angry, urgent, calm",
  "language": "english, hindi, gujarati, or hinglish",
  "is_emergency": true or false,
  "is_critical": true or false,
  "confidence": 0.0 to 1.0
}

Common categories:
- Road/Pothole: potholes, broken roads, waterlogging
- Drainage/Sewage: blocked drains, sewage overflow, bad smell
- Garbage/Sanitation: garbage not collected, dirty areas
- Electricity: power cuts, street lights, exposed wires
- Water Supply: no water, leakage, contaminated water
- Traffic: signal issues, illegal parking, accidents
- Cyber Crime: online fraud, UPI scams, hacking
- Police: theft, missing person, assault, crime
- Construction: illegal construction, debris, noise

Return ONLY valid JSON, no other text.'''
            },
            {
              'role': 'user',
              'content': text
            }
          ],
          'temperature': 0.3,
          'max_tokens': 500,
        }),
      ).timeout(const Duration(seconds: 15));

      print('OpenRouter response status: ${response.statusCode}');
      print('OpenRouter response body: ${response.body}');

      if (response.statusCode != 200) {
        print('HTTP error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] as String?;
      
      if (content == null) {
        print('No content in response');
        return null;
      }

      print('OpenRouter content: $content');

      // Parse JSON response from the model
      try {
        // Extract JSON from markdown code blocks if present
        String jsonStr = content.trim();
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        
        final result = jsonDecode(jsonStr) as Map<String, dynamic>;
        print('Parsed result: $result');
        return result;
      } catch (e) {
        print('Error parsing JSON response: $e');
        return null;
      }
    } catch (e, stackTrace) {
      print('OpenRouter API error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Build reply from your LLM prediction
  AssistantReply _buildReplyFromLLM(Map<String, dynamic> llmResult, String userInput) {
    final category = llmResult['category'] as String?;
    final subcategory = llmResult['subcategory'] as String?;
    final urgency = _normalizeUrgency((llmResult['urgency'] as String?) ?? 'medium');
    final emotion = _normalizeMood((llmResult['emotion'] as String?) ?? 'neutral');
    final language = _normalizeLanguage((llmResult['language'] as String?) ?? _currentLanguage);
    final isEmergency = llmResult['is_emergency'] == true;
    final isCritical = llmResult['is_critical'] == true;
    final confidence = (llmResult['confidence'] as num?)?.toDouble() ?? 0.8;

    // Update complaint data
    final draft = Map<String, dynamic>.from(_complaintData);
    if (category != null) draft['category'] = category;
    if (subcategory != null) draft['subcategory'] = subcategory;
    draft['urgency'] = urgency;
    draft['is_emergency'] = isEmergency;
    draft['is_critical'] = isCritical;

    // Generate response based on detection
    String response;
    String action = 'COLLECT_INFO';
    bool showConfirmation = false;
    String? confirmationQuestion;

    if (isEmergency || isCritical) {
      response = _localized(
        en: '🚨 EMERGENCY DETECTED!\n\nThis appears to be a critical situation: **$category**\n\nIf there is immediate danger, please call 112 now.\n\n📍 Share your exact location so we can send help quickly.',
        hi: '🚨 EMERGENCY DETECTED!\n\nYe ek critical situation lagti hai: **$category**\n\nAgar turant khatra hai to abhi 112 call karein.\n\n📍 Apni exact location share karein taki hum jaldi madad bhej sakein.',
        gu: '🚨 EMERGENCY DETECTED!\n\nAa ek critical situation laghe chhe: **$category**\n\nJo turant jokham hoy to abhi 112 call karo.\n\n📍 Tamari exact location share karo ke ame jaldi madad moki shakiye.',
        hinglish: '🚨 EMERGENCY DETECTED!\n\nYe critical situation hai: **$category**\n\nImmediate danger ho to 112 call karo.\n\n📍 Exact location share karo jaldi help ke liye.',
      );
      action = 'REQUEST_LOCATION';
    } else if (category != null && confidence > 0.7 && _conversationState == 'greeting') {
      _conversationState = 'category_confirmation';
      final emoji = _getCategoryEmoji(category);
      response = _localized(
        en: '$emoji I detected this as: **${subcategory ?? category}**\n\nConfidence: ${(confidence * 100).toStringAsFixed(0)}%\n\nIs this correct? I can help you file this complaint quickly.',
        hi: '$emoji Maine ise detect kiya: **${subcategory ?? category}**\n\nConfidence: ${(confidence * 100).toStringAsFixed(0)}%\n\nKya ye sahi hai? Main jaldi complaint file kar sakta hun.',
        gu: '$emoji Mane aa detect karyu: **${subcategory ?? category}**\n\nConfidence: ${(confidence * 100).toStringAsFixed(0)}%\n\nAa sachu chhe? Hu jaldi complaint file kari shaku chhu.',
        hinglish: '$emoji Maine detect kiya: **${subcategory ?? category}**\n\nConfidence: ${(confidence * 100).toStringAsFixed(0)}%\n\nYe correct hai? Main quickly complaint file kar sakta hun.',
      );
      action = 'CONFIRM';
      showConfirmation = true;
      confirmationQuestion = 'Is this the correct category?';
    } else if (category != null) {
      final emoji = _getCategoryEmoji(category);
      response = _localized(
        en: '$emoji Detected: **${subcategory ?? category}**\n\nNow I need the exact location where this issue is happening.\n\n📍 Please share area, street name, and nearby landmark.',
        hi: '$emoji Detected: **${subcategory ?? category}**\n\nAb mujhe exact location chahiye jahan ye problem hai.\n\n📍 Kripya area, street name aur nearby landmark bataiye.',
        gu: '$emoji Detected: **${subcategory ?? category}**\n\nHave mane exact location joiye jya aa samasya chhe.\n\n📍 Krupaya area, street name ane najikno landmark kaho.',
        hinglish: '$emoji Detected: **${subcategory ?? category}**\n\nAb exact location chahiye jahan problem hai.\n\n📍 Please area, street name aur nearby landmark batao.',
      );
      action = 'REQUEST_LOCATION';
    } else {
      response = _localized(
        en: '🤔 I need more details to identify the issue correctly.\n\nPlease describe your problem in more detail.',
        hi: '🤔 Mujhe issue identify karne ke liye aur details chahiye.\n\nKripya apni problem detail mein batayiye.',
        gu: '🤔 Mane issue identify karvama hor details joiye.\n\nKrupaya tamari samasya detail ma kaho.',
        hinglish: '🤔 Issue identify karne ke liye more details chahiye.\n\nPlease problem detail mein batao.',
      );
    }

    return AssistantReply(
      response: response,
      language: language,
      mood: emotion,
      urgency: urgency,
      category: category,
      subcategory: subcategory,
      missingFields: category == null ? ['issue_category'] : ['exact_location'],
      actionChecklist: _generateActionChecklist(
        category == null ? 'problem_identification' : 'location_request',
        category,
        category == null ? ['issue_category'] : ['exact_location'],
      ),
      isEmergency: isEmergency,
      confidence: confidence,
      complaintDraft: draft,
      nextQuestion: category == null ? 'What type of issue is it?' : 'Where is this issue located?',
      action: action,
      showConfirmation: showConfirmation,
      confirmationQuestion: confirmationQuestion,
    );
  }




  
  List<String> _generateActionChecklist(String currentStep, String? category, List<String> missing) {
    switch (currentStep) {
      case 'greeting':
        return ['📝 Describe your problem', '🎯 I will help you step by step'];
      case 'problem_identification':
        return ['🔍 Analyzing your issue...', '📋 Identifying category'];
      case 'category_confirmation':
        return ['✅ Confirm category', '📝 Provide more details'];
      case 'subcategory_selection':
        return ['🎯 Select specific issue type', '📍 Prepare location info'];
      case 'detail_collection':
        return ['📝 Share more details', '⏰ Mention duration/severity'];
      case 'location_request':
        return ['📍 Share exact location', '🗺️ Use map if needed'];
      case 'photo_request':
        return ['📷 Upload photo evidence', '⏭️ Skip if not available'];
      case 'final_review':
        return ['👀 Review all details', '✅ Submit complaint'];
      default:
        if (category != null) {
          return ['✅ Issue identified as $category', '📍 Share location next'];
        }
        return ['📝 Describe your issue', '🎯 I will guide you'];
    }
  }
  
  String _generateNextQuestion(String currentStep, List<String> missing) {
    switch (currentStep) {
      case 'greeting':
        return 'What problem would you like to report?';
      case 'problem_identification':
        return 'Is this the correct category for your issue?';
      case 'category_confirmation':
        return 'Please confirm if this is correct.';
      case 'subcategory_selection':
        return 'Which specific type of issue is it?';
      case 'detail_collection':
        return 'Please provide more details about the problem.';
      case 'location_request':
        return 'Where exactly is this problem located?';
      case 'photo_request':
        return 'Can you upload a photo of the issue?';
      case 'final_review':
        return 'Should I submit this complaint?';
      default:
        return 'How can I help you today?';
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
    _appLanguage = 'en'; // Reset app language too
    _userMood = 'neutral';
    _sessionId = '';
    _conversationState = 'greeting';
    _categoryConfirmed = false;
    _locationProvided = false;
    _photoUploaded = false;
    _dateProvided = false;
    _finalSummary = {};
    _responseCache.clear();
    print('AI Service reset - new session will be created');
  }

  /// Set the app's selected language for AI responses
  void setAppLanguage(String languageCode) {
    if (['en', 'hi', 'gu'].contains(languageCode)) {
      _appLanguage = languageCode;
      _currentLanguage = languageCode;
      print('✅ App language set to: $languageCode');
    }
  }
}
