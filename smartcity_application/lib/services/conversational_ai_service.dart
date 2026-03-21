import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'groq_context_analyzer.dart';

/// Advanced Human-like Conversational AI Service for Smart City Complaints
/// Features: Multi-language, Context-aware, Smart validation, Sentiment analysis
class ConversationalAIService {
  ConversationalAIService._internal();
  static final ConversationalAIService instance = ConversationalAIService._internal();
  factory ConversationalAIService() => instance;

  // Groq API configuration
  static const String _groqApiKey = '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';
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqModel = 'llama-3.1-70b-versatile';
  
  // Context analyzer
  final GroqContextAnalyzer _contextAnalyzer = GroqContextAnalyzer();

  // Enhanced conversation state
  String _currentStep = 'greeting';
  final Map<String, dynamic> _complaintData = {};
  final List<Map<String, String>> _conversationHistory = [];
  String _userCity = '';
  String _userName = '';
  String _userLanguage = 'en';
  int _retryCount = 0;
  String _sentiment = 'neutral';
  double _urgencyScore = 0.5;
  final Map<String, dynamic> _aiContext = {};
  bool _isSmartMode = true;
  DateTime _conversationStartTime = DateTime.now();
  Map<String, dynamic>? _userProfile;

  // 12 Main Categories (matching database COMPLAINT_TYPES)
  static const List<Map<String, String>> categories = [
    {'key': 'police', 'name': 'Police Complaint', 'emoji': '👮'},
    {'key': 'traffic', 'name': 'Traffic Complaint', 'emoji': '🚦'},
    {'key': 'construction', 'name': 'Construction Complaint', 'emoji': '🏗️'},
    {'key': 'water', 'name': 'Water Supply', 'emoji': '💧'},
    {'key': 'electricity', 'name': 'Electricity', 'emoji': '⚡'},
    {'key': 'garbage', 'name': 'Garbage/Sanitation', 'emoji': '🗑️'},
    {'key': 'road', 'name': 'Road/Pothole', 'emoji': '🛣️'},
    {'key': 'drainage', 'name': 'Drainage/Sewage', 'emoji': '🚰'},
    {'key': 'illegal', 'name': 'Illegal Activities', 'emoji': '⚠️'},
    {'key': 'transportation', 'name': 'Transportation', 'emoji': '🚌'},
    {'key': 'cyber', 'name': 'Cyber Crime', 'emoji': '💻'},
    {'key': 'other', 'name': 'Other Complaint', 'emoji': '📝'},
  ];

  // Subcategories (matching database structure)
  static const Map<String, List<String>> subcategories = {
    'police': [
      'Theft',
      'Missing Person',
      'Assault',
      'Harassment',
      'Robbery',
      'Suspicious Activity',
      'Domestic Violence',
      'Chain Snatching',
      'Burglary',
      'Other Police Matter'
    ],
    'traffic': [
      'Broken Signal',
      'Illegal Parking',
      'Traffic Jam',
      'Accident',
      'Rash Driving',
      'No Traffic Police',
      'Missing Road Markings',
      'Broken Speed Breaker',
      'Wrong Way Driving',
      'Other Traffic Issue'
    ],
    'construction': [
      'Illegal Construction',
      'Construction Debris',
      'Noise Pollution',
      'Unauthorized Building',
      'Encroachment',
      'Unsafe Construction',
      'Blocking Road',
      'No Permission',
      'Violation of Rules',
      'Other Construction Issue'
    ],
    'water': [
      'No Water Supply',
      'Water Leakage',
      'Dirty Water',
      'Low Pressure',
      'Pipe Burst',
      'Contaminated Water',
      'Irregular Supply',
      'Meter Issue',
      'Illegal Connection',
      'Other Water Issue'
    ],
    'electricity': [
      'Power Cut',
      'Street Light Not Working',
      'Exposed Wire',
      'Transformer Issue',
      'Flickering',
      'Voltage Fluctuation',
      'Meter Problem',
      'Illegal Connection',
      'Pole Damage',
      'Other Electricity Issue'
    ],
    'garbage': [
      'Garbage Not Collected',
      'Overflowing Dustbin',
      'Illegal Dumping',
      'Dead Animal',
      'Littering',
      'Burning Garbage',
      'No Dustbin Available',
      'Broken Dustbin',
      'Medical Waste',
      'Other Garbage Issue'
    ],
    'road': [
      'Pothole',
      'Broken Road',
      'Waterlogging',
      'Road Blockage',
      'Cracked Road',
      'Road Cave-in',
      'Uneven Surface',
      'Missing Road Signs',
      'Road Debris',
      'Other Road Issue'
    ],
    'drainage': [
      'Blocked Drain',
      'Sewage Overflow',
      'Bad Smell',
      'Open Manhole',
      'Clogged Gutter',
      'Broken Drain Cover',
      'Stagnant Water',
      'Sewage Leakage',
      'Drain Collapse',
      'Other Drainage Issue'
    ],
    'illegal': [
      'Illegal Parking',
      'Illegal Construction',
      'Illegal Dumping',
      'Illegal Hoarding',
      'Encroachment',
      'Unauthorized Activity',
      'Illegal Business',
      'Other Illegal Activity'
    ],
    'transportation': [
      'Bus Not Available',
      'Bus Delay',
      'Overcrowding',
      'Rash Driving',
      'Poor Condition',
      'Route Issue',
      'Other Transportation Issue'
    ],
    'cyber': [
      'Online Fraud',
      'UPI Scam',
      'Phishing',
      'Account Hacked',
      'Identity Theft',
      'Fake Website',
      'Social Media Fraud',
      'OTP Fraud',
      'Banking Fraud',
      'Other Cyber Crime'
    ],
    'other': [
      'Park Maintenance',
      'Tree Cutting Required',
      'Stray Animals',
      'Noise Complaint',
      'Air Pollution',
      'Illegal Hoarding',
      'Public Property Damage',
      'Encroachment',
      'Other Issue',
      'General Complaint'
    ],
  };

  /// Get categories (static only)
  List<Map<String, dynamic>> _getCategories() {
    return categories.map((c) => Map<String, dynamic>.from(c)).toList();
  }
  
