// 🚀 Enhanced Conversational AI Service - Usage Examples

import 'package:smartcity_application/services/conversational_ai_service.dart';

/// Example 1: Basic Usage
void basicUsageExample() async {
  final aiService = ConversationalAIService();
  
  // Start conversation
  final response = await aiService.processInput(
    'Hello',
    userName: 'John Doe',
    userCity: 'Mumbai',
    language: 'en',
  );
  
  print(response.message);
  print('Buttons: ${response.buttons}');
  print('Suggestions: ${response.suggestions}');
}

/// Example 2: Quick Complaint Filing
void quickComplaintExample() async {
  final aiService = ConversationalAIService();
  
  // User describes issue directly
  final response1 = await aiService.processInput(
    'There is a dangerous pothole on Main Street near the hospital',
    userName: 'Jane Smith',
    userCity: 'Delhi',
  );
  
  // AI automatically detects:
  // - Category: Road/Pothole
  // - Location: Main Street near hospital
  // - Urgency: High (keyword "dangerous")
  
  print('AI detected category: ${response1.step}');
  print('Urgency: ${response1.urgencyLevel}');
}

/// Example 3: Urgent Issue Handling
void urgentIssueExample() async {
  final aiService = ConversationalAIService();
  
  final response = await aiService.processInput(
    'URGENT! Exposed electrical wire hanging on the road, very dangerous!',
    userName: 'Raj Kumar',
    userCity: 'Bangalore',
  );
  
  // Check AI insights
  final insights = aiService.getAIInsights();
  print('Sentiment: ${insights['sentiment']}'); // urgent
  print('Urgency Score: ${insights['urgency_score']}'); // 0.9
  print('Priority: ${insights['priority']}'); // Critical
}

/// Example 4: Multi-step Conversation
void multiStepConversationExample() async {
  final aiService = ConversationalAIService();
  
  // Step 1: Greeting
  var response = await aiService.processInput(
    'Hi',
    userName: 'Amit Patel',
    userCity: 'Ahmedabad',
  );
  print('Step 1: ${response.message}');
  
  // Step 2: Category selection
  response = await aiService.processInput('Water problem');
  print('Step 2: ${response.message}');
  
  // Step 3: Subcategory
  response = await aiService.processInput('No water supply');
  print('Step 3: ${response.message}');
  
  // Step 4: Description
  response = await aiService.processInput(
    'No water in our area for the last 3 days. Many families affected.',
  );
  print('Step 4: ${response.message}');
  
  // Step 5: Date
  response = await aiService.processInput('Started 3 days ago');
  print('Step 5: ${response.message}');
  
  // Step 6: Location
  response = await aiService.processInput('Sector 5, Block A, near park');
  print('Step 6: ${response.message}');
  
  // Step 7: Photo
  response = await aiService.processInput('Skip photo');
  print('Step 7: ${response.message}');
  
  // Step 8: Confirmation
  response = await aiService.processInput('Submit');
  print('Step 8: ${response.message}');
  
  // Get final complaint data
  final complaintData = aiService.getComplaintData();
  print('Complaint ID: ${complaintData['complaint_id']}');
  print('Department: ${complaintData['department']}');
  print('Priority: ${complaintData['priority']}');
}

/// Example 5: Getting AI Insights
void aiInsightsExample() async {
  final aiService = ConversationalAIService();
  
  await aiService.processInput(
    'The garbage has not been collected for over a week! It smells terrible and rats are everywhere!',
    userName: 'Priya Singh',
    userCity: 'Pune',
  );
  
  // Get comprehensive AI insights
  final insights = aiService.getAIInsights();
  
  print('=== AI Insights ===');
  print('Sentiment: ${insights['sentiment']}'); // negative
  print('Urgency Score: ${insights['urgency_score']}'); // 0.7
  print('Urgency Level: ${insights['urgency_level']}'); // High
  print('Priority: ${insights['priority']}'); // High
  print('Estimated Resolution: ${insights['estimated_resolution']}'); // 1-2 days
  print('AI Context: ${insights['ai_context']}');
}

/// Example 6: Conversation Statistics
void conversationStatsExample() async {
  final aiService = ConversationalAIService();
  
  // Have a conversation
  await aiService.processInput('Hello', userName: 'User', userCity: 'City');
  await aiService.processInput('Road problem');
  await aiService.processInput('Pothole');
  
  // Get statistics
  final stats = aiService.getConversationStats();
  
  print('=== Conversation Stats ===');
  print('Duration: ${stats['duration_seconds']} seconds');
  print('Messages: ${stats['messages_count']}');
  print('Current Step: ${stats['current_step']}');
  print('Sentiment: ${stats['sentiment']}');
  print('Urgency Score: ${stats['urgency_score']}');
  print('Retry Count: ${stats['retry_count']}');
}

/// Example 7: Smart Mode Toggle
void smartModeExample() async {
  final aiService = ConversationalAIService();
  
  // Enable smart mode (default)
  aiService.setSmartMode(true);
  
  var response = await aiService.processInput(
    'Water issue',
    userName: 'User',
    userCity: 'City',
  );
  
  // Smart mode provides AI-enhanced suggestions
  print('Smart suggestions: ${response.suggestions}');
  
  // Disable smart mode for basic experience
  aiService.setSmartMode(false);
  
  response = await aiService.processInput('Water issue');
  
  // Basic mode with standard suggestions
  print('Basic suggestions: ${response.suggestions}');
}

