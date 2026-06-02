import 'complaint_service.dart';
import 'smart_complaint_extractor.dart';
import 'ml_voice_service.dart';

enum VoiceCallStage {
  greeting,      // welcome + language
  problem,       // what is the problem
  address,       // text address from user
  locationMap,   // show map picker button
  proof,         // show camera/gallery buttons
  datetime,      // ask when did it happen
  dateConfirm,   // AI resolved date, waiting for yes/no
  datePicker,    // show calendar button on screen
  personalName,  // ask for name
  personalPhone, // ask for phone
  personalEmail, // ask for email
  confirm,       // summary confirm
  submitting,    // API call in progress
  done,          // complaint ID shown
}

class VoiceComplaintDraft {
  String language = '';
  String category = '';
  String categoryDisplayName = '';
  String subcategory = '';
  String problemSummary = '';
  String description = '';
  String address = '';
  String city = '';
  String state = '';
  String pincode = '';
  double? latitude;
  double? longitude;
  String proofPath = '';
  bool proofVerified = false;
  String dateNoticed = '';    // raw user speech e.g. "2 din pehle"
  String resolvedDate = '';   // ISO date resolved by AI e.g. "2025-07-10"
  String contactName = '';
  String contactPhone = '';
  String contactEmail = '';
  String complaintId = '';
  double analysisConfidence = 0.0;
  double categoryConfidence = 0.0;
  double subcategoryConfidence = 0.0;
  bool needsCategoryConfirmation = false;
  String assignedDepartmentName = '';
  String assignedDepartmentPhone = '';
  int? assignedDepartmentSlaHours;
  bool duplicateFound = false;
  String duplicateComplaintId = '';
  String duplicateComplaintStatus = '';

  bool get hasLocation => latitude != null && longitude != null;
  String get effectiveAddress {
    if (address.isNotEmpty) return address;
    if (hasLocation) {
      return 'Pinned location (${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)})';
    }
    return '';
  }

  Map<String, dynamic> toDebugJson() {
    return {
      'language': language,
      'category_key': category,
      'category_display_name': categoryDisplayName,
      'subcategory': subcategory,
      'problem_summary': problemSummary,
      'description': description,
      'address': address,
      'effective_address': effectiveAddress,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'proof_path': proofPath,
      'proof_verified': proofVerified,
      'date_noticed': dateNoticed,
      'resolved_date': resolvedDate,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'complaint_id': complaintId,
      'analysis_confidence': analysisConfidence,
      'category_confidence': categoryConfidence,
      'subcategory_confidence': subcategoryConfidence,
      'needs_category_confirmation': needsCategoryConfirmation,
      'assigned_department_name': assignedDepartmentName,
      'assigned_department_phone': assignedDepartmentPhone,
      'assigned_department_sla_hours': assignedDepartmentSlaHours,
      'duplicate_found': duplicateFound,
      'duplicate_complaint_id': duplicateComplaintId,
      'duplicate_complaint_status': duplicateComplaintStatus,
    };
  }

  Map<String, String> toApiFields() {
    final titleBase = problemSummary.isNotEmpty
        ? problemSummary
        : (description.isNotEmpty ? description : category);
    final title = titleBase.length > 100 ? titleBase.substring(0, 100) : titleBase;
    final dateValue = resolvedDate.isNotEmpty ? resolvedDate : dateNoticed;
    final languageCode = _languageToApiCode(language);
    return {
      'complaint_type': category.isNotEmpty ? category : 'other',
      'subcategory': subcategory.isNotEmpty ? subcategory : 'general',
      'title': title.isNotEmpty ? title : 'Voice Complaint',
      'description': description.isNotEmpty
          ? description
          : (problemSummary.isNotEmpty
              ? problemSummary
              : (title.isNotEmpty ? title : 'Reported via Voice AI Assistant.')),
      'address': effectiveAddress.isNotEmpty ? effectiveAddress : 'Location given via AI',
      if (latitude != null) 'latitude': latitude!.toStringAsFixed(6),
      if (longitude != null) 'longitude': longitude!.toStringAsFixed(6),
      if (city.isNotEmpty) 'city': city,
      if (state.isNotEmpty) 'state': state,
      if (pincode.isNotEmpty) 'pincode': pincode,
      if (dateValue.isNotEmpty) 'date_of_occurrence': dateValue,
      if (languageCode.isNotEmpty) 'language': languageCode,
      // Guest contact fields (used if unauthenticated OR by backend as fallback)
      if (contactName.isNotEmpty) ...{
        'guest_name': contactName,
        'name': contactName,
      },
      if (contactPhone.isNotEmpty) ...{
        'guest_phone': contactPhone,
        'mobile_no': contactPhone,
      },
      if (contactEmail.isNotEmpty) ...{
        'guest_email': contactEmail,
        'email': contactEmail,
      },
      if (duplicateFound) 'bypass_duplicate': 'true',
      // Note: preferred_contact_phone/email removed — DRF BooleanField rejects
      // string 'true' from multipart forms. Backend derives this from presence of fields.
      'uploaded_only_verification': 'true',
      'source': 'voice_call',
    };
  }

