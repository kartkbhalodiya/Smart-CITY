import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = 'AIzaSyAim_9cK7zrtRe0UfNnf3b_wiwugHlOIjc';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  static const String _audioUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:streamGenerateContent';
  
  List<Map<String, String>> _conversationHistory = [];
  Map<String, dynamic> _complaintData = {};
  String _currentLanguage = 'en';
  
  final String _systemPrompt = '''You are an AI-powered Smart City Complaint Assistant.
Support multiple languages: Hindi, English, Gujarati, Hinglish.
Detect user intent and map to correct Category/Subcategory.
Ask only relevant follow-up questions.
Keep conversation simple, friendly, and short.
Guide user step-by-step until complaint submission.''';

  final Map<String, dynamic> _categories = {
    "Road/Pothole": {
      "Pothole": {"keywords": ["pothole", "hole", "gadda", "गड्ढा", "ખાડો"]},
      "Water Logging": {"keywords": ["water logging", "flooded", "pani jama", "पानी जमा", "પાણી ભરાયું"]},
      "Road Blocked": {"keywords": ["road blocked", "blocked", "road band", "रास्ता बंद", "રસ્તો બંધ"]}
    },
    "Drainage/Sewage": {
      "Blocked Drain": {"keywords": ["drain blocked", "nali jam", "नाली बंद", "નાળી બંધ"]},
      "Sewer Overflow": {"keywords": ["sewer overflow", "gutter overflow", "ગટર છલકાય"]},
      "Foul Smell": {"keywords": ["bad smell", "badbu", "बदबू", "દુર્ગંધ"]}
    },
    "Garbage/Sanitation": {
      "Garbage Not Collected": {"keywords": ["garbage", "kachra", "कचरा", "કચરો"]},
      "Overflowing Bin": {"keywords": ["overflowing", "dustbin full", "भरा हुआ", "ભરેલું"]},
      "Dead Animal": {"keywords": ["dead animal", "मरा जानवर", "મરેલું પ્રાણી"]}
    },
    "Electricity": {
      "Power Outage": {"keywords": ["no electricity", "power cut", "light nahi", "बिजली नहीं", "લાઇટ નથી"]},
      "Street Light": {"keywords": ["street light", "light band", "स्ट्रीट लाइट", "સ્ટ્રીટ લાઇટ"]},
      "Exposed Wires": {"keywords": ["open wire", "khuli wire", "खुली तार", "ખુલ્લી વાયર"]}
    },
    "Water Supply": {
      "No Water": {"keywords": ["no water", "pani nahi", "पानी नहीं", "પાણી નથી"]},
      "Water Leakage": {"keywords": ["water leak", "pani leak", "पानी लीक", "પાણી લીક"]},
      "Dirty Water": {"keywords": ["dirty water", "ganda pani", "गंदा पानी", "ગંદું પાણી"]}
    },
    "Traffic": {
      "Illegal Parking": {"keywords": ["illegal parking", "galat parking", "गलत पार्किंग", "ગેરકાયદે પાર્કિંગ"]},
      "Broken Signal": {"keywords": ["signal", "traffic light", "सिग्नल", "સિગ્નલ"]},
      "Wrong Side": {"keywords": ["wrong side", "गलत दिशा", "ખોટી દિશા"]}
    },
    "Cyber Crime": {
      "Online Fraud": {"keywords": ["fraud", "scam", "धोखा", "છેતરપિંડી"]},
      "UPI Scam": {"keywords": ["upi", "payment", "यूपीआई"]},
      "Phishing": {"keywords": ["phishing", "fake link", "फिशिंग"]}
    },
    "Construction": {
      "Illegal Construction": {"keywords": ["illegal building", "अवैध निर्माण", "ગેરકાયદે બાંધકામ"]},
      "Construction Debris": {"keywords": ["debris", "malba", "मलबा", "બાંધકામ કચરો"]}
    }
  };

  Future<String> processUserInput(String userInput) async {
    _conversationHistory.add({"role": "user", "content": userInput});
    
    if (_complaintData['category'] == null) {
      _detectCategory(userInput);
    }
    
    String prompt = _buildPrompt(userInput);
    String response = await _callGeminiAPI(prompt);
    
    _conversationHistory.add({"role": "assistant", "content": response});
    return response;
  }

  Future<String> processAudioInput(Uint8List audioBytes) async {
    try {
      final response = await http.post(
        Uri.parse('$_audioUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [
              {"text": _systemPrompt},
              {"inline_data": {
                "mime_type": "audio/wav",
                "data": base64Encode(audioBytes)
              }}
            ]
          }],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['candidates'][0]['content']['parts'][0]['text'];
        _conversationHistory.add({"role": "user", "content": "[Audio input]"});
        _conversationHistory.add({"role": "assistant", "content": text});
        _detectCategory(text);
        return text;
      }
      return "I couldn't understand that. Please try again.";
    } catch (e) {
      return "Sorry, audio processing failed. Please try again.";
    }
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
            return;
          }
        }
      });
    });
  }

  String _buildPrompt(String userInput) {
    String context = _systemPrompt;
    context += "\n\nConversation History:\n";
    for (var msg in _conversationHistory) {
      context += "${msg['role']}: ${msg['content']}\n";
    }
    
    if (_complaintData['category'] != null) {
      context += "\nDetected Category: ${_complaintData['category']}";
      context += "\nDetected Subcategory: ${_complaintData['subcategory']}";
    }
    
    context += "\n\nRespond in a friendly, conversational way. Ask one relevant question at a time.";
    return context;
  }

  Future<String> _callGeminiAPI(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }],
          "generationConfig": {
            "temperature": 0.8,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          },
          "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return "I'm having trouble connecting. Can you repeat that?";
      }
    } catch (e) {
      return "Sorry, I couldn't process that. Please try again.";
    }
  }

  Map<String, dynamic> getComplaintData() => _complaintData;
  
  void reset() {
    _conversationHistory.clear();
    _complaintData.clear();
  }
}
