// 🚀 Enhanced Conversational AI Service - Usage Examples

import 'package:smartcity_application/services/conversational_ai_service.dart';
import 'package:flutter/foundation.dart';

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
  
  debugPrint(response.message);
  debugPrint('Buttons: ${response.buttons}');
  debugPrint('Suggestions: ${response.suggestions}');
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
  
  debugPrint('AI detected category: ${response1.step}');
  debugPrint('Urgency: ${response1.urgencyLevel}');
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
  debugPrint('Sentiment: ${insights['sentiment']}'); // urgent
  debugPrint('Urgency Score: ${insights['urgency_score']}'); // 0.9
  debugPrint('Priority: ${insights['priority']}'); // Critical
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
  debugPrint('Step 1: ${response.message}');
  
  // Step 2: Category selection
  response = await aiService.processInput('Water problem');
  debugPrint('Step 2: ${response.message}');
  
  // Step 3: Subcategory
  response = await aiService.processInput('No water supply');
  debugPrint('Step 3: ${response.message}');
  
  // Step 4: Description
  response = await aiService.processInput(
    'No water in our area for the last 3 days. Many families affected.',
  );
  debugPrint('Step 4: ${response.message}');
  
  // Step 5: Date
  response = await aiService.processInput('Started 3 days ago');
  debugPrint('Step 5: ${response.message}');
  
  // Step 6: Location
  response = await aiService.processInput('Sector 5, Block A, near park');
  debugPrint('Step 6: ${response.message}');
  
  // Step 7: Photo
  response = await aiService.processInput('Skip photo');
  debugPrint('Step 7: ${response.message}');
  
  // Step 8: Confirmation
  response = await aiService.processInput('Submit');
  debugPrint('Step 8: ${response.message}');
  
  // Get final complaint data
  final complaintData = aiService.getComplaintData();
  debugPrint('Complaint ID: ${complaintData['complaint_id']}');
  debugPrint('Department: ${complaintData['department']}');
  debugPrint('Priority: ${complaintData['priority']}');
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
  
  debugPrint('=== AI Insights ===');
  debugPrint('Sentiment: ${insights['sentiment']}'); // negative
  debugPrint('Urgency Score: ${insights['urgency_score']}'); // 0.7
  debugPrint('Urgency Level: ${insights['urgency_level']}'); // High
  debugPrint('Priority: ${insights['priority']}'); // High
  debugPrint('Estimated Resolution: ${insights['estimated_resolution']}'); // 1-2 days
  debugPrint('AI Context: ${insights['ai_context']}');
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
  
  debugPrint('=== Conversation Stats ===');
  debugPrint('Duration: ${stats['duration_seconds']} seconds');
  debugPrint('Messages: ${stats['messages_count']}');
  debugPrint('Current Step: ${stats['current_step']}');
  debugPrint('Sentiment: ${stats['sentiment']}');
  debugPrint('Urgency Score: ${stats['urgency_score']}');
  debugPrint('Retry Count: ${stats['retry_count']}');
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
  debugPrint('Smart suggestions: ${response.suggestions}');
  
  // Disable smart mode for basic experience
  aiService.setSmartMode(false);
  
  response = await aiService.processInput('Water issue');
  
  // Basic mode with standard suggestions
  debugPrint('Basic suggestions: ${response.suggestions}');
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
    debugPrint(response.message); // "I didn't quite catch that..."
    debugPrint('Helpful buttons: ${response.buttons}');
    
    // User tries again with unclear input
    response = await aiService.processInput('abc');
    
    // After retries, AI shows all categories
    debugPrint('Retry count: ${aiService.getConversationStats()['retry_count']}');
    
  } catch (e) {
    debugPrint('Error: $e');
  }
}