  String _languageToApiCode(String rawLanguage) {
    final normalized = rawLanguage.trim().toLowerCase();
    switch (normalized) {
      case 'hindi':
      case 'hinglish':
      case 'hi':
        return 'hi';
      case 'gujarati':
      case 'gu':
        return 'gu';
      case 'marathi':
      case 'mr':
        return 'mr';
      case 'english':
      case 'en':
        return 'en';
      default:
        return '';
    }
  }
}

class CallConversationManager {
  VoiceCallStage _stage = VoiceCallStage.greeting;
  final VoiceComplaintDraft draft = VoiceComplaintDraft();
  bool _submitLocked = false; // prevents double-submit
  
  // Cache for categories and subcategories
  Map<String, dynamic> _categoriesCache = {};
  Map<String, List<dynamic>> _subcategoriesCache = {};
  bool _categoriesLoaded = false;
  
  // Smart extractor
  final SmartComplaintExtractor _smartExtractor = SmartComplaintExtractor();
  Map<String, dynamic>? _lastExtractedData;

  VoiceCallStage get stage => _stage;
  
  Map<String, dynamic>? getLastExtractedData() => _lastExtractedData;
  
  String getSmartExplanation(Map<String, dynamic> extracted, String language) {
    return _smartExtractor.getUnderstandingExplanation(extracted, language);
  }

  /// DISHA-STYLE: Detect if user's transcript is a follow-up question
  /// rather than an answer to the current stage's question.
  /// Covers city/complaint-related queries and civic help questions.
  bool isFollowUpQuestion(String transcript) {
    final t = transcript.trim().toLowerCase();
    if (t.length < 4) return false;

    // Don't detect follow-ups during greeting or terminal stages
    if (_stage == VoiceCallStage.greeting || 
        _stage == VoiceCallStage.done ||
        _stage == VoiceCallStage.submitting) return false;

    // Common follow-up question patterns (Hindi/English/Gujarati)
    final followUpPatterns = [
      // Timing questions
      'kitne din', 'kitna time', 'kab tak', 'kab hoga', 'how long', 'how many days',
      'when will', 'time lagega', 'jaldi hoga', 'kitni der',
      // Department questions  
      'kaunsa department', 'kaun dekhega', 'which department', 'who will handle',
      'kis vibhag', 'konse department', 'kaun solve',
      // Status/tracking questions
      'status kaise', 'track kaise', 'how to track', 'how to check', 'pata kaise',
      'complaint status', 'kaise pata chalega', 'update kaise',
      // Anonymous/privacy questions
      'anonymous', 'naam zaruri', 'name required', 'bina naam', 'without name',
      'privacy', 'gupniyata',
      // Previous complaint questions
      'pehle bhi', 'already filed', 'phir se', 'duplicate', 'same complaint',
      'purani complaint',
      // City/civic help questions
      'helpline number', 'office kahan', 'where is office', 'nearest office',
      'complaint office', 'kahan jaun', 'where to go', 'municipal office',
      'nagar palika', 'nagar nigam', 'corporation office',
      // General help questions
      'aur kya kar', 'what else can', 'kya karna chahiye', 'what should i do',
      'madad kaise', 'how to get help', 'kaise help', 'sahayata',
      // Process questions
      'kya hoga', 'what will happen', 'process kya', 'aage kya', 'next step',
      'phir kya hoga', 'complaint ke baad',
      // Fee/cost questions
      'charge lagega', 'paisa lagega', 'free hai', 'is it free', 'cost',
      'fees', 'kharcha',
      // Urgency questions
      'urgent hai', 'emergency', 'turant', 'immediately', 'jaldi karwa',
      'priority', 'jaldi ho sakta',
    ];

    for (final pattern in followUpPatterns) {
      if (t.contains(pattern)) return true;
    }

    // Detect question marks in short utterances (likely a question)
    if (t.contains('?') && t.length < 60) return true;

    // Detect Hindi question words at start of longer phrases
    final hindiQuestionStarts = ['kya ', 'kaise ', 'kab ', 'kahan ', 'kyun ', 'kaun ', 'kitna ', 'kitne ', 'kitni '];
    for (final q in hindiQuestionStarts) {
      if (t.startsWith(q) && t.length > 10 && !_isStageAnswer(t)) return true;
    }

    return false;
  }