/// Example 8: Error Handling
void errorHandlingExample() async {
  final aiService = ConversationalAIService();
  
  try {
    // User provides unclear input
    var response = await aiService.processInput(
      'xyz',
      userName: 'User',
      userCity: 'City',
    );
    
    // AI provides helpful guidance
    print(response.message); // "I didn't quite catch that..."
    print('Helpful buttons: ${response.buttons}');
    
    // User tries again with unclear input
    response = await aiService.processInput('abc');
    
    // After retries, AI shows all categories
    print('Retry count: ${aiService.getConversationStats()['retry_count']}');
    
  } catch (e) {
    print('Error: $e');
  }
}

/// Example 9: Reset Conversation
void resetExample() async {
  final aiService = ConversationalAIService();
  
  // Start conversation
  await aiService.processInput('Hello', userName: 'User', userCity: 'City');
  await aiService.processInput('Road problem');
  
  print('Before reset: ${aiService.getConversationStats()['messages_count']}');
  
  // Reset conversation
  aiService.reset();
  
  print('After reset: ${aiService.getConversationStats()['messages_count']}');
  
  // Start fresh
  final response = await aiService.processInput('Hi');
  print('Fresh start: ${response.message}');
}

/// Example 10: Complete Complaint Flow with All Features
void completeFlowExample() async {
  final aiService = ConversationalAIService();
  
  print('=== Starting Complete Complaint Flow ===\n');
  
  // Step 1: Natural language complaint
  var response = await aiService.processInput(
    'There is a huge pothole on MG Road near City Mall. It has been there for 2 weeks and causing accidents!',
    userName: 'Rahul Sharma',
    userCity: 'Hyderabad',
    language: 'en',
  );
  
  print('AI Response: ${response.message}');
  print('Detected Step: ${response.step}');
  print('Urgency: ${response.urgencyLevel}\n');
  
  // AI automatically extracted:
  // - Category: Road
  // - Subcategory: Pothole
  // - Location: MG Road near City Mall
  // - Duration: 2 weeks
  // - Urgency: High
  
  // Continue with remaining steps
  if (response.step == 'problem') {
    response = await aiService.processInput(
      'The pothole is about 2 feet deep and 4 feet wide. Water accumulates and vehicles get damaged.',
    );
    print('Description added: ${response.step}\n');
  }
  
  if (response.step == 'date') {
    response = await aiService.processInput('2 weeks ago');
    print('Date confirmed: ${response.step}\n');
  }
  
  if (response.step == 'location') {
    response = await aiService.processInput('Yes, MG Road near City Mall');
    print('Location confirmed: ${response.step}\n');
  }
  
  if (response.step == 'photo') {
    response = await aiService.processInput('Take Photo Now');
    print('Photo option selected: ${response.step}\n');
  }
  
  if (response.step == 'confirm') {
    print('=== Final Summary ===');
    print(response.message);
    print('\nEstimated Resolution: ${response.estimatedResolutionTime}');
    
    response = await aiService.processInput('Submit Complaint');
  }
  
  if (response.step == 'submitted') {
    print('\n=== Complaint Submitted ===');
    final complaintData = response.complaintData;
    print('Complaint ID: ${complaintData?['complaint_id']}');
    print('Department: ${complaintData?['department']}');
    print('Priority: ${complaintData?['priority']}');
    print('Tracking URL: ${complaintData?['tracking_url']}');
  }
  
  // Get final insights
  print('\n=== AI Insights ===');
  final insights = aiService.getAIInsights();
  print('Sentiment: ${insights['sentiment']}');
  print('Urgency Score: ${insights['urgency_score']}');
  print('Priority: ${insights['priority']}');
  
  // Get conversation stats
  print('\n=== Conversation Stats ===');
  final stats = aiService.getConversationStats();
  print('Duration: ${stats['duration_seconds']} seconds');
  print('Total Messages: ${stats['messages_count']}');
}

/// Example 11: Testing Different Categories
void categoryTestingExample() async {
  final aiService = ConversationalAIService();
  
  final testCases = [
    'Water pipe burst on my street',
    'Power cut for 6 hours daily',
    'Garbage not collected for a week',
    'Drain blocked and overflowing',
    'Traffic signal not working',
    'Theft in my neighborhood',
    'Illegal construction next door',
    'UPI fraud, lost 50000 rupees',
    'Street light not working',
    'Public toilet is very dirty',
  ];
  
  for (var testCase in testCases) {
    aiService.reset();
    
    final response = await aiService.processInput(
      testCase,
      userName: 'Test User',
      userCity: 'Test City',
    );
    
    final data = aiService.getComplaintData();
    print('Input: $testCase');
    print('Detected Category: ${data['category']}');
    print('Urgency: ${aiService.getAIInsights()['urgency_level']}');
    print('---');
  }
}

/// Main function to run examples
void main() async {
  print('🚀 Enhanced Conversational AI Service - Examples\n');
  
  // Run examples
  print('Example 1: Basic Usage');
  await basicUsageExample();
  print('\n---\n');
  
  print('Example 2: Quick Complaint');
  await quickComplaintExample();
  print('\n---\n');
  
  print('Example 3: Urgent Issue');
  await urgentIssueExample();
  print('\n---\n');
  
  print('Example 5: AI Insights');
  await aiInsightsExample();
  print('\n---\n');
  
  print('Example 6: Conversation Stats');
  await conversationStatsExample();
  print('\n---\n');
  
  // Run complete flow
  print('\n=== COMPLETE FLOW EXAMPLE ===\n');
  await completeFlowExample();
}
