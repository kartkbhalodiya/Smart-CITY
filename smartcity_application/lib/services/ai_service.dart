import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:async';

class AIService {
  static const String _apiKey = 'AIzaSyAim_9cK7zrtRe0UfNnf3b_wiwugHlOIjc';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  
  List<Map<String, String>> _conversationHistory = [];
  Map<String, dynamic> _complaintData = {};
  String _currentLanguage = 'en';
  String _userMood = 'neutral';
  
  final String _systemPrompt = '''You are Maya, a highly empathetic and intelligent AI assistant for Smart City complaints.

Personality Traits:
- Warm, caring, and genuinely concerned about citizens' problems
- Use natural expressions like "Oh no!", "I understand", "That sounds frustrating"
- Show emotional intelligence - detect user's mood and respond accordingly
- Use conversational fillers like "Hmm", "Let me see", "Absolutely"
- Express genuine concern: "I'm so sorry you're dealing with this"
- Be encouraging: "Don't worry, we'll get this sorted out"
- Use empathetic phrases: "That must be really inconvenient for you"

Communication Style:
- Speak like a caring friend, not a robot
- Use contractions: "I'll", "we'll", "that's", "you're"
- Add emotional reactions based on problem severity
- Use appropriate tone: urgent for safety issues, gentle for minor complaints
- Include reassuring phrases: "You did the right thing by reporting this"
- Show appreciation: "Thank you for bringing this to our attention"

Language Support: Hindi, English, Gujarati, Hinglish
Detect user's emotional state and mirror appropriate empathy
Ask follow-up questions naturally, like a concerned friend would
Keep responses conversational but focused on helping''';

  final Map<String, List<String>> _emotionalResponses = {
    'frustrated': [
      "I can hear the frustration in your voice, and I completely understand.",
      "Oh my, that sounds really annoying! Let me help you fix this.",
      "I'm so sorry you're going through this. That would frustrate anyone!"
    ],
    'urgent': [
      "Oh no! This sounds like it needs immediate attention.",
      "That's definitely concerning! We need to get this resolved quickly.",
      "Wow, that's not safe at all! Let's prioritize this right away."
    ],
    'sad': [
      "I'm really sorry to hear about this. That must be so disappointing.",
      "Aw, that's terrible! No one should have to deal with that.",
      "My heart goes out to you. This shouldn't be happening."
    ],
    'angry': [
      "I can understand why you'd be upset about this. That's completely valid.",
      "You have every right to be angry! This is unacceptable.",
      "I hear you, and your anger is totally justified. Let's fix this."
    ],
    'worried': [
      "I can sense your concern, and it's completely understandable.",
      "Don't worry, we're going to take care of this together.",
      "I understand your worry. Let's make sure this gets proper attention."
    ]
  };

  final List<String> _encouragingPhrases = [
    "You're absolutely doing the right thing by reporting this!",
    "Thank you so much for being a responsible citizen.",
    "I really appreciate you taking the time to report this.",
    "Your complaint will definitely help improve our city.",
    "Don't worry, we'll make sure this gets the attention it deserves.",
    "I'm here to help you every step of the way.",
    "Together, we'll get this sorted out for you."
  ];