  /// Check if the text looks like a direct answer to the current stage question
  /// (to avoid false-positive follow-up detection on actual answers)
  bool _isStageAnswer(String t) {
    switch (_stage) {
      case VoiceCallStage.problem:
        return t.length > 15;
      case VoiceCallStage.address:
        return t.length >= 10;
      case VoiceCallStage.personalName:
        return t.length > 1 && t.length < 40;
      case VoiceCallStage.personalPhone:
        return RegExp(r'\b[6-9]\d{9}\b').hasMatch(t);
      case VoiceCallStage.personalEmail:
        return t.contains('@') || _containsAny(t, ['skip', 'nahi', 'no', 'chhod']);
      default:
        return false;
    }
  }

  // Load categories from API
  Future<void> loadCategories() async {
    if (_categoriesLoaded) return;
    try {
      final result = await ComplaintService.getCategories();
      if (result['success'] == true && result['categories'] != null) {
        final categories = result['categories'] as List;
        for (final cat in categories) {
          final key = cat['key'] ?? cat['id'];
          _categoriesCache[key.toString()] = cat;
        }
        _categoriesLoaded = true;
      }
    } catch (e) {
      print('Failed to load categories: $e');
    }
  }

  // Load subcategories for a category
  Future<List<dynamic>> loadSubcategories(String categoryKey) async {
    if (_subcategoriesCache.containsKey(categoryKey)) {
      return _subcategoriesCache[categoryKey]!;
    }
    try {
      final result = await ComplaintService.getSubcategories(categoryKey);
      if (result['success'] == true && result['subcategories'] != null) {
        final subcats = result['subcategories'] as List;
        _subcategoriesCache[categoryKey] = subcats;
        return subcats;
      }
    } catch (e) {
      print('Failed to load subcategories: $e');
    }
    return [];
  }

  void applyIntakeAnalysis(Map<String, dynamic> analysis) {
    final summary = (analysis['summary'] ?? '').toString().trim();
    final categoryKey = (analysis['category_key'] ?? analysis['category'] ?? '')
        .toString()
        .trim();
    final categoryName = (analysis['category'] ?? '').toString().trim();
    final subcategory = (analysis['subcategory'] ?? '').toString().trim();

    if (summary.isNotEmpty) {
      draft.problemSummary = summary;
      draft.description = summary;
    }
    if (categoryKey.isNotEmpty) draft.category = categoryKey;
    if (categoryName.isNotEmpty) draft.categoryDisplayName = categoryName;
    if (subcategory.isNotEmpty) draft.subcategory = subcategory;

    draft.analysisConfidence = _asDouble(analysis['confidence']);
    draft.categoryConfidence = _asDouble(analysis['category_confidence']);
    draft.subcategoryConfidence = _asDouble(analysis['subcategory_confidence']);
    draft.needsCategoryConfirmation = analysis['needs_confirmation'] == true;

    final locationHint = (analysis['location_hint'] ?? '').toString().trim();
    if (locationHint.isNotEmpty && draft.address.isEmpty) {
      draft.address = locationHint;
    }

    _lastExtractedData = {
      'category': draft.category,
      'subcategory': draft.subcategory,
      'description': draft.description,
      'summary': draft.problemSummary,
      'confidence': draft.analysisConfidence,
    };
  }