/// Example 9: Reset Conversation
void resetExample() async {
  final aiService = ConversationalAIService();
  
  // Start conversation
  await aiService.processInput('Hello', userName: 'User', userCity: 'City');
  await aiService.processInput('Road problem');
  
  debugPrint('Before reset: ${aiService.getConversationStats()['messages_count']}');
  
  // Reset conversation
  aiService.reset();
  
  debugPrint('After reset: ${aiService.getConversationStats()['messages_count']}');
  
  // Start fresh
  final response = await aiService.processInput('Hi');
  debugPrint('Fresh start: ${response.message}');
}

/// Example 10: Complete Complaint Flow with All Features
void completeFlowExample() async {
  final aiService = ConversationalAIService();
  
  debugPrint('=== Starting Complete Complaint Flow ===\n');
  
  // Step 1: Natural language complaint
  var response = await aiService.processInput(
    'There is a huge pothole on MG Road near City Mall. It has been there for 2 weeks and causing accidents!',
    userName: 'Rahul Sharma',
    userCity: 'Hyderabad',
    language: 'en',
  );
  
  debugPrint('AI Response: ${response.message}');
  debugPrint('Detected Step: ${response.step}');
  debugPrint('Urgency: ${response.urgencyLevel}\n');
  
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
    debugPrint('Description added: ${response.step}\n');
  }
  
  if (response.step == 'date') {
    response = await aiService.processInput('2 weeks ago');
    debugPrint('Date confirmed: ${response.step}\n');
  }
  
  if (response.step == 'location') {
    response = await aiService.processInput('Yes, MG Road near City Mall');
    debugPrint('Location confirmed: ${response.step}\n');
  }
  
  if (response.step == 'photo') {
    response = await aiService.processInput('Take Photo Now');
    debugPrint('Photo option selected: ${response.step}\n');
  }
  
  if (response.step == 'confirm') {
    debugPrint('=== Final Summary ===');
    debugPrint(response.message);
    debugPrint('\nEstimated Resolution: ${response.estimatedResolutionTime}');
    
    response = await aiService.processInput('Submit Complaint');
  }
  
  if (response.step == 'submitted') {
    debugPrint('\n=== Complaint Submitted ===');
    final complaintData = response.complaintData;
    debugPrint('Complaint ID: ${complaintData?['complaint_id']}');
    debugPrint('Department: ${complaintData?['department']}');
    debugPrint('Priority: ${complaintData?['priority']}');
    debugPrint('Tracking URL: ${complaintData?['tracking_url']}');
  }
  
  // Get final insights
  debugPrint('\n=== AI Insights ===');
  final insights = aiService.getAIInsights();
  debugPrint('Sentiment: ${insights['sentiment']}');
  debugPrint('Urgency Score: ${insights['urgency_score']}');
  debugPrint('Priority: ${insights['priority']}');
  
  // Get conversation stats
  debugPrint('\n=== Conversation Stats ===');
  final stats = aiService.getConversationStats();
  debugPrint('Duration: ${stats['duration_seconds']} seconds');
  debugPrint('Total Messages: ${stats['messages_count']}');
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
    debugPrint('Input: $testCase');
    debugPrint('Detected Category: ${data['category']}');
    debugPrint('Urgency: ${aiService.getAIInsights()['urgency_level']}');
    debugPrint('---');
  }
}

/// Main function to run examples
void main() async {
  debugPrint('🚀 Enhanced Conversational AI Service - Examples\n');
  
  // Run examples
  debugPrint('Example 1: Basic Usage');
  await basicUsageExample();
  debugPrint('\n---\n');
  
  debugPrint('Example 2: Quick Complaint');
  await quickComplaintExample();
  debugPrint('\n---\n');
  
  debugPrint('Example 3: Urgent Issue');
  await urgentIssueExample();
  debugPrint('\n---\n');
  
  debugPrint('Example 5: AI Insights');
  await aiInsightsExample();
  debugPrint('\n---\n');
  
  debugPrint('Example 6: Conversation Stats');
  await conversationStatsExample();
  debugPrint('\n---\n');
  
  // Run complete flow
  debugPrint('\n=== COMPLETE FLOW EXAMPLE ===\n');
  await completeFlowExample();
}