  /// Get subcategories (static only)
  List<String> _getSubcategories(String categoryKey) {
    return subcategories[categoryKey] ?? ['Other'];
  }
  Future<ConversationResponse> processInput(
    String userInput, {
    String? userName,
    String? userCity,
    String? language,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? userProfile,
  }) async {
    if (userName != null) _userName = userName;
    if (userCity != null) _userCity = userCity;
    if (language != null) _userLanguage = language;
    if (userProfile != null) _userProfile = userProfile;

    // IMPORTANT: Don't check for new issues when user is providing details for current complaint
    // Only check when user is in early stages (greeting, category selection)
    final isProvidingDetails = _currentStep == 'problem' || 
                                _currentStep == 'subcategory' || 
                                _currentStep == 'date' || 
                                _currentStep == 'location' ||
                                _currentStep == 'photo' ||
                                _currentStep == 'personal_details' ||
                                _currentStep == 'summary' ||
                                _currentStep == 'confirm';
    
    // Only detect new issues if NOT providing details and category is already selected
    if (!isProvidingDetails && 
        _currentStep != 'greeting' && 
        _currentStep != 'submitted' && 
        _currentStep != 'category' &&
        _complaintData.containsKey('category_key')) {
      
      final newProblemDetected = await _detectCategoryWithAI(userInput);
      if (newProblemDetected != null && 
          newProblemDetected['key'] != _complaintData['category_key'] &&
          !userInput.toLowerCase().contains('yes') &&
          !userInput.toLowerCase().contains('no') &&
          !userInput.toLowerCase().contains('skip') &&
          userInput.length > 15) {
        
        // Store the new problem for later
        if (!_aiContext.containsKey('pending_issues')) {
          _aiContext['pending_issues'] = [];
        }
        (_aiContext['pending_issues'] as List).add({
          'category': newProblemDetected['name'],
          'category_key': newProblemDetected['key'],
          'description': userInput,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        final currentCategory = _complaintData['category_emoji'] ?? '📝';
        final currentCategoryName = _complaintData['category'] ?? 'Current issue';
        
        return ConversationResponse(
          message: '''👍 **Got it!** I noticed you mentioned another issue: **${newProblemDetected['emoji']} ${newProblemDetected['name']}**

📝 **Current Progress:**
$currentCategory $currentCategoryName - ${_getCurrentStepProgress()}

💡 **Smart Suggestion:**
Let's complete the current complaint first for faster resolution. I've noted your other issue and we can handle it right after!

🎯 **Continue with current issue?**''',
          buttons: ['✅ Yes, Continue', '🔄 Switch to New Issue', '📋 See All Issues'],
          suggestions: [],
          step: _currentStep,
          showInput: false,
        );
      }
    }

    // Analyze sentiment and urgency
    await _analyzeSentimentAndUrgency(userInput);

    _conversationHistory.add({
      'role': 'user',
      'content': userInput,
      'timestamp': DateTime.now().toIso8601String(),
      'sentiment': _sentiment,
      'urgency': _urgencyScore.toString(),
    });

    ConversationResponse response;

    switch (_currentStep) {
      case 'greeting':
        response = await _handleGreeting(userInput);
        break;
      case 'category':
        response = await _handleCategorySelection(userInput);
        break;
      case 'subcategory':
        response = await _handleSubcategorySelection(userInput);
        break;
      case 'problem':
        response = await _handleProblemDescription(userInput);
        break;
      case 'date':
        response = await _handleDateSelection(userInput);
        break;
      case 'location':
        response = await _handleLocationInput(userInput);
        break;
      case 'address':
        response = await _handleAddressInput(userInput);
        break;
      case 'photo':
        response = await _handlePhotoUpload(userInput);
        break;
      case 'personal_details':
        response = await _handlePersonalDetails(userInput);
        break;
      case 'summary':
        response = _showEnhancedFinalSummary();
        break;
      case 'confirm':
        response = await _handleConfirmation(userInput);
        break;
      case 'submitted':
        response = _showEnhancedSuccess();
        break;
      default:
        response = await _handleGreeting(userInput);
    }

    _conversationHistory.add({
      'role': 'assistant',
      'content': response.message,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return response;
  }

  /// Analyze sentiment and urgency using AI
  Future<void> _analyzeSentimentAndUrgency(String input) async {
    final lower = input.toLowerCase();
    
    if (lower.contains('urgent') || lower.contains('emergency') || 
        lower.contains('immediately') || lower.contains('asap') ||
        lower.contains('critical') || lower.contains('danger')) {
      _sentiment = 'urgent';
      _urgencyScore = 0.9;
    } else if (lower.contains('angry') || lower.contains('frustrated') ||
               lower.contains('terrible') || lower.contains('worst')) {
      _sentiment = 'negative';
      _urgencyScore = 0.7;
    } else if (lower.contains('please') || lower.contains('help') ||
               lower.contains('need')) {
      _sentiment = 'neutral';
      _urgencyScore = 0.5;
    } else {
      _sentiment = 'neutral';
      _urgencyScore = 0.4;
    }
  }

  /// Get urgency level
  String _getUrgencyLevel() {
    if (_urgencyScore >= 0.8) return 'Critical';
    if (_urgencyScore >= 0.6) return 'High';
    if (_urgencyScore >= 0.4) return 'Medium';
    return 'Low';
  }

  /// Estimate resolution time
  String _estimateResolutionTime() {
    final category = _complaintData['category_key'] as String?;
    
    switch (category) {
      case 'police':
      case 'cyber':
        return '24-48 hours';
      case 'electricity':
      case 'water':
        return '2-3 days';
      case 'road':
      case 'drainage':
        return '5-7 days';
      case 'garbage':
        return '1-2 days';
      default:
        return '3-5 days';
    }
  }

  /// Step 1: Enhanced Greeting
  Future<ConversationResponse> _handleGreeting(String userInput) async {
    _currentStep = 'category';
    _conversationStartTime = DateTime.now();
    
    final hour = DateTime.now().hour;
    String timeGreeting;
    String emoji;
    if (hour < 12) {
      timeGreeting = 'Good morning';
      emoji = '🌅';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
      emoji = '☀️';
    } else {
      timeGreeting = 'Good evening';
      emoji = '🌆';
    }
    
    final greeting = _userName.isNotEmpty
        ? '$emoji $timeGreeting $_userName!'
        : '$emoji $timeGreeting!';

    final detectedCategory = await _detectCategoryWithAI(userInput);
    if (detectedCategory != null && userInput.length > 20) {
      return await _handleCategorySelection(userInput);
    }

    final categoryButtons = _getCategories().map((c) => '${c['emoji']} ${c['name']}').toList();
    
    print('📝 Showing ${categoryButtons.length} categories to user');

    return ConversationResponse(
      message: '''$greeting

I'm JANHELP, your friendly AI assistant! 😊 I'm here to help you report issues in ${_userCity.isNotEmpty ? _userCity : 'your city'} and make sure they get resolved quickly.

Don't worry, I'll guide you through everything step by step. Just tell me what's bothering you, and I'll take care of the rest! 💪

🗣️ You can describe your problem naturally - I understand! What issue would you like to report?''',
      buttons: categoryButtons,
      suggestions: [
        'There\'s a big pothole on my street',
        'We haven\'t had water since morning',
        'Street light is broken - it\'s dark at night',
        'Garbage hasn\'t been collected for days',
      ],
      step: 'category',
      showInput: true,
      inputPlaceholder: 'Tell me what happened...',
    );
  }

  /// Step 2: Enhanced category selection
  Future<ConversationResponse> _handleCategorySelection(String userInput) async {
    if (_complaintData.containsKey('category_retry')) {
      _retryCount++;
    }

    // Check if user is trying to report multiple issues at once
    final multipleIssuesDetected = _detectMultipleIssues(userInput);
    if (multipleIssuesDetected != null && multipleIssuesDetected.length > 1) {
      return ConversationResponse(
        message: '''I can see you're dealing with multiple problems! 😟 That must be really frustrating.

You mentioned:
${multipleIssuesDetected.map((issue) => '• ${issue['emoji']} ${issue['name']}').join('\n')}

To help you better, let's handle one issue at a time so each gets the attention it deserves. Which one is bothering you the most right now?''',
        buttons: multipleIssuesDetected.map((issue) => '${issue['emoji']} ${issue['name']}').toList(),
        suggestions: ['The most urgent one', 'All are equally important'],
        step: 'category',
        showInput: true,
        inputPlaceholder: 'Which one first?',
      );
    }

    final detectedCategory = await _detectCategoryWithAI(userInput);
    
    if (detectedCategory != null) {
      _complaintData['category'] = detectedCategory['name'];
      _complaintData['category_key'] = detectedCategory['key'];
      _complaintData['category_emoji'] = detectedCategory['emoji'];
      _complaintData['raw_description'] = userInput;
      
      _currentStep = 'subcategory';
      
      final subs = _getSubcategories(detectedCategory['key']!);
      
      String empathyNote = '';
      if (_urgencyScore > 0.7) {
        empathyNote = '\n\nI can sense this is urgent. Don\'t worry, I\'ll make sure this gets priority attention! 🚨';
      } else {
        empathyNote = '\n\nI understand, let me help you with this. 🤝';
      }
      
      return ConversationResponse(
        message: '${detectedCategory['emoji']} Got it! So this is about **${detectedCategory['name']}**.$empathyNote\n\nCould you tell me more specifically what\'s happening? This will help the right team address it quickly.',
        buttons: subs,
        suggestions: _getSmartSuggestions(detectedCategory['key']!),
        step: 'subcategory',
        showInput: true,
        inputPlaceholder: 'What exactly is the problem?',
        urgencyLevel: _getUrgencyLevel(),
      );
    } else {
      _complaintData['category_retry'] = true;
      
      if (_retryCount > 2) {
        final allCategories = _getCategories();
        return ConversationResponse(
          message: 'No worries! Let me show you all the categories we handle. Just pick the one that matches your issue best:',
          buttons: allCategories.map((c) => '${c['emoji']} ${c['name']}').toList(),
          suggestions: [],
          step: 'category',
          showInput: true,
        );
      }
      
      final someCategories = _getCategories().take(6).toList();
      return ConversationResponse(
        message: '''I want to make sure I understand you correctly! 😊

Could you describe it a bit differently? For example:
• "There\'s a big pothole on Main Street"
• "We haven\'t had water since yesterday"
• "The street light near the park is broken"

Or just pick from these common issues:''',
        buttons: someCategories.map((c) => '${c['emoji']} ${c['name']}').toList(),
        suggestions: ['Road is damaged', 'Water problem', 'Electricity issue'],
        step: 'category',
        showInput: true,
      );
    }
  }

  /// Step 3: Subcategory selection
  Future<ConversationResponse> _handleSubcategorySelection(String userInput) async {
    final categoryKey = _complaintData['category_key'] as String?;
    
    String? matchedSub;
    if (categoryKey != null) {
      final subs = _getSubcategories(categoryKey);
      for (var sub in subs) {
        if (userInput.toLowerCase().contains(sub.toLowerCase())) {
          matchedSub = sub;
          break;
        }
      }
    }
    
    _complaintData['subcategory'] = matchedSub ?? userInput;
    _currentStep = 'problem';
    
    final smartQuestions = _getSmartQuestions(categoryKey ?? '');
    
    return ConversationResponse(
      message: '''Perfect! So it's **${_complaintData['subcategory']}**. I've got that noted down. ✅

Now, to help the team understand the situation better, could you share some details? Things like:

$smartQuestions

The more you tell me, the faster they can fix it! 🔧''',
      buttons: [],
      suggestions: _getDetailedSuggestions(categoryKey ?? ''),
      step: 'problem',
      showInput: true,
      inputPlaceholder: 'Describe what you see...',
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 4: Problem description with validation
  Future<ConversationResponse> _handleProblemDescription(String userInput) async {
    if (userInput.length < 10) {
      return ConversationResponse(
        message: 'I hear you! Could you tell me a bit more about it? 😊\n\nThe more details you share, the better I can help get this resolved quickly!',
        buttons: [],
        suggestions: _getDetailedSuggestions(_complaintData['category_key'] ?? ''),
        step: 'problem',
        showInput: true,
      );
    }
    
    _complaintData['description'] = userInput;
    _currentStep = 'date';
    
    return ConversationResponse(
      message: 'Thank you for those details! That really helps. 👍\n\nOne quick question - when did you first notice this problem?',
      buttons: ['Today', 'Yesterday', '2-3 days ago', 'Last week', 'More than a week ago'],
      suggestions: ['This morning', 'A few days back', 'It\'s been weeks'],
      step: 'date',
      showInput: true,
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 5: Date selection
  Future<ConversationResponse> _handleDateSelection(String userInput) async {
    final normalizedDate = _normalizeDateInput(userInput);
    _complaintData['date_noticed'] = normalizedDate;
    
    final duration = _calculateDuration(normalizedDate);
    if (duration > 7) {
      _urgencyScore = (_urgencyScore + 0.2).clamp(0.0, 1.0);
    }
    
    _currentStep = 'location';
    
    return ConversationResponse(
      message: '📍 Perfect! Where exactly is this issue?\n\n⚠️ **Important:** Provide the complaint/incident location, NOT your personal address\n\nYou can:\n• 📍 Share incident location\n• 📝 Type location address\n• 🏛️ Describe landmark',
      buttons: ['📍 Use Current Location', 'Type Address'],
      suggestions: [
        'Near ${_userCity} Station',
        'Main Market',
        'Behind Hospital',
      ],
      step: 'location',
      showInput: true,
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 6: Location input with duplicate check and department assignment
  Future<ConversationResponse> _handleLocationInput(String userInput) async {
    if (userInput.length < 5 && !userInput.contains('location')) {
      return ConversationResponse(
        message: '🤔 More location details?\n\n⚠️ Remember: Provide complaint/incident location\n\n• Street name\n• Nearby landmarks\n• Area/sector',
        buttons: ['📍 Use Current Location', '📝 Enter Full Address'],
        suggestions: ['Main Road, Sector 5', 'Near Hospital'],
        step: 'location',
        showInput: true,
      );
    }
    
    _complaintData['location'] = userInput;
    
    // Check for duplicate complaints if location coordinates are available
    if (_complaintData.containsKey('latitude') && _complaintData.containsKey('longitude')) {
      final duplicateInfo = await _checkDuplicateComplaint(
        _complaintData['latitude'],
        _complaintData['longitude'],
      );
      
      if (duplicateInfo != null && duplicateInfo['duplicate_found'] == true) {
        _complaintData['duplicate_found'] = true;
        _complaintData['duplicate_ticket'] = duplicateInfo['masked_ticket'];
        
        return ConversationResponse(
          message: '''⚠️ **Duplicate Complaint Found**

${duplicateInfo['message']}

**Existing Ticket:** ${duplicateInfo['masked_ticket']}
**Status:** ${duplicateInfo['complaint_status']}
**Reported:** ${duplicateInfo['created_at']}

This issue is already being handled by our team. You can track it using the ticket number above.

🤔 Would you like to:
• Track the existing complaint
• Submit a different complaint''',
          buttons: ['📋 Track Existing', '➕ New Complaint', '❌ Cancel'],
          suggestions: [],
          step: 'duplicate_found',
          showInput: false,
        );
      }
      
      // Get nearest department
      final departmentInfo = await _getNearestDepartment(
        _complaintData['latitude'],
        _complaintData['longitude'],
      );
      
      if (departmentInfo != null && departmentInfo['success'] == true) {
        final dept = departmentInfo['department'];
        _complaintData['assigned_department'] = dept['name'];
        _complaintData['department_phone'] = dept['phone'];
        _complaintData['department_email'] = dept['email'];
        _complaintData['sla_hours'] = dept['sla_hours'];
        
        _aiContext['department_assigned'] = true;
      }
    }
    
    // Move to address step
    _currentStep = 'address';
    
    return ConversationResponse(
      message: '📍 Location noted!\n\n📮 Please provide full address with pincode:\n\n• House/Building number\n• Street/Area\n• City\n• Pincode',
      buttons: ['⏭️ Skip (Use location only)'],
      suggestions: [
        '123, MG Road, Ahmedabad, 380001',
        'Near City Hospital, Sector 5, 380015',
      ],
      step: 'address',
      showInput: true,
      inputPlaceholder: 'Full address with pincode...',
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 7: Full address input
  Future<ConversationResponse> _handleAddressInput(String userInput) async {
    if (!userInput.toLowerCase().contains('skip')) {
      _complaintData['full_address'] = userInput;
      
      // Try to extract pincode
      final pincodeRegex = RegExp(r'\b\d{6}\b');
      final match = pincodeRegex.firstMatch(userInput);
      if (match != null) {
        _complaintData['pincode'] = match.group(0);
      }
    }
    
    _currentStep = 'photo';
    
    final categoryKey = _complaintData['category_key'] as String?;
    String photoMessage = '📸 Would you like to add a photo?\n\n✨ Photos help:';
    
    // Add department info if assigned
    if (_complaintData.containsKey('assigned_department')) {
      photoMessage = '''✅ **Location Confirmed**

📍 Your complaint will be assigned to:
🏛️ **${_complaintData['assigned_department']}**
📞 Contact: ${_complaintData['department_phone']}
⏱️ Expected resolution: ${_complaintData['sla_hours']} hours

---

📸 Would you like to add a photo?\n\n✨ Photos help:''';
    }
    
    switch (categoryKey) {
      case 'road':
        photoMessage += '\n• See exact damage\n• Assess severity\n• Plan repairs';
        break;
      case 'garbage':
        photoMessage += '\n• Verify situation\n• Take action\n• Prevent hazards';
        break;
      default:
        photoMessage += '\n• Understand issue\n• Respond faster\n• Resolve better';
    }
    
    return ConversationResponse(
      message: photoMessage,
      buttons: ['📷 Take Photo', '🖼️ Gallery', '⏭️ Skip'],
      suggestions: [],
      step: 'photo',
      showInput: false,
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 8: Photo upload
  Future<ConversationResponse> _handlePhotoUpload(String userInput) async {
    _complaintData['has_photo'] = !userInput.toLowerCase().contains('skip');
    _currentStep = 'personal_details';
    return _showPersonalDetailsConfirmation();
  }

  /// Step 9: Personal details confirmation - fetch from profile first
  ConversationResponse _showPersonalDetailsConfirmation() {
    _currentStep = 'personal_details';
    
    // Extract profile data
    String? name = _userProfile?['fullName'] ?? _userName;
    String? mobile = _userProfile?['mobile'];
    String? email = _userProfile?['email'];
    
    // Check what's missing
    final missingFields = <String>[];
    if (name == null || name.isEmpty) missingFields.add('Name');
    if (mobile == null || mobile.isEmpty) missingFields.add('Mobile');
    if (email == null || email.isEmpty) missingFields.add('Email');
    
    // If all details available, auto-fill and confirm
    if (missingFields.isEmpty) {
      _complaintData['contact_name'] = name!;
      _complaintData['contact_mobile'] = mobile!;
      _complaintData['contact_email'] = email!;
      
      return ConversationResponse(
        message: '''👤 **Personal Details Confirmation**

I've fetched your details from profile:

📛 **Name:** $name
📱 **Mobile:** $mobile
📧 **Email:** $email

---

These details will be used to contact you regarding this complaint.''',
        buttons: ['✅ Confirm Details', '✏️ Edit Details'],
        suggestions: [],
        step: 'personal_details',
        showInput: false,
      );
    }
    
    // If some details available, show them and ask for missing ones
    if (missingFields.length < 3) {
      String availableInfo = '';
      if (name != null && name.isNotEmpty) {
        availableInfo += '📛 **Name:** $name\n';
        _complaintData['contact_name'] = name;
      }
      if (mobile != null && mobile.isNotEmpty) {
        availableInfo += '📱 **Mobile:** $mobile\n';
        _complaintData['contact_mobile'] = mobile;
      }
      if (email != null && email.isNotEmpty) {
        availableInfo += '📧 **Email:** $email\n';
        _complaintData['contact_email'] = email;
      }
      
      return ConversationResponse(
        message: '''👤 **Personal Details**

From your profile:
$availableInfo
---

📝 Please provide missing details:
${missingFields.map((f) => '• $f').join('\n')}

Format: ${missingFields.join(', ')}
Example: ${missingFields.contains('Name') ? 'John Doe' : ''}${missingFields.contains('Mobile') ? (missingFields.contains('Name') ? ', ' : '') + '9876543210' : ''}${missingFields.contains('Email') ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}''',
        buttons: [],
        suggestions: [],
        step: 'personal_details',
        showInput: true,
        inputPlaceholder: missingFields.join(', '),
      );
    }
    
    // If no details available, ask for all
    return ConversationResponse(
      message: '''👤 **Personal Details Required**

To process your complaint, we need your contact information.

📝 Please provide:

1️⃣ Your full name
2️⃣ Mobile number
3️⃣ Email address

Format: Name, Mobile, Email
Example: John Doe, 9876543210, john@email.com''',
      buttons: [],
      suggestions: [],
      step: 'personal_details',
      showInput: true,
      inputPlaceholder: 'Name, Mobile, Email',
    );
  }

  /// Step 10: Handle personal details
  Future<ConversationResponse> _handlePersonalDetails(String userInput) async {
    if (userInput.toLowerCase().contains('confirm')) {
      _currentStep = 'summary';
      return _showEnhancedFinalSummary();
    } else if (userInput.toLowerCase().contains('edit')) {
      return ConversationResponse(
        message: '''✏️ **Update Personal Details**

Please provide your updated information:

Format: Name, Mobile, Email
Example: John Doe, 9876543210, john@email.com''',
        buttons: [],
        suggestions: [],
        step: 'personal_details',
        showInput: true,
        inputPlaceholder: 'Name, Mobile, Email',
      );
    } else {
      // Parse input based on what's missing
      final parts = userInput.split(',').map((e) => e.trim()).toList();
      
      // Check what was already filled from profile
      final hasName = _complaintData.containsKey('contact_name') && _complaintData['contact_name'].toString().isNotEmpty;
      final hasMobile = _complaintData.containsKey('contact_mobile') && _complaintData['contact_mobile'].toString().isNotEmpty;
      final hasEmail = _complaintData.containsKey('contact_email') && _complaintData['contact_email'].toString().isNotEmpty;
      
      final missingCount = [hasName, hasMobile, hasEmail].where((has) => !has).length;
      
      if (parts.length >= missingCount) {
        int partIndex = 0;
        
        if (!hasName && partIndex < parts.length) {
          _complaintData['contact_name'] = parts[partIndex++];
        }
        if (!hasMobile && partIndex < parts.length) {
          _complaintData['contact_mobile'] = parts[partIndex++];
        }
        if (!hasEmail && partIndex < parts.length) {
          _complaintData['contact_email'] = parts[partIndex++];
        }
        
        _currentStep = 'summary';
        return _showEnhancedFinalSummary();
      } else {
        final missingFields = <String>[];
        if (!hasName) missingFields.add('Name');
        if (!hasMobile) missingFields.add('Mobile');
        if (!hasEmail) missingFields.add('Email');
        
        return ConversationResponse(
          message: '''❌ **Invalid Format**

Please provide all missing details separated by commas:

Missing: ${missingFields.join(', ')}
Format: ${missingFields.join(', ')}
Example: ${missingFields.contains('Name') ? 'John Doe' : ''}${missingFields.contains('Mobile') ? (missingFields.contains('Name') ? ', ' : '') + '9876543210' : ''}${missingFields.contains('Email') ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}''',
          buttons: [],
          suggestions: [],
          step: 'personal_details',
          showInput: true,
          inputPlaceholder: missingFields.join(', '),
        );
      }
    }
  }

  /// Step 11: Enhanced summary
  ConversationResponse _showEnhancedFinalSummary() {
    _currentStep = 'confirm';
    
    final priority = _calculatePriority();
    _complaintData['priority'] = priority;
    
    final resolutionTime = _estimateResolutionTime();
    final department = _getAssignedDepartment();
    _complaintData['department'] = department;
    
    final urgencyIndicator = _urgencyScore > 0.7 ? '⚠️ **URGENT** ' : '';
    
    final summary = '''$urgencyIndicator✅ **Complaint Summary**

${_complaintData['category_emoji']} **Category:** ${_complaintData['category']}
📋 **Issue:** ${_complaintData['subcategory']}
📝 **Description:** ${_complaintData['description']}
📅 **Noticed:** ${_complaintData['date_noticed']}
📍 **Location:** ${_complaintData['location']}
📱 **Contact:** ${_complaintData['contact_mobile']}
📧 **Email:** ${_complaintData['contact_email']}
📸 **Photo:** ${_complaintData['has_photo'] == true ? 'Yes ✅' : 'No'}

---

🏛️ **Department:** $department
⏱️ **Est. Resolution:** $resolutionTime
📈 **Priority:** $priority
📊 **Urgency:** ${_getUrgencyLevel()}

---

🤔 Everything correct?''';
    
    return ConversationResponse(
      message: summary,
      buttons: ['✅ Submit', '✏️ Edit', '❌ Cancel'],
      suggestions: [],
      step: 'confirm',
      showInput: false,
      urgencyLevel: _getUrgencyLevel(),
      estimatedResolutionTime: resolutionTime,
    );
  }

  /// Step 12: Confirmation
  Future<ConversationResponse> _handleConfirmation(String userInput) async {
    if (userInput.toLowerCase().contains('submit')) {
      _currentStep = 'submitted';
      _complaintData['submission_time'] = DateTime.now().toIso8601String();
      _complaintData['conversation_duration'] = DateTime.now().difference(_conversationStartTime).inSeconds;
      return _showEnhancedSuccess();
    } else if (userInput.toLowerCase().contains('edit')) {
      _currentStep = 'category';
      _complaintData.clear();
      return ConversationResponse(
        message: '✏️ Let\'s start fresh!\n\n📝 What issue to report?',
        buttons: categories.map((c) => '${c['emoji']} ${c['name']}').toList(),
        suggestions: [],
        step: 'category',
        showInput: true,
      );
    }
    return _resetConversation();
  }

  /// Step 13: Success
  ConversationResponse _showEnhancedSuccess() {
    final complaintId = 'CMP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _complaintData['complaint_id'] = complaintId;
    
    final department = _complaintData['department'] ?? 'Municipal Corporation';
    final priority = _complaintData['priority'] ?? 'Normal';
    final resolutionTime = _estimateResolutionTime();
    
    final trackingUrl = 'smartcity.gov.in/track/$complaintId';
    _complaintData['tracking_url'] = trackingUrl;
    
    final successMessage = '''🎉 **Complaint Submitted!**

📋 **ID:** `$complaintId`
🏛️ **Assigned:** $department
📈 **Priority:** $priority
⏱️ **Est. Resolution:** $resolutionTime

---

✅ **Next Steps:**

1️⃣ Review within 24 hours
2️⃣ Department notified
3️⃣ Updates via notifications
4️⃣ Track in "My Complaints"

---

📱 **Track:** $trackingUrl
🔔 **Notifications:** Enabled
📞 **Helpline:** 1800-XXX-XXXX

Thank you for making ${_userCity.isNotEmpty ? _userCity : 'your city'} better! 🌟''';
    
    return ConversationResponse(
      message: successMessage,
      buttons: ['📋 My Complaints', '➕ New Complaint', '📊 Track', '🏠 Home'],
      suggestions: [],
      step: 'submitted',
      showInput: false,
      complaintData: Map<String, dynamic>.from(_complaintData),
    );
  }

  /// AI category detection with full context analysis
  Future<Map<String, String>?> _detectCategoryWithFullContext(String input) async {
    try {
      // Use context analyzer for better understanding
      final analysis = await _contextAnalyzer.analyzeConversationContext(
        currentInput: input,
        conversationHistory: _conversationHistory,
        currentStep: _currentStep,
        complaintData: _complaintData,
      );
      
      if (analysis['success'] == true) {
        final result = analysis['analysis'];
        final categoryKey = result['category'];
        
        print('Context Analysis: ${result['reasoning']}');
        print('Detected Intent: ${result['intent']}');
        print('Detected Category: $categoryKey');
        
        if (categoryKey != null && categoryKey != 'null') {
          for (var category in categories) {
            if (category['key'] == categoryKey) {
              return category;
            }
          }
        }
      }
    } catch (e) {
      print('Context analysis error: $e');
    }
    
    // Fallback to simple AI detection
    return await _detectCategoryWithAI(input);
  }
  Future<Map<String, String>?> _detectCategoryWithAI(String input) async {
    try {
      // First try fuzzy match for quick response
      final fuzzyMatch = _fuzzyMatchCategory(input);
      if (fuzzyMatch != null) {
        return fuzzyMatch;
      }
      
      // If fuzzy match fails, use Groq AI for better understanding
      final prompt = '''Analyze this user complaint and identify the category. The user might be using regional language (Hindi, Gujarati, etc.) or informal language.

User complaint: "$input"

Available categories:
${categories.map((c) => '- ${c['key']}: ${c['name']} (${c['emoji']})').join('\n')}

Examples:
- "maru bag chorai gyu chhe" → police (theft in Gujarati)
- "road ma khado chhe" → road (pothole in Gujarati)
- "pani nathi avtu" → water (no water in Gujarati)
- "light nathi" → electricity (no power in Gujarati)
- "kachra pado chhe" → garbage (garbage lying in Gujarati)

Respond with ONLY the category key (road, water, electricity, police, garbage, drainage, traffic, construction, cyber, street_light, public_toilet, or other).
No explanation, just the key.''';

      final response = await _callGroqAPI(prompt, maxTokens: 50, temperature: 0.1);
      
      if (response != null) {
        final categoryKey = response.trim().toLowerCase();
        
        for (var category in categories) {
          if (category['key'] == categoryKey) {
            print('Groq AI detected category: $categoryKey for input: $input');
            return category;
          }
        }
      }
    } catch (e) {
      print('Groq AI error: $e');
    }
    
    // Final fallback to fuzzy match
    return _fuzzyMatchCategory(input);
  }

  /// Call Groq API
  Future<String?> _callGroqAPI(String prompt, {int maxTokens = 500, double temperature = 0.3}) async {
    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [
            {
              'role': 'system',
              'content': '''You are Disha, a friendly and empathetic AI assistant for Smart City complaints. 

Your personality:
- Warm, caring, and understanding like a helpful friend
- Patient and supportive, especially when users are frustrated
- Use simple, conversational language (not robotic)
- Show empathy when users describe problems
- Be encouraging and reassuring
- Speak naturally like a human, not like a bot

Your communication style:
- Use casual, friendly tone
- Add empathetic phrases like "I understand", "That must be frustrating", "Don't worry"
- Keep responses concise but warm
- Use natural transitions in conversation
- Acknowledge user emotions

Be precise and helpful while maintaining a human touch.'''
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      }
    } catch (e) {
      print('Groq API failed: $e');
    }
    
    return null;
  }

  /// Validate description with AI
  Future<bool> validateComplaintDescription(String description, String category, String subcategory) async {
    try {
      final prompt = '''Validate if this description matches the category:

Description: "$description"
Category: $category
Subcategory: $subcategory

Does the description match? Is it clear and specific?

Respond: VALID or INVALID|reason''';

      final response = await _callGroqAPI(prompt, maxTokens: 100, temperature: 0.2);
      
      if (response != null) {
        if (response.toUpperCase().startsWith('VALID')) {
          return true;
        } else if (response.toUpperCase().startsWith('INVALID')) {
          final parts = response.split('|');
          if (parts.length > 1) {
            _aiContext['validation_error'] = parts[1].trim();
          }
          return false;
        }
      }
    } catch (e) {
      print('Validation error: $e');
    }
    
    return true;
  }

  /// Detect multiple issues in user input
  List<Map<String, String>>? _detectMultipleIssues(String input) {
    final lower = input.toLowerCase();
    final detectedCategories = <Map<String, String>>[];
    
    for (var category in categories) {
      final keywords = _getCategoryKeywords(category['key']!);
      for (var keyword in keywords) {
        if (lower.contains(keyword)) {
          if (!detectedCategories.any((c) => c['key'] == category['key'])) {
            detectedCategories.add(category);
          }
          break;
        }
      }
    }
    
    return detectedCategories.length > 1 ? detectedCategories : null;
  }
  
  /// Get keywords for category detection
  List<String> _getCategoryKeywords(String categoryKey) {
    switch (categoryKey) {
      case 'road':
        return ['road', 'pothole', 'khado', 'sadak', 'rasta', 'street'];
      case 'water':
        return ['water', 'pani', 'paani', 'tap', 'supply'];
      case 'electricity':
        return ['electricity', 'power', 'light', 'bijli', 'current'];
      case 'garbage':
        return ['garbage', 'trash', 'kachra', 'waste', 'dustbin'];
      case 'drainage':
        return ['drain', 'sewage', 'nali', 'gutter'];
      case 'traffic':
        return ['traffic', 'signal', 'jam'];
      case 'police':
        return ['police', 'theft', 'stolen', 'chorai', 'chori', 'robbery'];
      case 'construction':
        return ['construction', 'building'];
      case 'cyber':
        return ['cyber', 'fraud', 'scam', 'hacked'];
      default:
        return [categoryKey];
    }
  }
  
  /// Get current step progress description
  String _getCurrentStepProgress() {
    final category = _complaintData['category'] ?? 'Category';
    final subcategory = _complaintData['subcategory'];
    
    switch (_currentStep) {
      case 'greeting':
        return 'Starting conversation';
      case 'category':
        return 'Selecting category';
      case 'subcategory':
        return '$category - Selecting type';
      case 'problem':
        return subcategory != null ? '$category - $subcategory' : '$category - Adding details';
      case 'date':
        return subcategory != null ? '$category - $subcategory - Adding date' : '$category - Adding date';
      case 'location':
        return subcategory != null ? '$category - $subcategory - Adding location' : '$category - Adding location';
      case 'photo':
        return subcategory != null ? '$category - $subcategory - Adding photo' : '$category - Adding photo';
      case 'personal_details':
        return subcategory != null ? '$category - $subcategory - Contact details' : '$category - Contact details';
      case 'summary':
        return 'Review & submit';
      default:
        return 'In progress';
    }
  }
  Map<String, String>? _fuzzyMatchCategory(String input) {
    final lower = input.toLowerCase();
    
    // English keywords
    for (var category in categories) {
      if (lower.contains(category['key']!) || lower.contains(category['name']!.toLowerCase())) {
        return category;
      }
    }
    
    // Find category by key helper
    Map<String, String>? findByKey(String key) {
      try {
        return categories.firstWhere(
          (c) => c['key'] == key,
          orElse: () => <String, String>{},
        );
      } catch (e) {
        return null;
      }
    }
    
    // Common English keywords
    if (lower.contains('pothole') || lower.contains('road') || lower.contains('street')) {
      final cat = findByKey('road');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('water') || lower.contains('tap') || lower.contains('supply')) {
      final cat = findByKey('water');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('electricity') || lower.contains('power') || lower.contains('current')) {
      final cat = findByKey('electricity');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('light') && !lower.contains('traffic')) {
      final cat = findByKey('electricity');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('garbage') || lower.contains('trash') || lower.contains('waste') || lower.contains('dustbin')) {
      final cat = findByKey('garbage');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('drain') || lower.contains('sewage') || lower.contains('gutter')) {
      final cat = findByKey('drainage');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('traffic') || lower.contains('signal') || lower.contains('jam')) {
      final cat = findByKey('traffic');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('police') || lower.contains('theft') || lower.contains('stolen') || lower.contains('robbery')) {
      final cat = findByKey('police');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('construction') || lower.contains('building')) {
      final cat = findByKey('construction');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('cyber') || lower.contains('fraud') || lower.contains('scam') || lower.contains('hacked')) {
      final cat = findByKey('cyber');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('transport') || lower.contains('bus')) {
      final cat = findByKey('transportation');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('illegal')) {
      final cat = findByKey('illegal');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    
    // Hindi keywords
    if (lower.contains('sadak') || lower.contains('rasta') || lower.contains('गड्ढा')) {
      final cat = findByKey('road');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('paani') || lower.contains('पानी') || lower.contains('nal')) {
      final cat = findByKey('water');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('bijli') || lower.contains('बिजली')) {
      final cat = findByKey('electricity');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('kachra') || lower.contains('कचरा') || lower.contains('gandagi')) {
      final cat = findByKey('garbage');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('nali') || lower.contains('नाली') || lower.contains('ganda pani')) {
      final cat = findByKey('drainage');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('chori') || lower.contains('चोरी')) {
      final cat = findByKey('police');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    
    // Gujarati keywords
    if (lower.contains('khado') || lower.contains('rasto') || lower.contains('ખાડો')) {
      final cat = findByKey('road');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('pani') || lower.contains('પાણી') || lower.contains('nathi avtu')) {
      final cat = findByKey('water');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('લાઇટ')) {
      final cat = findByKey('electricity');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('કચરો') || lower.contains('pado chhe')) {
      final cat = findByKey('garbage');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    if (lower.contains('chorai') || lower.contains('ચોરાઈ') || lower.contains('bag')) {
      final cat = findByKey('police');
      if (cat != null && cat.isNotEmpty) return cat;
    }
    
    return null;
  }

  /// Calculate priority
  String _calculatePriority() {
    if (_urgencyScore >= 0.8) return 'Critical';
    if (_urgencyScore >= 0.6) return 'High';
    if (_urgencyScore >= 0.4) return 'Medium';
    return 'Normal';
  }

  /// Get assigned department
  String _getAssignedDepartment() {
    final categoryKey = _complaintData['category_key'] as String?;
    
    switch (categoryKey) {
      case 'road': return 'Public Works Department';
      case 'water': return 'Water Supply Department';
      case 'electricity': return 'Electricity Board';
      case 'garbage': return 'Sanitation Department';
      case 'drainage': return 'Drainage Department';
      case 'traffic': return 'Traffic Police';
      case 'police': return 'Police Department';
      case 'construction': return 'Municipal Corporation';
      case 'cyber': return 'Cyber Crime Cell';
      case 'street_light': return 'Electricity Department';
      case 'public_toilet': return 'Sanitation Department';
      default: return 'Municipal Corporation';
    }
  }

  /// Normalize date
  String _normalizeDateInput(String input) {
    final lower = input.toLowerCase();
    final now = DateTime.now();
    
    if (lower.contains('today')) return DateFormat('dd MMM yyyy').format(now);
    if (lower.contains('yesterday')) return DateFormat('dd MMM yyyy').format(now.subtract(Duration(days: 1)));
    if (lower.contains('2-3') || lower.contains('few')) return DateFormat('dd MMM yyyy').format(now.subtract(Duration(days: 3)));
    if (lower.contains('week')) return DateFormat('dd MMM yyyy').format(now.subtract(Duration(days: 7)));
    if (lower.contains('weeks')) return DateFormat('dd MMM yyyy').format(now.subtract(Duration(days: 14)));
    
    return input;
  }

  /// Calculate duration
  int _calculateDuration(String dateStr) {
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      return DateTime.now().difference(date).inDays;
    } catch (e) {
      return 1;
    }
  }

  /// Get smart suggestions
  List<String> _getSmartSuggestions(String categoryKey) {
    final subs = subcategories[categoryKey] ?? [];
    return subs.take(3).toList();
  }

  /// Get smart questions
  String _getSmartQuestions(String categoryKey) {
    switch (categoryKey) {
      case 'road': return '• Location & landmarks\n• Size of damage\n• Causing accidents?\n• Traffic impact';
      case 'water': return '• Your area\n• How long?\n• Many houses affected?\n• Visible leaks?';
      case 'electricity': return '• Affected area\n• Duration\n• Safety hazards?\n• Pole/transformer number';
      case 'garbage': return '• Location\n• How long?\n• Type of waste\n• Health hazards?';
      default: return '• Where exactly?\n• When noticed?\n• How severe?\n• Immediate risks?';
    }
  }

  /// Get detailed suggestions
  List<String> _getDetailedSuggestions(String categoryKey) {
    switch (categoryKey) {
      case 'road':
        return ['Deep pothole causing accidents', 'Road broken for 100 meters', 'Water accumulation'];
      case 'water':
        return ['No water for 3 days', 'Major pipe leaking', 'Very low pressure'];
      case 'electricity':
        return ['Daily 5+ hour cuts', 'Exposed wire hanging', 'All lights not working'];
      case 'garbage':
        return ['Not collected for week', 'Bins overflowing', 'Illegal dumping'];
      default:
        return ['Describe in detail', 'Mention severity', 'Any dangers?'];
    }
  }

  /// Reset conversation
  ConversationResponse _resetConversation() {
    _currentStep = 'greeting';
    _complaintData.clear();
    _conversationHistory.clear();
    
    return ConversationResponse(
      message: '❌ Cancelled.\n\nStart again anytime!',
      buttons: ['Start New'],
      suggestions: [],
      step: 'greeting',
      showInput: false,
    );
  }

  /// Get complaint data
  Map<String, dynamic> getComplaintData() => Map<String, dynamic>.from(_complaintData);
  
  /// Get stats
  Map<String, dynamic> getConversationStats() {
    return {
      'duration_seconds': DateTime.now().difference(_conversationStartTime).inSeconds,
      'messages_count': _conversationHistory.length,
      'current_step': _currentStep,
      'sentiment': _sentiment,
      'urgency_score': _urgencyScore,
      'retry_count': _retryCount,
    };
  }
  
  /// Reset
  void reset() {
    _currentStep = 'greeting';
    _complaintData.clear();
    _conversationHistory.clear();
    _retryCount = 0;
    _sentiment = 'neutral';
    _urgencyScore = 0.5;
    _aiContext.clear();
    _conversationStartTime = DateTime.now();
  }
  
  /// Set smart mode
  void setSmartMode(bool enabled) {
    _isSmartMode = enabled;
  }
  
  /// Get AI insights
  Map<String, dynamic> getAIInsights() {
    return {
      'sentiment': _sentiment,
      'urgency_score': _urgencyScore,
      'urgency_level': _getUrgencyLevel(),
      'priority': _calculatePriority(),
      'estimated_resolution': _estimateResolutionTime(),
      'ai_context': Map<String, dynamic>.from(_aiContext),
    };
  }
  
  /// Check for duplicate complaints using backend API
  Future<Map<String, dynamic>?> _checkDuplicateComplaint(double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse('http://your-backend-url/api/ai-check-duplicate/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'category': _complaintData['category'],
          'subcategory': _complaintData['subcategory'],
          'description': _complaintData['description'] ?? _complaintData['raw_description'],
        }),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Duplicate check error: $e');
    }
    return null;
  }
  
  /// Get nearest department using backend API
  Future<Map<String, dynamic>?> _getNearestDepartment(double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse('http://your-backend-url/api/ai-get-department/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'category': _complaintData['category'],
          'city': _userCity,
          'state': _complaintData['state'] ?? '',
        }),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Department lookup error: $e');
    }
    return null;
  }
  
  /// Set location coordinates
  void setLocationCoordinates(double latitude, double longitude, {String? city, String? state}) {
    _complaintData['latitude'] = latitude;
    _complaintData['longitude'] = longitude;
    if (city != null) _complaintData['city'] = city;
    if (state != null) _complaintData['state'] = state;
  }
}

/// Enhanced Response model
class ConversationResponse {
  final String message;
  final List<String> buttons;
  final List<String> suggestions;
  final String step;
  final bool showInput;
  final String? inputPlaceholder;
  final Map<String, dynamic>? complaintData;
  final String? urgencyLevel;
  final String? estimatedResolutionTime;
  final Map<String, dynamic>? aiInsights;

  ConversationResponse({
    required this.message,
    required this.buttons,
    required this.suggestions,
    required this.step,
    this.showInput = true,
    this.inputPlaceholder,
    this.complaintData,
    this.urgencyLevel,
    this.estimatedResolutionTime,
    this.aiInsights,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'buttons': buttons,
      'suggestions': suggestions,
      'step': step,
      'showInput': showInput,
      'inputPlaceholder': inputPlaceholder,
      'complaintData': complaintData,
      'urgencyLevel': urgencyLevel,
      'estimatedResolutionTime': estimatedResolutionTime,
      'aiInsights': aiInsights,
    };
  }
}