  void setDepartmentPreview(Map<String, dynamic> department) {
    draft.assignedDepartmentName = (department['name'] ?? '').toString().trim();
    draft.assignedDepartmentPhone = (department['phone'] ?? '').toString().trim();
    draft.assignedDepartmentSlaHours = department['sla_hours'] is int
        ? department['sla_hours'] as int
        : int.tryParse((department['sla_hours'] ?? '').toString());
  }

  void clearDepartmentPreview() {
    draft.assignedDepartmentName = '';
    draft.assignedDepartmentPhone = '';
    draft.assignedDepartmentSlaHours = null;
  }

  void setDuplicatePreview(Map<String, dynamic> duplicateInfo) {
    draft.duplicateFound = duplicateInfo['duplicate_found'] == true;
    draft.duplicateComplaintId =
        (duplicateInfo['masked_ticket'] ?? duplicateInfo['original_ticket'] ?? '')
            .toString()
            .trim();
    draft.duplicateComplaintStatus =
        (duplicateInfo['complaint_status'] ?? '').toString().trim();
  }

  void clearDuplicatePreview() {
    draft.duplicateFound = false;
    draft.duplicateComplaintId = '';
    draft.duplicateComplaintStatus = '';
  }

  void advanceTo(VoiceCallStage s) {
    // Once submitting/done, never go back via advanceTo
    if (_submitLocked && s != VoiceCallStage.done) return;
    _stage = s;
    if (s == VoiceCallStage.submitting) _submitLocked = true;
  }

  void resetSubmitLock() => _submitLocked = false;

  Future<bool> processUserTranscript(String transcript) async {
    final t = transcript.trim().toLowerCase();
    if (t.isEmpty) return false;

    // Use ML backend for intelligent processing
    final mlResult = await MLVoiceService.processInput(
      text: transcript,
      stage: _stage.toString().split('.').last,
      context: {
        'category': draft.category,
        'subcategory': draft.subcategory,
        'description': draft.description,
        'address': draft.address,
      },
    );

    if (mlResult['success'] == true) {
      // Extract data from ML response
      final extracted = mlResult['extracted_data'] as Map<String, dynamic>? ?? {};
      final nextStage = mlResult['next_stage'] as String? ?? '';
      
      // Update draft with extracted data
      if (extracted['category'] != null) draft.category = extracted['category'];
      if (extracted['subcategory'] != null) draft.subcategory = extracted['subcategory'];
      if (extracted['description'] != null) draft.description = extracted['description'];
      if (extracted['address'] != null) draft.address = extracted['address'];
      if (extracted['contact_name'] != null) draft.contactName = extracted['contact_name'];
      if (extracted['contact_phone'] != null) draft.contactPhone = extracted['contact_phone'];
      if (extracted['contact_email'] != null) draft.contactEmail = extracted['contact_email'];
      if (extracted['date_noticed'] != null) draft.dateNoticed = extracted['date_noticed'];
      if (extracted['resolved_date'] != null) draft.resolvedDate = extracted['resolved_date'];
      
      // Store extracted data for smart explanation
      if (extracted.isNotEmpty) _lastExtractedData = extracted;
      
      // Update stage based on ML recommendation
      if (nextStage.isNotEmpty) {
        final newStage = _parseStage(nextStage);
        if (newStage != null && newStage != _stage) {
          _stage = newStage;
          return true;
        }
      }
    }

    // Fallback to original logic if ML fails
    return _processUserTranscriptFallback(transcript);
  }

  VoiceCallStage? _parseStage(String stageStr) {
    try {
      return VoiceCallStage.values.firstWhere(
        (s) => s.toString().split('.').last == stageStr,
      );
    } catch (e) {
      return null;
    }
  }