  final Map<String, dynamic> _categories = {
    "Road/Pothole": {
      "Pothole": {"keywords": ["pothole", "hole", "gadda", "गड्ढा", "ખાડો"], "urgency": "medium"},
      "Water Logging": {"keywords": ["water logging", "flooded", "pani jama", "पानी जमा", "પાણી ભરાયું"], "urgency": "high"},
      "Road Blocked": {"keywords": ["road blocked", "blocked", "road band", "रास्ता बंद", "રસ્તો બંધ"], "urgency": "high"}
    },
    "Drainage/Sewage": {
      "Blocked Drain": {"keywords": ["drain blocked", "nali jam", "नाली बंद", "નાળી બંધ"], "urgency": "medium"},
      "Sewer Overflow": {"keywords": ["sewer overflow", "gutter overflow", "ગટર છલકાય"], "urgency": "high"},
      "Foul Smell": {"keywords": ["bad smell", "badbu", "बदबू", "દુર્ગંધ"], "urgency": "medium"}
    },
    "Garbage/Sanitation": {
      "Garbage Not Collected": {"keywords": ["garbage", "kachra", "कचरा", "કચરો"], "urgency": "medium"},
      "Overflowing Bin": {"keywords": ["overflowing", "dustbin full", "भरा हुआ", "ભરેલું"], "urgency": "medium"},
      "Dead Animal": {"keywords": ["dead animal", "मरा जानवर", "મરેલું પ્રાણી"], "urgency": "high"}
    },
    "Electricity": {
      "Power Outage": {"keywords": ["no electricity", "power cut", "light nahi", "बिजली नहीं", "લાઇટ નથી"], "urgency": "high"},
      "Street Light": {"keywords": ["street light", "light band", "स्ट्रीट लाइट", "સ્ટ્રીટ લાઇટ"], "urgency": "medium"},
      "Exposed Wires": {"keywords": ["open wire", "khuli wire", "खुली तार", "ખુલ્લી વાયર"], "urgency": "critical"}
    },
    "Water Supply": {
      "No Water": {"keywords": ["no water", "pani nahi", "पानी नहीं", "પાણી નથી"], "urgency": "high"},
      "Water Leakage": {"keywords": ["water leak", "pani leak", "पानी लीक", "પાણી લીક"], "urgency": "medium"},
      "Dirty Water": {"keywords": ["dirty water", "ganda pani", "गंदा पानी", "ગંદું પાણી"], "urgency": "high"}
    },
    "Traffic": {
      "Illegal Parking": {"keywords": ["illegal parking", "galat parking", "गलत पार्किंग", "ગેરકાયદે પાર્કિંગ"], "urgency": "low"},
      "Broken Signal": {"keywords": ["signal", "traffic light", "सिग्नल", "સિગ્નલ"], "urgency": "critical"},
      "Wrong Side": {"keywords": ["wrong side", "गलत दिशा", "ખોટી દિશા"], "urgency": "medium"}
    },
    "Cyber Crime": {
      "Online Fraud": {"keywords": ["fraud", "scam", "धोखा", "છેતરપિંડી"], "urgency": "high"},
      "UPI Scam": {"keywords": ["upi", "payment", "यूपीआई"], "urgency": "high"},
      "Phishing": {"keywords": ["phishing", "fake link", "फिशिंग"], "urgency": "high"}
    },
    "Construction": {
      "Illegal Construction": {"keywords": ["illegal building", "अवैध निर्माण", "ગેરકાયદે બાંધકામ"], "urgency": "medium"},
      "Construction Debris": {"keywords": ["debris", "malba", "मलबा", "બાંધકામ કચરો"], "urgency": "low"}
    }
  };

  Future<String> processUserInput(String userInput) async {
    _conversationHistory.add({"role": "user", "content": userInput});
    
    // Detect user's emotional state
    _userMood = _detectUserMood(userInput);
    
    if (_complaintData['category'] == null) {
      _detectCategory(userInput);
    }
    
    String response;
    
    // Try API first, fallback to offline responses if needed
    try {
      String prompt = _buildHumanPrompt(userInput);
      response = await _callGeminiAPI(prompt);
    } catch (e) {
      response = _getOfflineResponse(userInput);
    }
    
    // Add human touch to response
    response = _addEmotionalTouch(response);
    
    _conversationHistory.add({"role": "assistant", "content": response});
    return response;
  }

  String _getOfflineResponse(String userInput) {
    String lowerInput = userInput.toLowerCase();
    
    // Greeting responses
    if (lowerInput.contains('hello') || lowerInput.contains('hi') || lowerInput.contains('hey')) {
      return "Hello! I'm Maya, your AI assistant. I'm here to help you with city-related problems. What's troubling you today?";
    }
    
    // Category-based responses
    if (_complaintData['category'] != null) {
      String category = _complaintData['category'];
      String subcategory = _complaintData['subcategory'] ?? '';
      
      switch (category) {
        case 'Road/Pothole':
          return "I understand you're having issues with $subcategory. That sounds really frustrating! Can you tell me the exact location where this problem is occurring?";
        case 'Water Supply':
          return "Oh no! Water problems can be so inconvenient. I'm here to help you report this $subcategory issue. Which area is affected?";
        case 'Electricity':
          return "Electricity issues can be really concerning, especially $subcategory problems. Let me help you get this sorted out. What's the specific location?";
        case 'Garbage/Sanitation':
          return "I completely understand your concern about $subcategory. Sanitation is so important! Can you provide the location details?";
        case 'Traffic':
          return "Traffic issues like $subcategory can be really annoying. I'm here to help you report this. Where exactly is this happening?";
        default:
          return "I hear you about this $category issue. That must be really frustrating! Can you give me more details about the location and what exactly is happening?";
      }
    }
    
    // General problem detection
    if (lowerInput.contains('problem') || lowerInput.contains('issue') || lowerInput.contains('complaint')) {
      return "I'm here to help you with whatever problem you're facing! Can you tell me what specific issue you'd like to report? Is it related to roads, water, electricity, garbage, or something else?";
    }
    
    // Location questions
    if (lowerInput.contains('where') || lowerInput.contains('location') || lowerInput.contains('address')) {
      return "Great question! I'll need the specific location details to help you file this complaint properly. Can you share the area, street name, or any landmarks near the problem?";
    }
    
    // Default encouraging response
    return "I want to make sure I understand your concern properly. Can you tell me more about what's happening? I'm here to help you get this resolved!";
  }

