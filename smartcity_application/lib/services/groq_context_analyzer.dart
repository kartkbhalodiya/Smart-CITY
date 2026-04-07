import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GroqContextAnalyzer {
  static const String _apiKey = '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';
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-70b-versatile';

  /// Analyze full conversation context to understand user intent
  Future<Map<String, dynamic>> analyzeConversationContext({
    required String currentInput,
    required List<Map<String, String>> conversationHistory,
    required String currentStep,
    Map<String, dynamic>? complaintData,
  }) async {
    try {
      // Build conversation context
      final contextMessages = conversationHistory.map((msg) {
        return '${msg['role'] == 'user' ? 'User' : 'Assistant'}: ${msg['content']}';
      }).join('\n');

      final prompt = '''You are an intelligent assistant analyzing a complaint conversation.

**Conversation History:**
$contextMessages

**Current User Input:** "$currentInput"
**Current Step:** $currentStep
**Complaint Data So Far:** ${complaintData != null ? jsonEncode(complaintData) : 'None'}

**Your Task:**
Analyze the FULL conversation context and current input to understand:

1. **Primary Intent:** What is the user trying to do?
   - Report a new issue
   - Add details to current issue
   - Report another issue
   - Ask a question
   - Provide requested information

2. **Category Detection:** If reporting an issue, what category?
   - road, water, electricity, garbage, drainage, traffic, police, construction, cyber, street_light, public_toilet, other

3. **Context Understanding:**
   - Is user answering a question?
   - Is user providing additional details?
   - Is user changing topic?
   - Is user confused?

4. **Smart Suggestions:** What should we ask next?

**Important:**
- Consider the ENTIRE conversation, not just current input
- Detect if user says "I noticed another issue" or similar
- Understand multilingual input (English, Hindi, Gujarati)
- Be context-aware

**Response Format (JSON only):**
{
  "intent": "report_new|add_details|another_issue|question|answer",
  "category": "category_key or null",
  "subcategory": "detected subcategory or null",
  "confidence": 0.0-1.0,
  "reasoning": "brief explanation",
  "suggested_response": "what to say to user",
  "next_question": "what to ask next",
  "detected_language": "english|hindi|gujarati|mixed",
  "urgency": "low|medium|high|critical",
  "context_summary": "brief summary of conversation so far"
}

Return ONLY valid JSON, no other text.''';

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert conversation analyzer. Always respond with valid JSON only.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.3,
          'max_tokens': 800,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Extract JSON from response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final result = jsonDecode(jsonStr);
          
          debugPrint('Groq Context Analysis: ${result['reasoning']}');
          
          return {
            'success': true,
            'analysis': result,
          };
        }
        
        return {
          'success': false,
          'error': 'Could not parse AI response',
        };
      } else {
        debugPrint('Groq API error: ${response.statusCode}');
        return {
          'success': false,
          'error': 'AI service unavailable',
        };
      }
    } catch (e) {
      debugPrint('Groq context analysis error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Detect if user is mentioning another issue while current one is incomplete
  Future<Map<String, dynamic>> detectMultipleIssues(String input) async {
    try {
      final prompt = '''Analyze this user input to detect if they're mentioning multiple different issues:

User input: "$input"

Detect if user mentions:
- Multiple different problems (e.g., "road is broken AND water is not coming")
- Switching topics (e.g., talking about pothole then suddenly mentions theft)
- Adding another issue (e.g., "also there is garbage problem")

Available categories:
- road, water, electricity, garbage, drainage, traffic, police, construction, cyber, street_light, public_toilet, other

Response format (JSON only):
{
  "multiple_issues": true/false,
  "issues": [
    {"category": "category_key", "description": "brief description"},
    ...
  ],
  "primary_issue": "which issue seems most urgent",
  "confidence": 0.0-1.0
}

Return ONLY valid JSON.''';

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert at detecting multiple issues in user input. Respond with JSON only.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.2,
          'max_tokens': 400,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final result = jsonDecode(jsonStr);
          return {
            'success': true,
            'data': result,
          };
        }
      }
      
      return {'success': false};
    } catch (e) {
      debugPrint('Multiple issues detection error: $e');
      return {'success': false};
    }
  }

  /// Generate smart follow-up question based on context
  Future<String> generateSmartFollowUp({
    required String currentStep,
    required Map<String, dynamic> complaintData,
    required List<Map<String, String>> conversationHistory,
  }) async {
    try {
      // Get last 5 messages
      final recentHistory = conversationHistory.length > 5
          ? conversationHistory.sublist(conversationHistory.length - 5)
          : conversationHistory;
      
      final contextMessages = recentHistory.map((msg) {
        return '${msg['role'] == 'user' ? 'User' : 'Assistant'}: ${msg['content']}';
      }).join('\n');

      final prompt = '''Based on this conversation, generate a smart follow-up question:

**Recent Conversation:**
$contextMessages

**Current Step:** $currentStep
**Complaint Data:** ${jsonEncode(complaintData)}

Generate a natural, helpful follow-up question that:
1. Continues the conversation smoothly
2. Gathers necessary information
3. Shows empathy and understanding
4. Is concise (2-3 sentences max)

Return ONLY the question text, no JSON or extra formatting.''';

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful assistant. Generate natural follow-up questions.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 150,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      }
      
      return 'Could you provide more details?';
    } catch (e) {
      debugPrint('Smart follow-up generation error: $e');
      return 'Could you provide more details?';
    }
  }
}