  /// Synchronous stage processing — used for INSTANT UI updates.
  /// This runs the same fallback logic but synchronously, ensuring
  /// buttons (map, camera) appear before AI mentions them.
  bool processUserTranscriptSync(String transcript) {
    return _processUserTranscriptFallback(transcript);
  }

  bool _processUserTranscriptFallback(String transcript) {
    final t = transcript.trim().toLowerCase();
    if (t.isEmpty) return false;

    if (_stage == VoiceCallStage.dateConfirm) {
      if (_isAffirmativeResponse(t)) {
        _stage = VoiceCallStage.personalName;
        return true;
      }
      if (_isNegativeResponse(t) || _isSkipResponse(t)) {
        _stage = VoiceCallStage.datePicker;
        return true;
      }
    }

    if (_stage == VoiceCallStage.personalPhone &&
        (_isNegativeResponse(t) || _isSkipResponse(t))) {
      _stage = VoiceCallStage.personalEmail;
      return true;
    }

    if (_stage == VoiceCallStage.personalEmail &&
        (_isNegativeResponse(t) || _isSkipResponse(t))) {
      return false;
    }

    if (_stage == VoiceCallStage.confirm) {
      if (_isAffirmativeResponse(t)) {
        if (_submitLocked) return false;
        _submitLocked = true;
        _stage = VoiceCallStage.submitting;
        return true;
      }
      if (_isNegativeResponse(t)) {
        _stage = VoiceCallStage.problem;
        return true;
      }
    }

    switch (_stage) {
      case VoiceCallStage.greeting:
        // Detect language from user response — all 4 options
        String detectedLang = 'english'; // default fallback
        if (_containsAny(t, ['gujarati', 'guj', 'ગુજરાતી', 'gujrati', 'gujju', 'gujarathi'])) {
          detectedLang = 'gujarati';
        } else if (_containsAny(t, ['hinglish', 'hing', 'mix', 'dono', 'both', 'hindi english'])) {
          detectedLang = 'hinglish';
        } else if (_containsAny(t, ['hindi', 'hin', 'हिंदी', 'हिन्दी', 'hind'])) {
          detectedLang = 'hindi';
        } else if (_containsAny(t, ['english', 'eng', 'angrezi', 'angrez', 'inglis', 'inglish'])) {
          detectedLang = 'english';
        } else if (t == '1' || t == 'one' || t == 'ek' || t == 'first' || t == 'pehla' || t == 'pahla') {
          detectedLang = 'hindi';
        } else if (t == '2' || t == 'two' || t == 'do' || t == 'second' || t == 'dusra') {
          detectedLang = 'english';
        } else if (t == '3' || t == 'three' || t == 'teen' || t == 'third' || t == 'teesra') {
          detectedLang = 'gujarati';
        } else if (t == '4' || t == 'four' || t == 'char' || t == 'fourth' || t == 'chautha') {
          detectedLang = 'hinglish';
        }
        
        draft.language = detectedLang;
        _stage = VoiceCallStage.problem;
        return true;

      case VoiceCallStage.problem:
        if (_isAffirmativeResponse(t) &&
            (draft.description.trim().isNotEmpty ||
                draft.category.trim().isNotEmpty ||
                _lastExtractedData != null)) {
          _stage = VoiceCallStage.address;
          return true;
        }

        if (_isNegativeResponse(t) &&
            (draft.description.trim().isNotEmpty ||
                draft.category.trim().isNotEmpty ||
                _lastExtractedData != null)) {
          draft.problemSummary = '';
          draft.category = '';
          draft.categoryDisplayName = '';
          draft.subcategory = '';
          draft.description = '';
          draft.analysisConfidence = 0.0;
          draft.categoryConfidence = 0.0;
          draft.subcategoryConfidence = 0.0;
          draft.needsCategoryConfirmation = false;
          return false;
        }

        if (t.length > 5) {
          draft.problemSummary = transcript.trim();
          draft.description = transcript.trim();
          _lastExtractedData = {
            'description': draft.description,
            'summary': draft.problemSummary,
          };
          return false;
        }
        return false;

      case VoiceCallStage.address:
        // Accept address if at least 5 chars and not just a confirmation word
        final isJustConfirmation = _isAffirmativeResponse(t);
        if (t.length >= 5 && !isJustConfirmation) {
          draft.address = transcript.trim();
          // Advance to locationMap so map button appears on screen
          _stage = VoiceCallStage.locationMap;
          return true;
        }
        return false;

      case VoiceCallStage.locationMap:
        // User can skip map OR confirm they've done with map
        if (_isNegativeResponse(t) ||
            _isSkipResponse(t) ||
            _isAffirmativeResponse(t) ||
            _containsAny(t, ['done', 'ho gaya', 'kar diya', 'mark', 'marked', 'next', 'aage', 'aagey'])) {
          _stage = VoiceCallStage.proof;
          return true;
        }
        return false;

      case VoiceCallStage.proof:
        if (_isNegativeResponse(t) ||
            _isSkipResponse(t) ||
            _containsAny(t, ['nahi hai', 'photo nahi'])) {
          _stage = VoiceCallStage.datetime;
          return true;
        }
        return false;

      case VoiceCallStage.datetime:
        // Accept any meaningful date expression — AI will resolve it
        if (t.length > 3) {
          draft.dateNoticed = transcript.trim();
          _stage = VoiceCallStage.dateConfirm;
          return true;
        }
        return false;

      case VoiceCallStage.dateConfirm:
        // User confirms or rejects the AI-resolved date
        if (_containsAny(t, ['yes', 'haan', 'ha', 'correct', 'sahi', 'ok', 'okay', 'bilkul', 'theek', 'right'])) {
          _stage = VoiceCallStage.personalName;
          return true;
        }
        // User said no — show date picker
        _stage = VoiceCallStage.datePicker;
        return true;

      case VoiceCallStage.datePicker:
        // UI-only — date picker button on screen handles advancement
        return false;

      case VoiceCallStage.personalName:
        if (t.length > 1) {
          // Extract only the name part (ignore phone numbers if accidentally said)
          final cleaned = transcript.trim().replaceAll(RegExp(r'\b[6-9]\d{9}\b'), '').trim();
          if (cleaned.isNotEmpty) draft.contactName = cleaned;
          _stage = VoiceCallStage.personalPhone;
          return true;
        }
        return false;

      case VoiceCallStage.personalPhone:
        final phone = _extractPhone(t);
        if (phone != null) {
          draft.contactPhone = phone;
          _stage = VoiceCallStage.personalEmail;
          return true;
        }
        // User may have said "nahi hai" or "skip" — advance anyway
        if (_containsAny(t, ['nahi', 'no', 'skip', 'nai', 'nahin', 'chhod'])) {
          _stage = VoiceCallStage.personalEmail;
          return true;
        }
        return false;

      case VoiceCallStage.personalEmail:
        final email = _extractEmail(t);
        if (email != null) {
          draft.contactEmail = email;
          _stage = VoiceCallStage.confirm;
          return true;
        }
        // Email is optional for voice complaints - allow skip.
        if (_containsAny(t, ['nahi', 'no', 'skip', 'nai', 'nahin', 'chhod'])) {
          _stage = VoiceCallStage.confirm;
          return true;
        }
        return false;

      case VoiceCallStage.confirm:
        if (_containsAny(t, ['yes', 'haan', 'ha', 'correct', 'sahi', 'ok', 'okay', 'bilkul', 'confirm'])) {
          if (_submitLocked) return false;
          _submitLocked = true;
          _stage = VoiceCallStage.submitting;
          return true;
        } else if (_containsAny(t, ['no', 'nahi', 'wrong', 'galat', 'change'])) {
          _stage = VoiceCallStage.problem;
          return true;
        }
        return false;

      case VoiceCallStage.submitting:
      case VoiceCallStage.done:
        return false;
    }
  }