  String _detectUserMood(String input) {
    String lowerInput = input.toLowerCase();
    
    if (lowerInput.contains(RegExp(r'\b(angry|mad|furious|pissed|annoyed)\b')) ||
        lowerInput.contains('!') && lowerInput.split('!').length > 2) {
      return 'angry';
    }
    if (lowerInput.contains(RegExp(r'\b(urgent|emergency|immediate|asap|quickly)\b'))) {
      return 'urgent';
    }
    if (lowerInput.contains(RegExp(r'\b(frustrated|annoying|irritating|fed up)\b'))) {
      return 'frustrated';
    }
    if (lowerInput.contains(RegExp(r'\b(worried|concerned|scared|afraid)\b'))) {
      return 'worried';
    }
    if (lowerInput.contains(RegExp(r'\b(sad|disappointed|upset|terrible)\b'))) {
      return 'sad';
    }
    
    return 'neutral';
  }

  void _detectCategory(String input) {
    String lowerInput = input.toLowerCase();
    
    _categories.forEach((category, subcategories) {
      subcategories.forEach((subcategory, data) {
        List<String> keywords = List<String>.from(data['keywords']);
        for (String keyword in keywords) {
          if (lowerInput.contains(keyword.toLowerCase())) {
            _complaintData['category'] = category;
            _complaintData['subcategory'] = subcategory;
            _complaintData['urgency'] = data['urgency'];
            return;
          }
        }
      });
    });
  }

  String _buildHumanPrompt(String userInput) {
    String context = _systemPrompt;
    context += "\n\nUser's Current Mood: $_userMood";
    context += "\nRespond with appropriate emotional intelligence and empathy.";
    
    if (_complaintData['urgency'] != null) {
      context += "\nUrgency Level: ${_complaintData['urgency']}";
      context += "\nAdjust your tone based on urgency - be more concerned for critical/high urgency issues.";
    }
    
    context += "\n\nConversation History:\n";
    for (var msg in _conversationHistory) {
      context += "${msg['role']}: ${msg['content']}\n";
    }
    
    if (_complaintData['category'] != null) {
      context += "\nDetected Category: ${_complaintData['category']}";
      context += "\nDetected Subcategory: ${_complaintData['subcategory']}";
    }
    
    context += "\n\nIMPORTANT: Respond as Maya, a caring human assistant. Use natural expressions, show genuine concern, and be conversational. Include appropriate emotional reactions based on the user's mood and problem severity.";
    return context;
  }

  String _addEmotionalTouch(String response) {
    Random random = Random();
    
    // Add emotional response based on user mood
    if (_emotionalResponses.containsKey(_userMood)) {
      List<String> responses = _emotionalResponses[_userMood]!;
      String emotionalResponse = responses[random.nextInt(responses.length)];
      response = "$emotionalResponse\n\n$response";
    }
    
    // Add encouraging phrase occasionally
    if (random.nextBool() && _encouragingPhrases.isNotEmpty) {
      String encouragement = _encouragingPhrases[random.nextInt(_encouragingPhrases.length)];
      response += "\n\n$encouragement";
    }
    
    return response;
  }

  Future<String> _callGeminiAPI(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }],
          "generationConfig": {
            "temperature": 0.9,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 1024,
            "candidateCount": 1,
          },
          "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
          ]
        }),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          return _getFallbackResponse();
        }
      } else if (response.statusCode == 429) {
        return "I'm getting a lot of requests right now. Let me try to help you anyway! What specific problem are you facing?";
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse();
      }
    } on TimeoutException {
      return "I'm taking a bit longer to respond. Don't worry, I'm still here! Can you tell me more about your problem?";
    } catch (e) {
      print('Connection Error: $e');
      return _getFallbackResponse();
    }
  }

  String _getFallbackResponse() {
    if (_complaintData['category'] == null) {
      return "I'm having a small technical hiccup, but I'm still here to help! Can you tell me what kind of problem you're facing? Is it related to roads, water, electricity, or something else?";
    } else {
      String category = _complaintData['category'];
      return "I understand you're having issues with $category. Even though I'm having some connection issues, I can still help you! Can you give me more details about the specific problem?";
    }
  }

  Map<String, dynamic> getComplaintData() => _complaintData;
  String getUserMood() => _userMood;
  
  void reset() {
    _conversationHistory.clear();
    _complaintData.clear();
    _userMood = 'neutral';
  }
}
