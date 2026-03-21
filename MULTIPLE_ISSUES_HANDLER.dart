// Add this method to conversational_ai_service.dart

/// Check if user is mentioning another issue during active complaint
Future<ConversationResponse?> _checkForMultipleIssues(String userInput) async {
  // Only check if we're in the middle of a complaint
  if (_currentStep == 'greeting' || 
      _currentStep == 'submitted' || 
      _currentStep == 'confirm' ||
      !_complaintData.containsKey('category_key') ||
      userInput.length < 15) {
    return null;
  }

  // Use Groq to analyze if this is a new issue
  final multipleIssuesAnalysis = await _contextAnalyzer.detectMultipleIssues(userInput);
  
  if (multipleIssuesAnalysis['success'] != true) {
    return null;
  }

  final data = multipleIssuesAnalysis['data'];
  
  if (data['multiple_issues'] != true) {
    return null;
  }

  final issues = data['issues'] as List;
  final currentCategoryKey = _complaintData['category_key'];
  
  // Check if any detected issue is different from current one
  final newIssues = issues.where((issue) => 
    issue['category'] != currentCategoryKey
  ).toList();
  
  if (newIssues.isEmpty) {
    return null;
  }

  // Store the new issues for later
  if (!_aiContext.containsKey('pending_issues')) {
    _aiContext['pending_issues'] = [];
  }
  
  for (var issue in newIssues) {
    (_aiContext['pending_issues'] as List).add({
      'category': issue['category'],
      'description': issue['description'],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  final newIssuesList = newIssues.map((i) => '• ${i['description']}').join('\n');
  
  return ConversationResponse(
    message: '''👍 **Got it!** I noticed you mentioned another issue:

$newIssuesList

📝 **Current Progress:**
${_complaintData['category_emoji']} **${_complaintData['category']}** - ${_getCurrentStepProgress()}

💡 **Smart Suggestion:**
Let's complete the current complaint first for faster resolution. I've noted your other issue(s) and we can handle them right after!

**Pending Issues:** ${(_aiContext['pending_issues'] as List).length}

🎯 **What would you like to do?**''',
    buttons: [
      '✅ Continue Current Issue',
      '🔄 Switch to New Issue',
      '📋 View All Pending Issues',
    ],
    suggestions: [],
    step: _currentStep,
    showInput: false,
  );
}

/// Get contextual prompt based on current step
String _getContextualPrompt() {
  switch (_currentStep) {
    case 'subcategory':
      return 'What specifically is the issue?';
    case 'problem':
      return 'Please provide more details about the problem.';
    case 'date':
      return 'When did you first notice this?';
    case 'location':
      return 'Where exactly is this issue?';
    case 'photo':
      return 'Would you like to add a photo?';
    case 'personal_details':
      return 'Please confirm your contact details.';
    default:
      return 'Let\'s continue...';
  }
}

/// Get contextual buttons based on current step
List<String> _getContextualButtons() {
  switch (_currentStep) {
    case 'date':
      return ['Today', 'Yesterday', '2-3 days ago', 'Last week'];
    case 'photo':
      return ['📷 Take Photo', '🖼️ Gallery', '⏭️ Skip'];
    case 'personal_details':
      return ['✅ Confirm Details', '✏️ Edit Details'];
    default:
      return [];
  }
}

/// Get contextual suggestions based on current step
List<String> _getContextualSuggestions() {
  final categoryKey = _complaintData['category_key'] as String?;
  
  switch (_currentStep) {
    case 'problem':
      return _getDetailedSuggestions(categoryKey ?? '');
    case 'location':
      return ['Near Main Market', 'Behind Hospital', 'Sector 5'];
    default:
      return [];
  }
}

/// Get current step progress description
String _getCurrentStepProgress() {
  switch (_currentStep) {
    case 'category':
      return 'Selecting category';
    case 'subcategory':
      return 'Describing issue';
    case 'problem':
      return 'Providing details';
    case 'date':
      return 'When noticed';
    case 'location':
      return 'Adding location';
    case 'photo':
      return 'Adding photo';
    case 'personal_details':
      return 'Contact details';
    case 'summary':
      return 'Review & submit';
    default:
      return 'In progress';
  }
}