  String _detectCategory(String t) {
    // First try to match with loaded categories from API
    if (_categoriesLoaded) {
      for (final entry in _categoriesCache.entries) {
        final cat = entry.value;
        final name = (cat['name'] ?? '').toString().toLowerCase();
        final key = entry.key.toLowerCase();
        if (t.contains(name) || t.contains(key)) {
          return entry.key;
        }
      }
    }
    
    // Fallback to keyword matching
    const map = {
      'police': ['police', 'crime', 'theft', 'chori', 'fight', 'ladai', 'violence', 'suspicious', 'shak'],
      'traffic': ['traffic', 'signal', 'jam', 'accident', 'parking', 'vehicle', 'gaadi'],
      'construction': ['construction', 'building', 'illegal', 'collapse', 'unsafe', 'imarat', 'building giri'],
      'water': ['water', 'paani', 'pani', 'pipe', 'leak', 'supply', 'dirty water', 'ganda paani'],
      'electricity': ['electricity', 'light', 'bijli', 'power', 'electric', 'wire', 'current', 'shock'],
      'garbage': ['garbage', 'waste', 'kachra', 'dustbin', 'cleaning', 'safai', 'ganda'],
      'road': ['road', 'pothole', 'sadak', 'hole', 'broken road', 'khadda', 'footpath'],
      'drainage': ['drainage', 'drain', 'sewage', 'naali', 'overflow', 'waterlog', 'paani bhara'],
      'illegal': ['illegal', 'encroachment', 'unauthorized', 'kabza', 'illegal shop'],
      'transportation': ['bus', 'auto', 'transport', 'rickshaw', 'public transport'],
      'cyber': ['cyber', 'fraud', 'scam', 'online', 'hack', 'phishing', 'dhokha', 'fake'],
    };
    for (final e in map.entries) {
      for (final kw in e.value) {
        if (t.contains(kw)) return e.key;
      }
    }
    return 'other';
  }

  String _detectSubcategory(String t, String category) {
    // First try to match with loaded subcategories from API
    if (_subcategoriesCache.containsKey(category)) {
      final subcats = _subcategoriesCache[category]!;
      for (final subcat in subcats) {
        final name = (subcat['name'] ?? '').toString().toLowerCase();
        final key = (subcat['key'] ?? subcat['id'] ?? '').toString().toLowerCase();
        if (t.contains(name) || t.contains(key)) {
          return subcat['key'] ?? subcat['id'] ?? 'general';
        }
      }
    }
    
    // Fallback to keyword matching
    final subcatMap = {
      'police': {
        'theft': ['theft', 'chori', 'stolen'],
        'fight': ['fight', 'ladai', 'violence'],
        'suspicious': ['suspicious', 'shak', 'doubt'],
      },
      'traffic': {
        'signal_not_working': ['signal', 'light not working'],
        'accident': ['accident', 'crash'],
        'parking': ['parking', 'wrong parking'],
      },
      'water': {
        'no_water': ['no water', 'paani nahi', 'supply nahi'],
        'pipe_leak': ['leak', 'pipe leak', 'pipe toot'],
        'dirty_water': ['dirty', 'ganda paani'],
      },
      'electricity': {
        'power_cut': ['power cut', 'bijli nahi', 'no power'],
        'wire_hanging': ['wire', 'hanging', 'gir gaya'],
        'street_light': ['street light', 'light not working'],
      },
      'garbage': {
        'not_collected': ['not collected', 'nahi uthaya'],
        'overflowing': ['overflow', 'bhar gaya'],
      },
      'road': {
        'pothole': ['pothole', 'hole', 'khadda'],
        'broken_road': ['broken', 'damaged'],
      },
      'drainage': {
        'blocked': ['blocked', 'band'],
        'overflow': ['overflow', 'bhar gaya'],
      },
    };

    if (subcatMap.containsKey(category)) {
      for (final e in subcatMap[category]!.entries) {
        for (final kw in e.value) {
          if (t.contains(kw)) return e.key;
        }
      }
    }
    return 'general';
  }

  String? _extractPhone(String t) =>
      RegExp(r'\b[6-9]\d{9}\b').firstMatch(t)?.group(0);

  String? _extractEmail(String t) =>
      RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}').firstMatch(t)?.group(0);

  String _normalizeIntentText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F\u0A80-\u0AFF+\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesPhrase(String text, String phrase) {
    final normalizedText = _normalizeIntentText(text);
    final normalizedPhrase = _normalizeIntentText(phrase);
    if (normalizedText.isEmpty || normalizedPhrase.isEmpty) {
      return false;
    }
    if (normalizedText == normalizedPhrase) {
      return true;
    }
    return normalizedText.startsWith('$normalizedPhrase ') ||
        normalizedText.endsWith(' $normalizedPhrase') ||
        normalizedText.contains(' $normalizedPhrase ');
  }

  bool _matchesAnyPhrase(String text, List<String> phrases) {
    for (final phrase in phrases) {
      if (_matchesPhrase(text, phrase)) {
        return true;
      }
    }
    return false;
  }

  bool _isAffirmativeResponse(String text) => _matchesAnyPhrase(text, [
        'yes',
        'y',
        'yeah',
        'yep',
        'ok',
        'okay',
        'confirm',
        'confirmed',
        'correct',
        'right',
        'sure',
        'haan',
        'haan ji',
        'han',
        'ha',
        'hmm',
        'hm',
        'hmmm',
        'ji',
        'ji ha',
        'bilkul',
        'theek',
        'thik',
        'sahi',
        'done',
        'ho gaya',
        'kar diya',
      ]);

  bool _isNegativeResponse(String text) => _matchesAnyPhrase(text, [
        'no',
        'n',
        'nope',
        'nah',
        'nahi',
        'nahin',
        'nai',
        'na',
        'wrong',
        'galat',
      ]);

  bool _isSkipResponse(String text) => _matchesAnyPhrase(text, [
        'skip',
        'skip it',
        'later',
        'chhod',
        'chod',
        'baad mein',
        'baad me',
      ]);

  bool _containsAny(String text, List<String> kws) =>
      kws.any((k) => text.contains(k));

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0.0;
  }

  // Legacy compat
  CallStage get legacyStage => CallStage.greeting;

  void reset() {
    _stage = VoiceCallStage.greeting;
    _submitLocked = false;
    _lastExtractedData = null;
    draft.language = '';
    draft.category = '';
    draft.categoryDisplayName = '';
    draft.subcategory = '';
    draft.problemSummary = '';
    draft.description = '';
    draft.address = '';
    draft.city = '';
    draft.state = '';
    draft.pincode = '';
    draft.latitude = null;
    draft.longitude = null;
    draft.proofPath = '';
    draft.proofVerified = false;
    draft.dateNoticed = '';
    draft.resolvedDate = '';
    draft.contactName = '';
    draft.contactPhone = '';
    draft.contactEmail = '';
    draft.complaintId = '';
    draft.analysisConfidence = 0.0;
    draft.categoryConfidence = 0.0;
    draft.subcategoryConfidence = 0.0;
    draft.needsCategoryConfirmation = false;
    draft.assignedDepartmentName = '';
    draft.assignedDepartmentPhone = '';
    draft.assignedDepartmentSlaHours = null;
    draft.duplicateFound = false;
    draft.duplicateComplaintId = '';
    draft.duplicateComplaintStatus = '';
    // Don't reset categories cache
  }
}

// Keep old enum for any existing references
enum CallStage {
  greeting, language, category, subcategory, description,
  dateNoticed, location, landmark, contact, confirm, submitted,
}

class ComplaintDraft {
  String language = '';
  String category = '';
  String subcategory = '';
  String description = '';
  String dateNoticed = '';
  String location = '';
  String landmark = '';
  String contactName = '';
  String contactPhone = '';
  bool get isReadyToConfirm => category.isNotEmpty && description.isNotEmpty && location.isNotEmpty;
  Map<String, dynamic> toJson() => {
    'language': language, 'category': category, 'subcategory': subcategory,
    'description': description, 'date_noticed': dateNoticed, 'location': location,
    'landmark': landmark, 'contact_name': contactName, 'contact_phone': contactPhone,
  };
}
