import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'groq_context_analyzer.dart';
import 'package:flutter/foundation.dart';

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

  // Enhanced conversation state with language selection and persistence
  String _currentStep = 'language_selection';
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
  String? _currentChatId;
  final bool _strictBackendTaxonomy = true;
  bool _backendCategoriesLoadAttempted = false;
  List<Map<String, String>> _backendCategories = [];
  final Map<String, List<String>> _backendSubcategories = {};
  
  // Chat persistence keys
  static const String _chatHistoryKey = 'chat_history';
  static const String _activeChatKey = 'active_chat_id';
  static const String _chatDataKey = 'chat_data_';

  // Language options with native names
  static const Map<String, Map<String, String>> languageOptions = {
    'en': {
      'code': 'en',
      'name': 'English',
      'native': 'English',
      'emoji': '🇺🇸'
    },
    'hi': {
      'code': 'hi',
      'name': 'Hindi',
      'native': 'हिंदी',
      'emoji': '🇮🇳'
    },
    'gu': {
      'code': 'gu',
      'name': 'Gujarati',
      'native': 'ગુજરાતી',
      'emoji': '🇮🇳'
    },
    'hinglish': {
      'code': 'hinglish',
      'name': 'Hinglish',
      'native': 'Hinglish',
      'emoji': '🇮🇳'
    },
  };

  // 12 Main Categories (matching database COMPLAINT_TYPES) - Multi-language support
  static const Map<String, Map<String, String>> categories = {
    'police': {
      'key': 'police',
      'en': 'Police Complaint',
      'hi': 'पुलिस शिकायत',
      'gu': 'પોલીસ ફરિયાદ',
      'hinglish': 'Police ki Complaint',
      'emoji': '👮'
    },
    'traffic': {
      'key': 'traffic',
      'en': 'Traffic Complaint',
      'hi': 'ट्रैफिक शिकायत',
      'gu': 'ટ્રાફિક ફરિયાદ',
      'hinglish': 'Traffic ki Problem',
      'emoji': '🚦'
    },
    'construction': {
      'key': 'construction',
      'en': 'Construction Complaint',
      'hi': 'निर्माण शिकायत',
      'gu': 'બાંધકામ ફરિયાદ',
      'hinglish': 'Construction ki Problem',
      'emoji': '🏗️'
    },
    'water': {
      'key': 'water',
      'en': 'Water Supply',
      'hi': 'पानी की आपूर्ति',
      'gu': 'પાણી પુરવઠો',
      'hinglish': 'Paani ki Supply',
      'emoji': '💧'
    },
    'electricity': {
      'key': 'electricity',
      'en': 'Electricity',
      'hi': 'बिजली',
      'gu': 'વીજળી',
      'hinglish': 'Bijli ki Problem',
      'emoji': '⚡'
    },
    'garbage': {
      'key': 'garbage',
      'en': 'Garbage/Sanitation',
      'hi': 'कचरा/स्वच्छता',
      'gu': 'કચરો/સફાઈ',
      'hinglish': 'Kachra/Safai',
      'emoji': '🗑️'
    },
    'road': {
      'key': 'road',
      'en': 'Road/Pothole',
      'hi': 'सड़क/गड्ढा',
      'gu': 'રસ્તો/ખાડો',
      'hinglish': 'Sadak/Khada',
      'emoji': '🛣️'
    },
    'drainage': {
      'key': 'drainage',
      'en': 'Drainage/Sewage',
      'hi': 'नाली/सीवेज',
      'gu': 'ગટર/ગંદુ પાણી',
      'hinglish': 'Nali/Ganda Paani',
      'emoji': '🚰'
    },
    'illegal': {
      'key': 'illegal',
      'en': 'Illegal Activities',
      'hi': 'अवैध गतिविधियां',
      'gu': 'ગેરકાયદેસર પ્રવૃત્તિઓ',
      'hinglish': 'Illegal Activities',
      'emoji': '⚠️'
    },
    'transportation': {
      'key': 'transportation',
      'en': 'Transportation',
      'hi': 'परिवहन',
      'gu': 'પરિવહન',
      'hinglish': 'Transport ki Problem',
      'emoji': '🚌'
    },
    'cyber': {
      'key': 'cyber',
      'en': 'Cyber Crime',
      'hi': 'साइबर अपराध',
      'gu': 'સાયબર ક્રાઈમ',
      'hinglish': 'Cyber Crime',
      'emoji': '💻'
    },
    'other': {
      'key': 'other',
      'en': 'Other Complaint',
      'hi': 'अन्य शिकायत',
      'gu': 'અન્ય ફરિયાદ',
      'hinglish': 'Aur Koi Problem',
      'emoji': '📝'
    },
  };

  // Subcategories (matching database structure) - Multi-language support
  static const Map<String, Map<String, List<String>>> subcategories = {
    'police': {
      'en': [
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
      'hi': [
        'चोरी',
        'लापता व्यक्ति',
        'हमला',
        'उत्पीड़न',
        'डकैती',
        'संदिग्ध गतिविधि',
        'घरेलू हिंसा',
        'चेन स्नैचिंग',
        'सेंधमारी',
        'अन्य पुलिस मामला'
      ],
      'gu': [
        'ચોરી',
        'ગુમ થયેલ વ્યક્તિ',
        'હુમલો',
        'હેરાનગતિ',
        'લૂંટ',
        'શંકાસ્પદ પ્રવૃત્તિ',
        'ઘરેલું હિંસા',
        'ચેઇન છીનવી',
        'ઘરફોડ ચોરી',
        'અન્ય પોલીસ બાબત'
      ],
      'hinglish': [
        'Chori',
        'Missing Person',
        'Maarpeet',
        'Harassment',
        'Loot',
        'Suspicious Activity',
        'Ghar ki Violence',
        'Chain Snatching',
        'Ghar mein Chori',
        'Aur Police Matter'
      ]
    },
    'traffic': {
      'en': [
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
      'hi': [
        'टूटा सिग्नल',
        'गैरकानूनी पार्किंग',
        'ट्रैफिक जाम',
        'दुर्घटना',
        'तेज़ ड्राइविंग',
        'ट्रैफिक पुलिस नहीं',
        'सड़क निशान गायब',
        'टूटा स्पीड ब्रेकर',
        'गलत दिशा में ड्राइविंग',
        'अन्य ट्रैफिक समस्या'
      ],
      'gu': [
        'તૂટેલ સિગ્નલ',
        'ગેરકાયદેસર પાર્કિંગ',
        'ટ્રાફિક જામ',
        'અકસ્માત',
        'ઝડપી ડ્રાઇવિંગ',
        'ટ્રાફિક પોલીસ નથી',
        'રસ્તાના નિશાન ગુમ',
        'તૂટેલ સ્પીડ બ્રેકર',
        'ખોટી દિશામાં ડ્રાઇવિંગ',
        'અન્ય ટ્રાફિક સમસ્યા'
      ],
      'hinglish': [
        'Signal Toot Gaya',
        'Galat Parking',
        'Traffic Jam',
        'Accident',
        'Fast Driving',
        'Traffic Police Nahi',
        'Road Marking Nahi',
        'Speed Breaker Toota',
        'Ulti Direction Driving',
        'Aur Traffic Problem'
      ]
    },
    'construction': {
      'en': [
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
      'hi': [
        'अवैध निर्माण',
        'निर्माण मलबा',
        'ध्वनि प्रदूषण',
        'अनधिकृत भवन',
        'अतिक्रमण',
        'असुरक्षित निर्माण',
        'सड़क अवरोध',
        'अनुमति नहीं',
        'नियम उल्लंघन',
        'अन्य निर्माण समस्या'
      ],
      'gu': [
        'ગેરકાયદેસર બાંધકામ',
        'બાંધકામનો કચરો',
        'અવાજનું પ્રદૂષણ',
        'અનધિકૃત મકાન',
        'કબજો',
        'અસુરક્ષિત બાંધકામ',
        'રસ્તો બંધ',
        'પરવાનગી નથી',
        'નિયમોનું ઉલ્લંઘન',
        'અન્ય બાંધકામ સમસ્યા'
      ],
      'hinglish': [
        'Illegal Construction',
        'Construction ka Kachra',
        'Noise Pollution',
        'Bina Permission Building',
        'Kabza',
        'Unsafe Construction',
        'Road Block',
        'Permission Nahi',
        'Rules Tod Rahe',
        'Aur Construction Problem'
      ]
    },
    'water': {
      'en': [
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
      'hi': [
        'पानी की आपूर्ति नहीं',
        'पानी का रिसाव',
        'गंदा पानी',
        'कम दबाव',
        'पाइप फटा',
        'दूषित पानी',
        'अनियमित आपूर्ति',
        'मीटर की समस्या',
        'अवैध कनेक्शन',
        'अन्य पानी की समस्या'
      ],
      'gu': [
        'પાણીની પુરવઠો નથી',
        'પાણીનો લીકેજ',
        'ગંદું પાણી',
        'ઓછું દબાણ',
        'પાઇપ ફાટ્યો',
        'દૂષિત પાણી',
        'અનિયમિત પુરવઠો',
        'મીટરની સમસ્યા',
        'ગેરકાયદેસર કનેક્શન',
        'અન્ય પાણીની સમસ્યા'
      ],
      'hinglish': [
        'Paani Nahi Aa Raha',
        'Paani Leak Ho Raha',
        'Ganda Paani',
        'Kam Pressure',
        'Pipe Phata',
        'Kharab Paani',
        'Kabhi Kabhi Paani',
        'Meter ki Problem',
        'Illegal Connection',
        'Aur Paani ki Problem'
      ]
    },
    'electricity': {
      'en': [
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
      'hi': [
        'बिजली कटौती',
        'स्ट्रीट लाइट काम नहीं कर रही',
        'खुला तार',
        'ट्रांसफार्मर की समस्या',
        'टिमटिमाना',
        'वोल्टेज में उतार-चढ़ाव',
        'मीटर की समस्या',
        'अवैध कनेक्शन',
        'पोल क्षति',
        'अन्य बिजली की समस्या'
      ],
      'gu': [
        'વીજળી કાપ',
        'સ્ટ્રીટ લાઇટ કામ નથી કરતી',
        'ખુલ્લો વાયર',
        'ટ્રાન્સફોર્મરની સમસ્યા',
        'ઝબકારો',
        'વોલ્ટેજમાં ફેરફાર',
        'મીટરની સમસ્યા',
        'ગેરકાયદેસર કનેક્શન',
        'પોલને નુકસાન',
        'અન્ય વીજળીની સમસ્યા'
      ],
      'hinglish': [
        'Light Chali Gayi',
        'Street Light Nahi Jal Rahi',
        'Wire Khula Hai',
        'Transformer ki Problem',
        'Light On Off Ho Rahi',
        'Voltage Up Down',
        'Meter ki Problem',
        'Illegal Connection',
        'Pole Toot Gaya',
        'Aur Bijli ki Problem'
      ]
    },
    'garbage': {
      'en': [
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
      'hi': [
        'कचरा नहीं उठाया गया',
        'भरा हुआ डस्टबिन',
        'अवैध कचरा फेंकना',
        'मृत जानवर',
        'कूड़ा फैलाना',
        'कचरा जलाना',
        'डस्टबिन उपलब्ध नहीं',
        'टूटा डस्टबिन',
        'मेडिकल कचरा',
        'अन्य कचरा समस्या'
      ],
      'gu': [
        'કચરો ઉપાડવામાં આવ્યો નથી',
        'ભરાઈ ગયેલ ડસ્ટબિન',
        'ગેરકાયદેસર કચરો ફેંકવો',
        'મૃત પ્રાણી',
        'કચરો ફેલાવવો',
        'કચરો બાળવો',
        'ડસ્ટબિન ઉપલબ્ધ નથી',
        'તૂટેલ ડસ્ટબિન',
        'તબીબી કચરો',
        'અન્ય કચરાની સમસ્યા'
      ],
      'hinglish': [
        'Kachra Nahi Uthaya',
        'Dustbin Bhar Gaya',
        'Galat Jagah Kachra',
        'Mara Hua Janwar',
        'Kachra Failana',
        'Kachra Jalana',
        'Dustbin Nahi Hai',
        'Dustbin Toota',
        'Hospital ka Kachra',
        'Aur Kachra Problem'
      ]
    },
    'road': {
      'en': [
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
      'hi': [
        'गड्ढा',
        'टूटी सड़क',
        'जल भराव',
        'सड़क अवरोध',
        'दरार वाली सड़क',
        'सड़क धंसना',
        'असमान सतह',
        'सड़क के संकेत गायब',
        'सड़क पर मलबा',
        'अन्य सड़क समस्या'
      ],
      'gu': [
        'ખાડો',
        'તૂટેલો રસ્તો',
        'પાણી ભરાવો',
        'રસ્તો બંધ',
        'તિરાડ વાળો રસ્તો',
        'રસ્તો ધસી જવો',
        'અસમાન સપાટી',
        'રસ્તાના સંકેતો ગુમ',
        'રસ્તા પર કચરો',
        'અન્ય રસ્તાની સમસ્યા'
      ],
      'hinglish': [
        'Khada/Pothole',
        'Sadak Tooti',
        'Paani Bhara Hua',
        'Road Block',
        'Sadak mein Crack',
        'Sadak Dhas Gayi',
        'Uneven Road',
        'Road Sign Nahi',
        'Road pe Kachra',
        'Aur Road Problem'
      ]
    },
    'drainage': {
      'en': [
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
      'hi': [
        'बंद नाली',
        'सीवेज ओवरफ्लो',
        'बुरी गंध',
        'खुला मैनहोल',
        'बंद गटर',
        'टूटा नाली कवर',
        'रुका हुआ पानी',
        'सीवेज रिसाव',
        'नाली गिरना',
        'अन्य नाली समस्या'
      ],
      'gu': [
        'બંધ ગટર',
        'ગંદા પાણીનો ઓવરફ્લો',
        'ખરાબ ગંધ',
        'ખુલ્લો મેનહોલ',
        'બંધ ગટર',
        'તૂટેલ ગટર કવર',
        'સ્થિર પાણી',
        'ગંદા પાણીનો લીકેજ',
        'ગટર પડી જવી',
        'અન્ય ગટરની સમસ્યા'
      ],
      'hinglish': [
        'Nali Band',
        'Ganda Paani Overflow',
        'Buri Smell',
        'Manhole Khula',
        'Gutter Band',
        'Nali Cover Toota',
        'Paani Ruka Hua',
        'Ganda Paani Leak',
        'Nali Gir Gayi',
        'Aur Nali Problem'
      ]
    },
    'illegal': {
      'en': [
        'Illegal Parking',
        'Illegal Construction',
        'Illegal Dumping',
        'Illegal Hoarding',
        'Encroachment',
        'Unauthorized Activity',
        'Illegal Business',
        'Other Illegal Activity'
      ],
      'hi': [
        'अवैध पार्किंग',
        'अवैध निर्माण',
        'अवैध कचरा फेंकना',
        'अवैध होर्डिंग',
        'अतिक्रमण',
        'अनधिकृत गतिविधि',
        'अवैध व्यापार',
        'अन्य अवैध गतिविधि'
      ],
      'gu': [
        'ગેરકાયદેસર પાર્કિંગ',
        'ગેરકાયદેસર બાંધકામ',
        'ગેરકાયદેસર કચરો ફેંકવો',
        'ગેરકાયદેસર હોર્ડિંગ',
        'કબજો',
        'અનધિકૃત પ્રવૃત્તિ',
        'ગેરકાયદેસર ધંધો',
        'અન્ય ગેરકાયદેસર પ્રવૃત્તિ'
      ],
      'hinglish': [
        'Galat Parking',
        'Illegal Construction',
        'Galat Jagah Kachra',
        'Illegal Hoarding',
        'Kabza',
        'Bina Permission Activity',
        'Illegal Business',
        'Aur Illegal Activity'
      ]
    },
    'transportation': {
      'en': [
        'Bus Not Available',
        'Bus Delay',
        'Overcrowding',
        'Rash Driving',
        'Poor Condition',
        'Route Issue',
        'Other Transportation Issue'
      ],
      'hi': [
        'बस उपलब्ध नहीं',
        'बस देरी',
        'भीड़भाड़',
        'तेज़ ड्राइविंग',
        'खराब स्थिति',
        'रूट की समस्या',
        'अन्य परिवहन समस्या'
      ],
      'gu': [
        'બસ ઉપલબ્ધ નથી',
        'બસ મોડી',
        'ભીડ',
        'ઝડપી ડ્રાઇવિંગ',
        'ખરાબ સ્થિતિ',
        'રૂટની સમસ્યા',
        'અન્ય પરિવહન સમસ્યા'
      ],
      'hinglish': [
        'Bus Nahi Mil Rahi',
        'Bus Late',
        'Bahut Bheed',
        'Fast Driving',
        'Bus ki Condition Kharab',
        'Route ki Problem',
        'Aur Transport Problem'
      ]
    },
    'cyber': {
      'en': [
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
      'hi': [
        'ऑनलाइन धोखाधड़ी',
        'UPI घोटाला',
        'फिशिंग',
        'खाता हैक',
        'पहचान चोरी',
        'नकली वेबसाइट',
        'सोशल मीडिया धोखाधड़ी',
        'OTP धोखाधड़ी',
        'बैंकिंग धोखाधड़ी',
        'अन्य साइबर अपराध'
      ],
      'gu': [
        'ઓનલાઇન છેતરપિંડી',
        'UPI સ્કેમ',
        'ફિશિંગ',
        'એકાઉન્ટ હેક',
        'ઓળખની ચોરી',
        'નકલી વેબસાઇટ',
        'સોશિયલ મીડિયા છેતરપિંડી',
        'OTP છેતરપિંડી',
        'બેંકિંગ છેતરપિંડી',
        'અન્ય સાયબર ક્રાઇમ'
      ],
      'hinglish': [
        'Online Fraud',
        'UPI Scam',
        'Phishing',
        'Account Hack Ho Gaya',
        'Identity Chori',
        'Fake Website',
        'Social Media Fraud',
        'OTP Fraud',
        'Bank Fraud',
        'Aur Cyber Crime'
      ]
    },
    'other': {
      'en': [
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
      'hi': [
        'पार्क रखरखाव',
        'पेड़ काटना आवश्यक',
        'आवारा जानवर',
        'शोर की शिकायत',
        'वायु प्रदूषण',
        'अवैध होर्डिंग',
        'सार्वजनिक संपत्ति क्षति',
        'अतिक्रमण',
        'अन्य समस्या',
        'सामान्य शिकायत'
      ],
      'gu': [
        'પાર્કની જાળવણી',
        'વૃક્ષ કાપવાની જરૂર',
        'રખડતા પ્રાણીઓ',
        'અવાજની ફરિયાદ',
        'હવા પ્રદૂષણ',
        'ગેરકાયદેસર હોર્ડિંગ',
        'જાહેર મિલકતને નુકસાન',
        'કબજો',
        'અન્ય સમસ્યા',
        'સામાન્ય ફરિયાદ'
      ],
      'hinglish': [
        'Park ki Safai',
        'Ped Katna Hai',
        'Awara Janwar',
        'Noise ki Problem',
        'Air Pollution',
        'Illegal Hoarding',
        'Public Property Damage',
        'Kabza',
        'Aur Problem',
        'General Complaint'
      ]
    },
  };

  /// Initialize or restore chat session
  Future<void> initializeChatSession({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generate or get chat ID
      _currentChatId = _generateChatId();
      
      // Try to restore active chat
      final activeChatId = prefs.getString(_activeChatKey);
      if (activeChatId != null) {
        final restored = await _restoreChatSession(activeChatId);
        if (restored) {
          _currentChatId = activeChatId;
          return;
        }
      }
      
      // Start fresh session
      await _saveChatSession();
      await prefs.setString(_activeChatKey, _currentChatId!);
      
    } catch (e) {
      debugPrint('Error initializing chat session: $e');
      // Continue with fresh session
      _currentChatId = _generateChatId();
    }
  }
  
  /// Generate unique chat ID
  String _generateChatId() {
    return 'chat_${DateTime.now().millisecondsSinceEpoch}_${_userName.isNotEmpty ? _userName.hashCode : 'anon'}';
  }
  
  /// Save current chat session
  Future<void> _saveChatSession() async {
    if (_currentChatId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final chatData = {
        'chatId': _currentChatId,
        'currentStep': _currentStep,
        'complaintData': _complaintData,
        'conversationHistory': _conversationHistory,
        'userCity': _userCity,
        'userName': _userName,
        'userLanguage': _userLanguage,
        'retryCount': _retryCount,
        'sentiment': _sentiment,
        'urgencyScore': _urgencyScore,
        'aiContext': _aiContext,
        'conversationStartTime': _conversationStartTime.toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
        'isCompleted': _currentStep == 'submitted',
      };
      
      // Save individual chat data
      await prefs.setString('$_chatDataKey$_currentChatId', jsonEncode(chatData));
      
      // Update chat history list
      await _updateChatHistoryList();
      
    } catch (e) {
      debugPrint('Error saving chat session: $e');
    }
  }
  
  /// Update chat history list
  Future<void> _updateChatHistoryList() async {
    if (_currentChatId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_chatHistoryKey) ?? '[]';
      final List<dynamic> history = jsonDecode(historyJson);
      
      // Remove existing entry if present
      history.removeWhere((chat) => chat['chatId'] == _currentChatId);
      
      // Add current chat to top
      final chatSummary = {
        'chatId': _currentChatId,
        'title': _getChatTitle(),
        'lastMessage': _getLastMessage(),
        'timestamp': DateTime.now().toIso8601String(),
        'isCompleted': _currentStep == 'submitted',
        'category': _complaintData['category'] ?? '',
        'categoryEmoji': _complaintData['category_emoji'] ?? '📝',
        'language': _userLanguage,
        'step': _currentStep,
      };
      
      history.insert(0, chatSummary);
      
      // Keep only last 50 chats
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }
      
      await prefs.setString(_chatHistoryKey, jsonEncode(history));
      
    } catch (e) {
      debugPrint('Error updating chat history: $e');
    }
  }
  
  /// Get chat title based on current state
  String _getChatTitle() {
    if (_complaintData.containsKey('category')) {
      return '${_complaintData['category_emoji']} ${_complaintData['category']}';
    }
    
    switch (_currentStep) {
      case 'language_selection':
        return _localize('Language Selection', 'भाषा चयन', 'ભાષા પસંદગી', 'Language Selection');
      case 'greeting':
      case 'category':
        return _localize('New Complaint', 'नई शिकायत', 'નવી ફરિયાદ', 'Nayi Complaint');
      case 'submitted':
        return _localize('Complaint Submitted', 'शिकायत जमा की गई', 'ફરિયાદ સબમિટ કરી', 'Complaint Submit Ho Gayi');
      default:
        return _localize('Complaint in Progress', 'शिकायत प्रगति में', 'ફરિયાદ પ્રગતિમાં', 'Complaint Progress Mein');
    }
  }
  
  /// Get last message for preview
  String _getLastMessage() {
    if (_conversationHistory.isNotEmpty) {
      final lastMsg = _conversationHistory.last;
      final content = lastMsg['content'] ?? '';
      return content.length > 100 ? '${content.substring(0, 100)}...' : content;
    }
    
    return _localize('Chat started', 'चैट शुरू हुई', 'ચેટ શરૂ થઈ', 'Chat start hui');
  }
  
  /// Restore chat session from storage
  Future<bool> _restoreChatSession(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatDataJson = prefs.getString('$_chatDataKey$chatId');
      
      if (chatDataJson == null) return false;
      
      final chatData = jsonDecode(chatDataJson);
      
      // Restore state
      _currentStep = chatData['currentStep'] ?? 'language_selection';
      _complaintData.clear();
      _complaintData.addAll(Map<String, dynamic>.from(chatData['complaintData'] ?? {}));
      
      _conversationHistory.clear();
      final history = chatData['conversationHistory'] as List? ?? [];
      _conversationHistory.addAll(history.map((h) => Map<String, String>.from(h)).toList());
      
      _userCity = chatData['userCity'] ?? '';
      _userName = chatData['userName'] ?? '';
      _userLanguage = chatData['userLanguage'] ?? 'en';
      _retryCount = chatData['retryCount'] ?? 0;
      _sentiment = chatData['sentiment'] ?? 'neutral';
      _urgencyScore = (chatData['urgencyScore'] ?? 0.5).toDouble();
      
      _aiContext.clear();
      _aiContext.addAll(Map<String, dynamic>.from(chatData['aiContext'] ?? {}));
      
      final startTimeStr = chatData['conversationStartTime'];
      if (startTimeStr != null) {
        _conversationStartTime = DateTime.parse(startTimeStr);
      }
      
      return true;
      
    } catch (e) {
      debugPrint('Error restoring chat session: $e');
      return false;
    }
  }
  
  /// Get chat history list
  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_chatHistoryKey) ?? '[]';
      final List<dynamic> history = jsonDecode(historyJson);
      
      return history.map((chat) => Map<String, dynamic>.from(chat)).toList();
      
    } catch (e) {
      debugPrint('Error getting chat history: $e');
      return [];
    }
  }
  
  /// Load specific chat by ID
  Future<bool> loadChat(String chatId) async {
    final restored = await _restoreChatSession(chatId);
    if (restored) {
      _currentChatId = chatId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeChatKey, chatId);
    }
    return restored;
  }
  
  /// Start new chat session
  Future<void> startNewChat() async {
    // Reset all state
    _currentStep = 'language_selection';
    _complaintData.clear();
    _conversationHistory.clear();
    _retryCount = 0;
    _sentiment = 'neutral';
    _urgencyScore = 0.5;
    _aiContext.clear();
    _conversationStartTime = DateTime.now();
    _userLanguage = 'en';
    
    // Generate new chat ID
    _currentChatId = _generateChatId();
    
    // Save new session
    await _saveChatSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeChatKey, _currentChatId!);
  }
  
  /// Delete specific chat
  Future<void> deleteChat(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove chat data
      await prefs.remove('$_chatDataKey$chatId');
      
      // Update history list
      final historyJson = prefs.getString(_chatHistoryKey) ?? '[]';
      final List<dynamic> history = jsonDecode(historyJson);
      history.removeWhere((chat) => chat['chatId'] == chatId);
      await prefs.setString(_chatHistoryKey, jsonEncode(history));
      
      // If this was the active chat, clear it
      final activeChatId = prefs.getString(_activeChatKey);
      if (activeChatId == chatId) {
        await prefs.remove(_activeChatKey);
      }
      
    } catch (e) {
      debugPrint('Error deleting chat: $e');
    }
  }
  
  /// Clear all chat history
  Future<void> clearAllChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all chat IDs and remove their data
      final historyJson = prefs.getString(_chatHistoryKey) ?? '[]';
      final List<dynamic> history = jsonDecode(historyJson);
      
      for (final chat in history) {
        final chatId = chat['chatId'];
        if (chatId != null) {
          await prefs.remove('$_chatDataKey$chatId');
        }
      }
      
      // Clear history list and active chat
      await prefs.remove(_chatHistoryKey);
      await prefs.remove(_activeChatKey);
      
    } catch (e) {
      debugPrint('Error clearing all chats: $e');
    }
  }
  
  /// Get current chat ID
  String? getCurrentChatId() => _currentChatId;
  List<Map<String, dynamic>> _getCategories() {
    if (_backendCategories.isNotEmpty) {
      return _backendCategories
          .map((category) => {
                'key': category['key'],
                'name': _getCategoryName(
                  category['key']!,
                  fallbackName: category['name'],
                ),
                'emoji': _getCategoryEmoji(
                  category['key']!,
                  fallbackEmoji: category['emoji'],
                ),
              })
          .toList();
    }

    if (_strictBackendTaxonomy) {
      return [];
    }

    return categories.values
        .map((c) => {
              'key': c['key'],
              'name': _getCategoryName(c['key']!),
              'emoji': c['emoji'],
            })
        .toList();
  }
  
  /// Get category name in current language
  String _getCategoryName(String key, {String? fallbackName}) {
    final category = categories[key];
    if (category == null) {
      return (fallbackName?.trim().isNotEmpty ?? false)
          ? fallbackName!.trim()
          : key;
    }
    
    switch (_userLanguage) {
      case 'hi':
        return category['hi'] ?? category['en'] ?? key;
      case 'gu':
        return category['gu'] ?? category['en'] ?? key;
      case 'hinglish':
        return category['hinglish'] ?? category['en'] ?? key;
      default:
        return category['en'] ?? key;
    }
  }

  String _getCategoryEmoji(String key, {String? fallbackEmoji}) {
    final category = categories[key];
    if (category != null && (category['emoji']?.isNotEmpty ?? false)) {
      return category['emoji']!;
    }
    if (fallbackEmoji?.trim().isNotEmpty ?? false) {
      return fallbackEmoji!.trim();
    }
    return '📝';
  }

  bool _hasCategoryKey(String key) {
    if (key.trim().isEmpty) return false;
    if (!_strictBackendTaxonomy && categories.containsKey(key)) return true;
    return _backendCategories.any((category) => category['key'] == key);
  }

  Map<String, String>? _findCategoryByKey(String key) {
    if (!_hasCategoryKey(key)) {
      return null;
    }

    Map<String, String>? backendCategory;
    for (final category in _backendCategories) {
      if (category['key'] == key) {
        backendCategory = category;
        break;
      }
    }

    return {
      'key': key,
      'name': _getCategoryName(
        key,
        fallbackName: backendCategory?['name'],
      ),
      'emoji': _getCategoryEmoji(
        key,
        fallbackEmoji: backendCategory?['emoji'],
      ),
    };
  }

  Future<void> _ensureBackendCategoriesLoaded() async {
    if (_backendCategoriesLoadAttempted) {
      return;
    }
    _backendCategoriesLoadAttempted = true;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.categories),
        headers: const {
          'Content-Type': 'application/json',
        },
      ).timeout(ApiConfig.receiveTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Backend categories request failed: ${response.statusCode}');
        return;
      }

      final decoded = jsonDecode(response.body);
      final rawCategories = decoded is Map<String, dynamic>
          ? decoded['categories']
          : decoded;
      if (rawCategories is! List) {
        return;
      }

      final parsedCategories = <Map<String, String>>[];
      final parsedSubcategories = <String, List<String>>{};

      for (final rawCategory in rawCategories) {
        if (rawCategory is! Map) continue;
        final category = Map<String, dynamic>.from(rawCategory);
        final key = (category['key'] ?? '').toString().trim();
        if (key.isEmpty) continue;

        final name = (category['name'] ?? '').toString().trim();
        final emoji = (category['emoji'] ?? '').toString().trim();

        parsedCategories.add({
          'key': key,
          'name': name.isNotEmpty ? name : key,
          'emoji': emoji.isNotEmpty ? emoji : _getCategoryEmoji(key),
        });

        final rawSubcategories = category['subcategories'];
        if (rawSubcategories is List) {
          final names = rawSubcategories
              .whereType<Map>()
              .map((sub) => (sub['name'] ?? '').toString().trim())
              .where((name) => name.isNotEmpty)
              .toList();
          if (names.isNotEmpty) {
            parsedSubcategories[key] = names;
          }
        }
      }

      if (parsedCategories.isNotEmpty) {
        _backendCategories = parsedCategories;
      }
      if (parsedSubcategories.isNotEmpty) {
        _backendSubcategories
          ..clear()
          ..addAll(parsedSubcategories);
      }
    } catch (e) {
      debugPrint('Failed to load backend categories: $e');
    }
  }
  
  /// Get subcategories with multi-language support
  List<String> _getSubcategories(String categoryKey) {
    final backendSubs = _backendSubcategories[categoryKey];
    if (backendSubs != null && backendSubs.isNotEmpty) {
      return backendSubs;
    }

    if (_strictBackendTaxonomy) return [];

    final subs = subcategories[categoryKey];
    if (subs == null) return ['Other'];
    
    switch (_userLanguage) {
      case 'hi':
        return subs['hi'] ?? subs['en'] ?? ['अन्य'];
      case 'gu':
        return subs['gu'] ?? subs['en'] ?? ['અન્ય'];
      case 'hinglish':
        return subs['hinglish'] ?? subs['en'] ?? ['Other'];
      default:
        return subs['en'] ?? ['Other'];
    }
  }

  String _normalizeSubcategoryToEnglish(String categoryKey, String userInput) {
    final backendSubs = _backendSubcategories[categoryKey];
    final backendMatch = _matchSubcategoryFromList(
      backendSubs ?? const <String>[],
      userInput,
    );
    if (backendMatch != null) {
      return backendMatch;
    }

    final subs = subcategories[categoryKey];
    if (subs == null) {
      return userInput.trim();
    }

    final englishSubs = subs['en'] ?? const <String>[];
    final variants = <String, List<String>>{
      'en': englishSubs,
      'hi': subs['hi'] ?? const <String>[],
      'gu': subs['gu'] ?? const <String>[],
      'hinglish': subs['hinglish'] ?? const <String>[],
    };

    final normalizedInput = _normalizeTextForMatching(userInput);
    for (var i = 0; i < englishSubs.length; i++) {
      final englishValue = englishSubs[i];
      for (final languageValues in variants.values) {
        if (i >= languageValues.length) continue;
        final candidate = _normalizeTextForMatching(languageValues[i]);
        if (candidate.isNotEmpty &&
            (normalizedInput == candidate ||
                normalizedInput.contains(candidate) ||
                candidate.contains(normalizedInput))) {
          final exactBackendMatch = _matchSubcategoryFromList(
            backendSubs ?? const <String>[],
            englishValue,
          );
          if (exactBackendMatch != null) {
            return exactBackendMatch;
          }
          return englishValue;
        }
      }
    }

    return userInput.trim();
  }

  String? _matchSubcategoryFromList(List<String> options, String input) {
    final normalizedInput = _normalizeTextForMatching(input);
    if (normalizedInput.isEmpty) {
      return null;
    }

    String? containsMatch;
    for (final option in options) {
      final normalizedOption = _normalizeTextForMatching(option);
      if (normalizedOption.isEmpty) continue;

      if (normalizedInput == normalizedOption) {
        return option;
      }

      if (normalizedInput.contains(normalizedOption) ||
          normalizedOption.contains(normalizedInput)) {
        containsMatch ??= option;
      }
    }
    return containsMatch;
  }

  String? _fallbackSubcategoryOption(List<String> options) {
    for (final option in options) {
      final normalized = _normalizeTextForMatching(option);
      if (normalized.contains('other')) {
        return option;
      }
    }
    return null;
  }

  bool _looksLikeDetailedComplaint(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 25) {
      return false;
    }
    final words = normalized
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .length;
    return words >= 5;
  }

  Future<String?> _detectSubcategoryForCategory(
    String categoryKey,
    String input,
  ) async {
    final availableSubcategories = _getSubcategories(categoryKey);
    if (availableSubcategories.isEmpty) {
      return null;
    }

    final directMatch = _matchSubcategoryFromList(availableSubcategories, input);
    if (directMatch != null) {
      return directMatch;
    }

    final normalizedMatch = _normalizeSubcategoryToEnglish(categoryKey, input);
    final backendMatch = _matchSubcategoryFromList(
      availableSubcategories,
      normalizedMatch,
    );
    if (backendMatch != null) {
      return backendMatch;
    }

    if (!_looksLikeDetailedComplaint(input)) {
      return null;
    }

    try {
      final prompt = '''Pick the single best backend subcategory for this complaint.

Category key: $categoryKey
Complaint text: "$input"

Available subcategories:
${availableSubcategories.map((sub) => '- $sub').join('\n')}

Rules:
- Respond with exactly one subcategory name from the list above.
- If nothing matches well, respond with UNKNOWN.''';

      final response = await _callGroqAPI(
        prompt,
        maxTokens: 80,
        temperature: 0.1,
      );

      if (response != null) {
        final aiMatch = _matchSubcategoryFromList(
          availableSubcategories,
          response,
        );
        if (aiMatch != null) {
          return aiMatch;
        }
      }
    } catch (e) {
      debugPrint('Subcategory detection failed: $e');
    }

    return _fallbackSubcategoryOption(availableSubcategories);
  }

  String _normalizeTextForMatching(String input) {
    return _convertDigitsToAscii(input)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _convertDigitsToAscii(String input) {
    const digitMap = {
      '०': '0',
      '१': '1',
      '२': '2',
      '३': '3',
      '४': '4',
      '५': '5',
      '६': '6',
      '७': '7',
      '८': '8',
      '९': '9',
      '૦': '0',
      '૧': '1',
      '૨': '2',
      '૩': '3',
      '૪': '4',
      '૫': '5',
      '૬': '6',
      '૭': '7',
      '૮': '8',
      '૯': '9',
    };

    var output = input;
    digitMap.forEach((key, value) {
      output = output.replaceAll(key, value);
    });
    return output;
  }

  String _normalizePhoneValue(String input) {
    return _convertDigitsToAscii(input).replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _normalizeEmailValue(String input) {
    return _convertDigitsToAscii(input).trim().toLowerCase().replaceAll(' ', '');
  }

  String _normalizeContactNameValue(String input) {
    final profileName = (_userProfile?['fullName'] ?? '').toString().trim();
    if (profileName.isNotEmpty) {
      return profileName;
    }
    return input.trim();
  }

  bool _matchesIntentPhrase(String input, String phrase) {
    final normalizedInput = _normalizeTextForMatching(input);
    final normalizedPhrase = _normalizeTextForMatching(phrase);
    if (normalizedInput.isEmpty || normalizedPhrase.isEmpty) {
      return false;
    }
    if (normalizedInput == normalizedPhrase) {
      return true;
    }
    return normalizedInput.startsWith('$normalizedPhrase ') ||
        normalizedInput.endsWith(' $normalizedPhrase') ||
        normalizedInput.contains(' $normalizedPhrase ');
  }

  bool _matchesAnyIntentPhrase(String input, List<String> phrases) {
    for (final phrase in phrases) {
      if (_matchesIntentPhrase(input, phrase)) {
        return true;
      }
    }
    return false;
  }

  bool _isAffirmativeResponse(String input) => _matchesAnyIntentPhrase(input, [
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
        'yes please',
      ]);

  bool _isNegativeResponse(String input) => _matchesAnyIntentPhrase(input, [
        'no',
        'n',
        'nope',
        'nah',
        'nahi',
        'nahin',
        'nai',
        'na',
        'galat',
        'wrong',
      ]);

  bool _isSkipResponse(String input) => _matchesAnyIntentPhrase(input, [
        'skip',
        'skip it',
        'later',
        'baad mein',
        'baad me',
        'chhod',
        'chod',
      ]);

  bool _isEditResponse(String input) => _matchesAnyIntentPhrase(input, [
        'edit',
        'change',
        'modify',
        'sampadit',
        'संपादित',
      ]);

  bool _isSubmitLikeResponse(String input) {
    return _matchesAnyIntentPhrase(input, [
          'submit',
          'sabmit',
          'submitt',
          'submit karo',
          'submit kar do',
          'submitt karo',
          'सबमिट',
          'સબમિટ',
        ]) ||
        _isAffirmativeResponse(input);
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

    if (!_backendCategoriesLoadAttempted) {
      await _ensureBackendCategoriesLoaded();
    }

    if (_strictBackendTaxonomy && _backendCategories.isEmpty) {
      return ConversationResponse(
        message: _localize(
          'Category service is syncing from backend. Please try again in a few seconds.',
          'कैटेगरी सेवा बैकएंड से सिंक हो रही है। कृपया कुछ सेकंड बाद फिर कोशिश करें।',
          'કેટેગરી સેવા બેકએન્ડમાંથી સિંક થઈ રહી છે. કૃપા કરીને થોડા સેકન્ડ પછી ફરી પ્રયાસ કરો.',
          'Category service backend se sync ho rahi hai. Please kuch second baad try karo.',
        ),
        buttons: [
          _localize('Retry', 'फिर कोशिश करें', 'ફરી પ્રયાસ કરો', 'Retry'),
        ],
        suggestions: [],
        step: _currentStep,
        showInput: true,
      );
    }

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
          !_isAffirmativeResponse(userInput) &&
          !_isNegativeResponse(userInput) &&
          !_isSkipResponse(userInput) &&
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
      case 'language_selection':
        response = _handleLanguageSelection(userInput);
        break;
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
        response = _handleLanguageSelection(userInput);
    }

    _conversationHistory.add({
      'role': 'assistant',
      'content': response.message,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Save chat session after each interaction
    await _saveChatSession();

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

  /// Step 0: Language Selection - First step in conversation
  ConversationResponse _handleLanguageSelection(String userInput) {
    // Check if user selected a language
    if (userInput.isNotEmpty && userInput != 'start') {
      // Try to detect language from input
      String? selectedLang;
      final input = userInput.toLowerCase();
      
      if (input.contains('english') || input.contains('eng')) {
        selectedLang = 'en';
      } else if (input.contains('hindi') || input.contains('हिंदी') || input.contains('hin')) {
        selectedLang = 'hi';
      } else if (input.contains('gujarati') || input.contains('ગુજરાતી') || input.contains('guj')) {
        selectedLang = 'gu';
      } else if (input.contains('hinglish')) {
        selectedLang = 'hinglish';
      }
      
      // Check if it's a button selection (emoji + language)
      for (var lang in languageOptions.values) {
        if (input.contains(lang['native']!.toLowerCase()) || 
            input.contains(lang['name']!.toLowerCase())) {
          selectedLang = lang['code'];
          break;
        }
      }
      
      if (selectedLang != null) {
        _userLanguage = selectedLang;
        _currentStep = 'greeting';
        
        // Show confirmation and proceed to greeting
        final selectedLangInfo = languageOptions[selectedLang]!;
        return ConversationResponse(
          message: '''${selectedLangInfo['emoji']} ${_localize(
            'Perfect! I\'ll help you in **${selectedLangInfo['name']}**.',
            'बहुत बढ़िया! मैं **${selectedLangInfo['native']}** में आपकी मदद करूंगा।',
            'સારું! હું **${selectedLangInfo['native']}** માં તમારી મદદ કરીશ।',
            'Perfect! Main **${selectedLangInfo['native']}** mein aapki help karunga.'
          )}

${_localize(
            'Let\'s get started with your complaint! 🚀',
            'आइए आपकी शिकायत के साथ शुरूआत करते हैं! 🚀',
            'ચાલો તમારી ફરિયાદ સાથે શરૂઆત કરીએ! 🚀',
            'Chalo aapki complaint ke saath start karte hain! 🚀'
          )}''',
          buttons: [_localize('Continue', 'जारी रखें', 'ચાલુ રાખો', 'Continue')],
          suggestions: [],
          step: 'greeting',
          showInput: true,
          inputPlaceholder: _localize('Tell me your problem...', 'अपनी समस्या बताएं...', 'તમારી સમસ્યા કહો...', 'Apni problem batao...'),
        );
      }
    }
    
    // Show language selection options
    final languageButtons = languageOptions.values
        .map((lang) => '${lang['emoji']} ${lang['native']}')
        .toList();
    
    return ConversationResponse(
      message: '''🌍 **Welcome to JANHELP!**
👋 Namaste! સ્વાગત! Welcome!

I'm your friendly AI assistant for Smart City complaints. I can help you in multiple languages!

🇨 **Choose your preferred language:**
मैं कई भाषाओं में मदद कर सकता हूं!
હું અનેક ભાષાઓમાં મદદ કરી શકું છું!
Main kai languages mein help kar sakta hun!''',
      buttons: languageButtons,
      suggestions: [
        'English please',
        'हिंदी में बात करें',
        'ગુજરાતીમાં વાત કરીએ',
        'Hinglish mein baat karte hain'
      ],
      step: 'language_selection',
      showInput: true,
      inputPlaceholder: 'Select your language / अपनी भाषा चुनें / તમારી ભાષા પસંદ કરો',
    );
  }

  /// Step 1: Enhanced Greeting with multi-language support
  Future<ConversationResponse> _handleGreeting(String userInput) async {
    _currentStep = 'category';
    _conversationStartTime = DateTime.now();
    
    final hour = DateTime.now().hour;
    String timeGreeting;
    String emoji;
    if (hour < 12) {
      timeGreeting = _localize('Good morning', 'सुप्रभात', 'સુપ્રભાત', 'Good morning');
      emoji = '🌅';
    } else if (hour < 17) {
      timeGreeting = _localize('Good afternoon', 'शुभ दोपहर', 'શુભ બપોર', 'Good afternoon');
      emoji = '☀️';
    } else {
      timeGreeting = _localize('Good evening', 'शुभ संध्या', 'શુભ સાંજ', 'Good evening');
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
    if (categoryButtons.isEmpty) {
      return ConversationResponse(
        message: _localize(
          'I could not load complaint categories from backend yet. Please tap retry.',
          'मैं अभी बैकएंड से शिकायत श्रेणियां लोड नहीं कर पाया। कृपया रीट्राई दबाएं।',
          'હું હજી બેકએન્ડમાંથી ફરિયાદ કેટેગરી લોડ કરી શક્યો નથી. કૃપા કરીને રિટ્રાય દબાવો.',
          'Main abhi backend se complaint categories load nahi kar paaya. Please retry dabao.',
        ),
        buttons: [_localize('Retry', 'फिर कोशिश करें', 'ફરી પ્રયાસ કરો', 'Retry')],
        suggestions: [],
        step: 'greeting',
        showInput: true,
      );
    }
    
    debugPrint('📝 Showing ${categoryButtons.length} categories to user');

    return ConversationResponse(
      message: '''$greeting

${_localize(
        'I\'m JANHELP, your friendly AI assistant! 😊 I\'m here to help you report issues in ${_userCity.isNotEmpty ? _userCity : 'your city'} and make sure they get resolved quickly.',
        'मैं JANHELP हूं, आपका दोस्ताना AI सहायक! 😊 मैं ${_userCity.isNotEmpty ? _userCity : 'आपके शहर'} में समस्याओं की रिपोर्ट करने में आपकी मदद करने के लिए यहां हूं।',
        'હું JANHELP છું, તમારો મૈત્રીપૂર્ણ AI સહાયક! 😊 હું ${_userCity.isNotEmpty ? _userCity : 'તમારા શહેર'}માં સમસ્યાઓની જાણ કરવામાં તમને મદદ કરવા માટે અહીં છું।',
        'Main JANHELP hun, aapka friendly AI assistant! 😊 Main ${_userCity.isNotEmpty ? _userCity : 'aapke city'} mein problems report karne mein help karunga.'
      )}

${_localize(
        'Don\'t worry, I\'ll guide you through everything step by step. Just tell me what\'s bothering you, and I\'ll take care of the rest! 💪',
        'चिंता मत करो, मैं आपको हर चीज में कदम दर कदम मार्गदर्शन करूंगा। बस मुझे बताएं कि आपको क्या परेशान कर रहा है! 💪',
        'ચિંતા કરશો નહીં, હું તમને દરેક વસ્તુમાં પગલું દર પગલું માર્ગદર્શન આપીશ। ફક્ત મને કહો કે તમને શું પરેશાન કરી રહ્યું છે! 💪',
        'Tension mat lo, main aapko step by step guide karunga. Bas batao kya problem hai! 💪'
      )}

🗣️ ${_localize(
        'You can describe your problem naturally - I understand! What issue would you like to report?',
        'आप अपनी समस्या स्वाभाविक रूप से बता सकते हैं - मैं समझता हूं! आप कौन सी समस्या रिपोर्ट करना चाहते हैं?',
        'તમે તમારી સમસ્યા સ્વાભાવિક રીતે વર્ણવી શકો છો - હું સમજું છું! તમે કઈ સમસ્યાની જાણ કરવા માંગો છો?',
        'Aap apni problem naturally bata sakte hain - main samajh jaunga! Kya problem report karni hai?'
      )}''',
      buttons: categoryButtons,
      suggestions: [
        _localize('There\'s a big pothole on my street', 'मेरी गली में एक बड़ा गड्ढा है', 'મારી ગલીમાં મોટો ખાડો છે', 'Meri gali mein bada khada hai'),
        _localize('We haven\'t had water since morning', 'सुबह से पानी नहीं आया', 'સવારથી પાણી આવ્યું નથી', 'Subah se paani nahi aaya'),
        _localize('Street light is broken - it\'s dark at night', 'स्ट्रीट लाइट टूटी है - रात में अंधेरा है', 'સ્ટ્રીટ લાઇટ તૂટી ગઈ છે - રાત્રે અંધારું છે', 'Street light toot gayi - raat mein andhera hai'),
        _localize('Garbage hasn\'t been collected for days', 'कई दिनों से कचरा नहीं उठाया गया', 'દિવસોથી કચરો ઉપાડવામાં આવ્યો નથી', 'Kai dino se kachra nahi uthaya'),
      ],
      step: 'category',
      showInput: true,
      inputPlaceholder: _localize('Tell me what happened...', 'बताएं क्या हुआ...', 'કહો શું થયું...', 'Batao kya hua...'),
    );
  }

  /// Step 2: Enhanced category selection with multi-language support
  Future<ConversationResponse> _handleCategorySelection(String userInput) async {
    if (_complaintData.containsKey('category_retry')) {
      _retryCount++;
    }

    // Check if user is trying to report multiple issues at once
    final multipleIssuesDetected = _detectMultipleIssues(userInput);
    if (multipleIssuesDetected != null && multipleIssuesDetected.length > 1) {
      return ConversationResponse(
        message: '''${_localize(
          'I can see you\'re dealing with multiple problems! 😟 That must be really frustrating.',
          'मैं देख सकता हूं कि आप कई समस्याओं से निपट रहे हैं! 😟 यह वास्तव में निराशाजनक होना चाहिए।',
          'હું જોઈ શકું છું કે તમે અનેક સમસ્યાઓ સાથે વ્યવહાર કરી રહ્યા છો! 😟 તે ખરેખર નિરાશાજનક હોવું જોઈએ।',
          'Main dekh sakta hun ki aap kai problems se deal kar rahe hain! 😟 Ye bahut frustrating hoga.'
        )}

${_localize(
          'You mentioned:',
          'आपने उल्लेख किया:',
          'તમે ઉલ્લેખ કર્યો:',
          'Aapne mention kiya:'
        )}
${multipleIssuesDetected.map((issue) => '• ${issue['emoji']} ${issue['name']}').join('\n')}

${_localize(
          'To help you better, let\'s handle one issue at a time so each gets the attention it deserves. Which one is bothering you the most right now?',
          'आपकी बेहतर मदद के लिए, आइए एक समय में एक मुद्दे को संभालते हैं ताकि प्रत्येक को वह ध्यान मिले जिसका वह हकदार है। अभी आपको कौन सा सबसे ज्यादा परेशान कर रहा है?',
          'તમને વધુ સારી રીતે મદદ કરવા માટે, ચાલો એક સમયે એક મુદ્દાને હેન્ડલ કરીએ જેથી દરેકને તે ધ્યાન મળે જેનો તે હકદાર છે। અત્યારે તમને કયો સૌથી વધુ પરેશાન કરી રહ્યો છે?',
          'Aapki better help ke liye, ek time mein ek issue handle karte hain. Abhi sabse zyada kya pareshan kar raha hai?'
        )}''',
        buttons: multipleIssuesDetected.map((issue) => '${issue['emoji']} ${issue['name']}').toList(),
        suggestions: [
          _localize('The most urgent one', 'सबसे जरूरी वाला', 'સૌથી તાત્કાલિક', 'Sabse urgent wala'),
          _localize('All are equally important', 'सभी समान रूप से महत्वपूर्ण हैं', 'બધા સમાન રીતે મહત્વપૂર્ણ છે', 'Sab equally important hain')
        ],
        step: 'category',
        showInput: true,
        inputPlaceholder: _localize('Which one first?', 'पहले कौन सा?', 'પહેલા કયો?', 'Pehle kaun sa?'),
      );
    }

    final availableCategories = _getCategories();
    if (_strictBackendTaxonomy && availableCategories.isEmpty) {
      return ConversationResponse(
        message: _localize(
          'Backend categories are not available right now. Please retry.',
          'बैकएंड कैटेगरी अभी उपलब्ध नहीं हैं। कृपया फिर कोशिश करें।',
          'બેકએન્ડ કેટેગરી હાલ ઉપલબ્ધ નથી. કૃપા કરીને ફરી પ્રયાસ કરો.',
          'Backend categories abhi available nahi hain. Please retry karo.',
        ),
        buttons: [_localize('Retry', 'फिर कोशिश करें', 'ફરી પ્રયાસ કરો', 'Retry')],
        suggestions: [],
        step: 'category',
        showInput: true,
      );
    }

    final detectedCategory = await _detectCategoryWithAI(userInput);
    
    if (detectedCategory != null) {
      _complaintData['category'] = detectedCategory['name'];
      _complaintData['category_key'] = detectedCategory['key'];
      _complaintData['category_emoji'] = detectedCategory['emoji'];
      _complaintData['raw_description'] = userInput;

      final detectedSubcategory = await _detectSubcategoryForCategory(
        detectedCategory['key']!,
        userInput,
      );
      final looksDetailedComplaint = _looksLikeDetailedComplaint(userInput);
      if (detectedSubcategory != null) {
        _complaintData['subcategory_display'] = detectedSubcategory;
        _complaintData['subcategory'] = _normalizeSubcategoryToEnglish(
          detectedCategory['key']!,
          detectedSubcategory,
        );
      }

      if (looksDetailedComplaint && detectedSubcategory != null) {
        _currentStep = 'problem';
        final problemResponse = await _handleProblemDescription(userInput);
        return ConversationResponse(
          message: '''${detectedCategory['emoji']} ${_localize(
            'I understood your full complaint and matched it to **${detectedCategory['name']} → ${_complaintData['subcategory_display']}**.',
            'मैंने आपकी पूरी शिकायत समझ ली और उसे **${detectedCategory['name']} → ${_complaintData['subcategory_display']}** से मैच कर दिया है।',
            'મેં તમારી સંપૂર્ણ ફરિયાદ સમજી લીધી અને તેને **${detectedCategory['name']} → ${_complaintData['subcategory_display']}** સાથે મેચ કરી છે.',
            'Maine aapki full complaint samajh li aur use **${detectedCategory['name']} → ${_complaintData['subcategory_display']}** se match kar diya hai.',
          )}\n\n${problemResponse.message}''',
          buttons: problemResponse.buttons,
          suggestions: problemResponse.suggestions,
          step: problemResponse.step,
          showInput: problemResponse.showInput,
          inputPlaceholder: problemResponse.inputPlaceholder,
          complaintData: problemResponse.complaintData,
          urgencyLevel: problemResponse.urgencyLevel,
          estimatedResolutionTime: problemResponse.estimatedResolutionTime,
          aiInsights: problemResponse.aiInsights,
        );
      }
      
      _currentStep = 'subcategory';
      
      final subs = _getSubcategories(detectedCategory['key']!);
      if (_strictBackendTaxonomy && subs.isEmpty) {
        return ConversationResponse(
          message: _localize(
            'Subcategories for this category are missing in backend. Please contact admin.',
            'इस कैटेगरी की सबकैटेगरी बैकएंड में उपलब्ध नहीं है। कृपया एडमिन से संपर्क करें।',
            'આ કેટેગરી માટે સબકેટેગરી બેકએન્ડમાં ઉપલબ્ધ નથી. કૃપા કરીને એડમિનનો સંપર્ક કરો.',
            'Is category ki subcategories backend mein available nahi hain. Please admin se contact karo.',
          ),
          buttons: [_localize('Choose Another Category', 'दूसरी कैटेगरी चुनें', 'બીજી કેટેગરી પસંદ કરો', 'Choose Another Category')],
          suggestions: [],
          step: 'category',
          showInput: true,
        );
      }
      
      String empathyNote = '';
      if (_urgencyScore > 0.7) {
        empathyNote = '\n\n${_localize(
          'I can sense this is urgent. Don\'t worry, I\'ll make sure this gets priority attention! 🚨',
          'मैं समझ सकता हूं कि यह जरूरी है। चिंता मत करो, मैं यह सुनिश्चित करूंगा कि इसे प्राथमिकता मिले! 🚨',
          'હું સમજી શકું છું કે આ તાત્કાલિક છે. ચિંતા કરશો નહીં, હું ખાતરી કરીશ કે આને પ્રાથમિકતા મળે! 🚨',
          'Main samajh sakta hun ki ye urgent hai. Tension mat lo, main priority attention dilwaunga! 🚨'
        )}';
      } else {
        empathyNote = '\n\n${_localize(
          'I understand, let me help you with this. 🤝',
          'मैं समझता हूं, मुझे इसमें आपकी मदद करने दें। 🤝',
          'હું સમજું છું, મને આમાં તમારી મદદ કરવા દો. 🤝',
          'Main samajh gaya, main aapki help karunga. 🤝'
        )}';
      }
      
      return ConversationResponse(
        message: '${detectedCategory['emoji']} ${_localize(
          'Got it! So this is about **${detectedCategory['name']}**.$empathyNote\n\nCould you tell me more specifically what\'s happening? This will help the right team address it quickly.',
          'समझ गया! तो यह **${detectedCategory['name']}** के बारे में है।$empathyNote\n\nक्या आप मुझे और विशेष रूप से बता सकते हैं कि क्या हो रहा है? इससे सही टीम को इसे जल्दी हल करने में मदद मिलेगी।',
          'સમજાઈ ગયું! તો આ **${detectedCategory['name']}** વિશે છે.$empathyNote\n\nશું તમે મને વધુ ખાસ કરીને કહી શકો કે શું થઈ રહ્યું છે? આ યોગ્ય ટીમને તેને ઝડપથી સંબોધવામાં મદદ કરશે.',
          'Samajh gaya! To ye **${detectedCategory['name']}** ke baare mein hai.$empathyNote\n\nKya aap mujhe aur detail mein bata sakte hain ki kya ho raha hai? Isse right team ko jaldi solve karne mein help milegi.'
        )}',
        buttons: subs,
        suggestions: _getSmartSuggestions(detectedCategory['key']!),
        step: 'subcategory',
        showInput: true,
        inputPlaceholder: _localize('What exactly is the problem?', 'वास्तव में समस्या क्या है?', 'ખરેખર સમસ્યા શું છે?', 'Exactly kya problem hai?'),
        urgencyLevel: _getUrgencyLevel(),
      );
    } else {
      _complaintData['category_retry'] = true;
      
      if (_retryCount > 2) {
        final allCategories = _getCategories();
        return ConversationResponse(
          message: _localize(
            'No worries! Let me show you all the categories we handle. Just pick the one that matches your issue best:',
            'कोई चिंता नहीं! मुझे आपको सभी श्रेणियां दिखाने दें जिन्हें हम संभालते हैं। बस उस एक को चुनें जो आपकी समस्या से सबसे अच्छा मेल खाता है:',
            'કોઈ ચિંતા નહીં! મને તમને બધી કેટેગરીઓ બતાવવા દો જે અમે હેન્ડલ કરીએ છીએ. ફક્ત તે એક પસંદ કરો જે તમારી સમસ્યા સાથે શ્રેષ્ઠ મેળ ખાય છે:',
            'Koi tension nahi! Main aapko sab categories dikhata hun jo hum handle karte hain. Bas wo select karo jo aapki problem se match kare:'
          ),
          buttons: allCategories.map((c) => '${c['emoji']} ${c['name']}').toList(),
          suggestions: [],
          step: 'category',
          showInput: true,
        );
      }
      
      final someCategories = _getCategories().take(6).toList();
      return ConversationResponse(
        message: '''${_localize(
          'I want to make sure I understand you correctly! 😊',
          'मैं यह सुनिश्चित करना चाहता हूं कि मैं आपको सही तरीके से समझूं! 😊',
          'હું ખાતરી કરવા માંગું છું કે હું તમને યોગ્ય રીતે સમજું! 😊',
          'Main sure karna chahta hun ki main aapko sahi se samjhun! 😊'
        )}

${_localize(
          'Could you describe it a bit differently? For example:',
          'क्या आप इसे थोड़ा अलग तरीके से बता सकते हैं? उदाहरण के लिए:',
          'શું તમે તેને થોડી અલગ રીતે વર્ણવી શકો છો? ઉદાહરણ તરીકે:',
          'Kya aap ise thoda alag tarike se bata sakte hain? Example ke liye:'
        )}
• "${_localize('There\'s a big pothole on Main Street', 'मेन स्ट्रीट पर एक बड़ा गड्ढा है', 'મેઈન સ્ટ્રીટ પર મોટો ખાડો છે', 'Main Street pe bada khada hai')}"
• "${_localize('We haven\'t had water since yesterday', 'कल से पानी नहीं आया', 'ગઈકાલથી પાણી આવ્યું નથી', 'Kal se paani nahi aaya')}"
• "${_localize('The street light near the park is broken', 'पार्क के पास की स्ट्रीट लाइट टूटी है', 'પાર્ક પાસેની સ્ટ્રીટ લાઇટ તૂટી ગઈ છે', 'Park ke paas ki street light toot gayi')}"

${_localize('Or just pick from these common issues:', 'या इन सामान्य मुद्दों में से चुनें:', 'અથવા આ સામાન્ય મુદ્દાઓમાંથી પસંદ કરો:', 'Ya in common issues mein se choose karo:')}''',
        buttons: someCategories.map((c) => '${c['emoji']} ${c['name']}').toList(),
        suggestions: [
          _localize('Road is damaged', 'सड़क खराब है', 'રસ્તો ખરાબ છે', 'Sadak kharab hai'),
          _localize('Water problem', 'पानी की समस्या', 'પાણીની સમસ્યા', 'Paani ki problem'),
          _localize('Electricity issue', 'बिजली की समस्या', 'વીજળીની સમસ્યા', 'Bijli ki problem')
        ],
        step: 'category',
        showInput: true,
      );
    }
  }

  /// Step 3: Subcategory selection with multi-language support
  Future<ConversationResponse> _handleSubcategorySelection(String userInput) async {
    final categoryKey = _complaintData['category_key'] as String?;
    final looksDetailedComplaint = _looksLikeDetailedComplaint(userInput);
    
    String? matchedSub;
    if (categoryKey != null) {
      matchedSub = await _detectSubcategoryForCategory(categoryKey, userInput);
    }

    if (categoryKey != null && matchedSub == null && looksDetailedComplaint) {
      _complaintData['raw_description'] = userInput;
      final subs = _getSubcategories(categoryKey);
      if (_strictBackendTaxonomy && subs.isEmpty) {
        return ConversationResponse(
          message: _localize(
            'No backend subcategories found for the selected category. Please choose another category.',
            'चयनित कैटेगरी के लिए बैकएंड सबकैटेगरी नहीं मिली। कृपया दूसरी कैटेगरी चुनें।',
            'પસંદ કરેલી કેટેગરી માટે બેકએન્ડ સબકેટેગરી મળી નથી. કૃપા કરીને બીજી કેટેગરી પસંદ કરો.',
            'Selected category ke liye backend subcategories nahi mili. Please dusri category choose karo.',
          ),
          buttons: [_localize('Back to Categories', 'कैटेगरी पर वापस जाएं', 'કેટેગરી પર પાછા જાઓ', 'Back to Categories')],
          suggestions: [],
          step: 'category',
          showInput: true,
        );
      }
      return ConversationResponse(
        message: _localize(
          'I understood the complaint details, but I still need the closest issue type before I save it correctly. Please choose the best matching subcategory.',
          'मैंने शिकायत का विवरण समझ लिया है, लेकिन सही तरीके से सेव करने से पहले मुझे सबसे नज़दीकी समस्या प्रकार चाहिए। कृपया सही सबकैटेगरी चुनें।',
          'મેં ફરિયાદની વિગત સમજી લીધી છે, પરંતુ તેને યોગ્ય રીતે સેવ કરતા પહેલા મને સૌથી નજીકનો પ્રશ્ન પ્રકાર જોઈએ. કૃપા કરીને યોગ્ય સબકેટેગરી પસંદ કરો.',
          'Maine complaint detail samajh li hai, lekin sahi save karne se pehle mujhe closest issue type chahiye. Please best subcategory choose karo.',
        ),
        buttons: subs,
        suggestions: subs.take(3).toList(),
        step: 'subcategory',
        showInput: true,
        inputPlaceholder: _localize(
          'Choose or type the closest issue type...',
          'सबसे नज़दीकी समस्या प्रकार चुनें या लिखें...',
          'સૌથી નજીકનો પ્રશ્ન પ્રકાર પસંદ કરો અથવા લખો...',
          'Closest issue type choose ya type karo...',
        ),
      );
    }

    final chosenSubcategory = matchedSub ?? userInput;
    _complaintData['subcategory_display'] = chosenSubcategory;
    _complaintData['subcategory'] = categoryKey != null
        ? _normalizeSubcategoryToEnglish(categoryKey, chosenSubcategory)
        : chosenSubcategory;

    if (categoryKey != null &&
        matchedSub != null &&
        looksDetailedComplaint) {
      _currentStep = 'problem';
      final problemResponse = await _handleProblemDescription(userInput);
      return ConversationResponse(
        message: '''${_localize(
          'I picked **${_complaintData['subcategory_display']}** from your full problem and added your description too.',
          'मैंने आपकी पूरी समस्या से **${_complaintData['subcategory_display']}** चुना है और विवरण भी जोड़ दिया है।',
          'મેં તમારી સંપૂર્ણ સમસ્યામાંથી **${_complaintData['subcategory_display']}** પસંદ કર્યું છે અને વિગત પણ ઉમેરી છે.',
          'Maine aapki full problem se **${_complaintData['subcategory_display']}** choose kiya hai aur detail bhi add kar di hai.',
        )}\n\n${problemResponse.message}''',
        buttons: problemResponse.buttons,
        suggestions: problemResponse.suggestions,
        step: problemResponse.step,
        showInput: problemResponse.showInput,
        inputPlaceholder: problemResponse.inputPlaceholder,
        complaintData: problemResponse.complaintData,
        urgencyLevel: problemResponse.urgencyLevel,
        estimatedResolutionTime: problemResponse.estimatedResolutionTime,
        aiInsights: problemResponse.aiInsights,
      );
    }

    _currentStep = 'problem';
    
    final smartQuestions = _getSmartQuestions(categoryKey ?? '');
    
    return ConversationResponse(
      message: '''${_localize(
        'Perfect! So it\'s **${_complaintData['subcategory_display'] ?? _complaintData['subcategory']}**. I\'ve got that noted down. ✅',
        'बिल्कुल सही! तो यह **${_complaintData['subcategory_display'] ?? _complaintData['subcategory']}** है। मैंने इसे नोट कर लिया है। ✅',
        'પરફેક્ટ! તો તે **${_complaintData['subcategory_display'] ?? _complaintData['subcategory']}** છે. મેં તે નોંધ્યું છે. ✅',
        'Perfect! To ye **${_complaintData['subcategory_display'] ?? _complaintData['subcategory']}** hai. Maine note kar liya hai. ✅'
      )}

${_localize(
        'Now, to help the team understand the situation better, could you share some details? Things like:',
        'अब, टीम को स्थिति को बेहतर ढंग से समझने में मदद करने के लिए, क्या आप कुछ विवरण साझा कर सकते हैं? जैसे कि:',
        'હવે, ટીમને પરિસ્થિતિને વધુ સારી રીતે સમજવામાં મદદ કરવા માટે, શું તમે કેટલીક વિગતો શેર કરી શકો છો? જેવી કે:',
        'Ab, team ko situation better samjhane ke liye, kya aap kuch details share kar sakte hain? Jaise ki:'
      )}

$smartQuestions

${_localize(
        'The more you tell me, the faster they can fix it! 🔧',
        'आप जितना अधिक बताएंगे, वे उतनी ही तेजी से इसे ठीक कर सकेंगे! 🔧',
        'તમે જેટલું વધુ કહેશો, તેટલી ઝડપથી તેઓ તેને ઠીક કરી શકશે! 🔧',
        'Aap jitna zyada batayenge, utni jaldi wo fix kar sakte hain! 🔧'
      )}''',
      buttons: [],
      suggestions: _getDetailedSuggestions(categoryKey ?? ''),
      step: 'problem',
      showInput: true,
      inputPlaceholder: _localize('Describe what you see...', 'आप जो देख रहे हैं उसका वर्णन करें...', 'તમે જે જુઓ છો તેનું વર્ણન કરો...', 'Jo dekh rahe hain uska description do...'),
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 4: Problem description with validation - Multi-language support
  Future<ConversationResponse> _handleProblemDescription(String userInput) async {
    final normalizedInput = userInput.trim().replaceAll(RegExp(r'\s+'), ' ');
    final detailError = _getDescriptionQualityError(normalizedInput);
    if (detailError != null) {
      _aiContext['validation_error'] = detailError;
      return ConversationResponse(
        message: '''${_localize(
          'I hear you! Could you tell me a bit more about it? 😊',
          'मैं सुन रहा हूं! क्या आप इसके बारे में थोड़ा और बता सकते हैं? 😊',
          'હું સાંભળું છું! શું તમે તેના વિશે થોડું વધુ કહી શકો છો? 😊',
          'Main sun raha hun! Kya aap iske baare mein thoda aur bata sakte hain? 😊'
        )}

${_localize(
          'The more details you share, the better I can help get this resolved quickly!',
          'आप जितनी अधिक जानकारी साझा करेंगे, उतनी ही बेहतर मैं इसे जल्दी हल करने में मदद कर सकूंगा!',
          'તમે જેટલી વધુ વિગતો શેર કરશો, તેટલી સારી રીતે હું આને ઝડપથી ઉકેલવામાં મદદ કરી શકીશ!',
          'Aap jitni zyada details share karenge, utna better main ise jaldi solve karne mein help kar sakunga!'
        )}''',
        buttons: [],
        suggestions: _getDetailedSuggestions(_complaintData['category_key'] ?? ''),
        step: 'problem',
        showInput: true,
        inputPlaceholder: _localize(
          'Write one full line with issue, place, and detail...',
          'समस्या, जगह, और विवरण के साथ एक पूरी लाइन लिखें...',
          'સમस्या, જગ્યા અને વિગત સાથે એક પૂરી લાઇન લખો...',
          'Issue, place aur detail ke saath ek full line likho...',
        ),
      );
    }
    
    final category = (_complaintData['category'] ?? '').toString();
    final subcategory = (_complaintData['subcategory'] ?? '').toString();
    if (category.isNotEmpty && subcategory.isNotEmpty) {
      final isValidDescription = await validateComplaintDescription(
        normalizedInput,
        category,
        subcategory,
      );
      if (!isValidDescription) {
        final validationReason = (_aiContext['validation_error'] ?? '').toString().trim();
        return ConversationResponse(
          message: validationReason.isNotEmpty
              ? validationReason
              : _localize(
                  'Please write at least one clear line explaining the issue properly.',
                  'कृपया समस्या को ठीक से समझाते हुए कम से कम एक साफ़ लाइन लिखें।',
                  'કૃપા કરીને સમસ્યાને સારી રીતે સમજાવતી ઓછામાં ઓછી એક સ્પષ્ટ લાઇન લખો.',
                  'Please problem ko properly explain karte hue kam se kam ek clear line likho.',
                ),
          buttons: [],
          suggestions: _getDetailedSuggestions(_complaintData['category_key'] ?? ''),
          step: 'problem',
          showInput: true,
          inputPlaceholder: _localize(
            'Explain the issue in one full line...',
            'समस्या को एक पूरी लाइन में समझाएं...',
            'સમસ્યાને એક પૂરી લાઇનમાં સમજાવો...',
            'Issue ko ek full line mein explain karo...',
          ),
        );
      }
    }

    _complaintData['description'] = normalizedInput;
    _currentStep = 'date';
    
    return ConversationResponse(
      message: '''${_localize(
        'Thank you for those details! That really helps. 👍',
        'उन विवरणों के लिए धन्यवाद! यह वास्तव में मदद करता है। 👍',
        'તે વિગતો માટે આભાર! તે ખરેખર મદદ કરે છે. 👍',
        'Un details ke liye thank you! Ye really help karta hai. 👍'
      )}

${_localize(
        'One quick question - when did you first notice this problem?',
        'एक त्वरित प्रश्न - आपने पहली बार यह समस्या कब देखी?',
        'એક ઝડપી પ્રશ્ન - તમે આ સમસ્યા પ્રથમ વખત ક્યારે જોઈ?',
        'Ek quick question - aapne pehli baar ye problem kab dekhi?'
      )}''',
      buttons: [
        _localize('Today', 'आज', 'આજે', 'Aaj'),
        _localize('Yesterday', 'कल', 'ગઈકાલે', 'Kal'),
        _localize('2-3 days ago', '2-3 दिन पहले', '2-3 દિવસ પહેલાં', '2-3 din pehle'),
        _localize('Last week', 'पिछले सप्ताह', 'ગયા અઠવાડિયે', 'Last week'),
        _localize('More than a week ago', 'एक सप्ताह से अधिक पहले', 'એક અઠવાડિયાથી વધુ પહેલાં', 'Ek week se zyada pehle')
      ],
      suggestions: [
        _localize('This morning', 'आज सुबह', 'આજે સવારે', 'Aaj subah'),
        _localize('A few days back', 'कुछ दिन पहले', 'કેટલાક દિવસ પહેલાં', 'Kuch din pehle'),
        _localize('It\'s been weeks', 'हफ्तों से है', 'અઠવાડિયાઓથી છે', 'Hafto se hai')
      ],
      step: 'date',
      showInput: true,
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 5: Date selection - Multi-language support
  Future<ConversationResponse> _handleDateSelection(String userInput) async {
    final normalizedDate = _normalizeDateInput(userInput);
    _complaintData['date_noticed'] = normalizedDate;
    
    final duration = _calculateDuration(normalizedDate);
    if (duration > 7) {
      _urgencyScore = (_urgencyScore + 0.2).clamp(0.0, 1.0);
    }
    
    _currentStep = 'location';
    
    return ConversationResponse(
      message: '''📍 ${_localize(
        'Perfect! Where exactly is this issue?',
        'बिल्कुल सही! यह समस्या वास्तव में कहाँ है?',
        'પરફેક્ટ! આ સમસ્યા ખરેખર ક્યાં છે?',
        'Perfect! Ye problem exactly kahan hai?'
      )}

⚠️ ${_localize(
        '**Important:** Provide the complaint/incident location, NOT your personal address',
        '**महत्वपूर्ण:** शिकायत/घटना का स्थान बताएं, अपना व्यक्तिगत पता नहीं',
        '**મહત્વપૂર્ણ:** ફરિયાદ/ઘટનાનું સ્થાન આપો, તમારું વ્યક્તિગત સરનામું નહીં',
        '**Important:** Complaint/incident location batao, apna personal address nahi'
      )}

${_localize(
        'You can:',
        'आप कर सकते हैं:',
        'તમે કરી શકો છો:',
        'Aap kar sakte hain:'
      )}
• 📍 ${_localize('Share incident location', 'घटना का स्थान साझा करें', 'ઘટનાનું સ્થાન શેર કરો', 'Incident location share karo')}
• 📝 ${_localize('Type location address', 'स्थान का पता टाइप करें', 'સ્થાનનું સરનામું ટાઇપ કરો', 'Location address type karo')}
• 🏛️ ${_localize('Describe landmark', 'लैंडमार्क का वर्णन करें', 'લેન્ડમાર્કનું વર્ણન કરો', 'Landmark describe karo')}''',
      buttons: [
        '📍 ${_localize('Use Current Location', 'वर्तमान स्थान का उपयोग करें', 'વર્તમાન સ્થાન વાપરો', 'Current Location Use Karo')}',
        _localize('Type Address', 'पता टाइप करें', 'સરનામું ટાઇપ કરો', 'Address Type Karo')
      ],
      suggestions: [
        '${_localize('Near', 'के पास', 'પાસે', 'Ke paas')} ${_userCity.isNotEmpty ? _userCity : _localize('City', 'शहर', 'શહેર', 'City')} ${_localize('Station', 'स्टेशन', 'સ્ટેશન', 'Station')}',
        _localize('Main Market', 'मुख्य बाजार', 'મુખ્ય બજાર', 'Main Market'),
        _localize('Behind Hospital', 'अस्पताल के पीछे', 'હોસ્પિટલની પાછળ', 'Hospital ke peeche'),
      ],
      step: 'location',
      showInput: true,
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 6: Location input with duplicate check and department assignment - Multi-language support
  Future<ConversationResponse> _handleLocationInput(String userInput) async {
    if (userInput.length < 5 && !userInput.contains('location')) {
      return ConversationResponse(
        message: '''🤔 ${_localize(
          'More location details?',
          'और स्थान विवरण?',
          'વધુ સ્થાન વિગતો?',
          'Aur location details?'
        )}

⚠️ ${_localize(
          'Remember: Provide complaint/incident location',
          'याद रखें: शिकायत/घटना का स्थान बताएं',
          'યાદ રાખો: ફરિયાદ/ઘટનાનું સ્થાન આપો',
          'Yaad rakho: Complaint/incident location batao'
        )}

${_localize(
          '• Street name\n• Nearby landmarks\n• Area/sector',
          '• सड़क का नाम\n• आसपास के लैंडमार्क\n• क्षेत्र/सेक्टर',
          '• શેરીનું નામ\n• નજીકના લેન્ડમાર્ક\n• વિસ્તાર/સેક્ટર',
          '• Street name\n• Nearby landmarks\n• Area/sector'
        )}''',
        buttons: [
          '📍 ${_localize('Use Current Location', 'वर्तमान स्थान का उपयोग करें', 'વર્તમાન સ્થાન વાપરો', 'Current Location Use Karo')}',
          '📝 ${_localize('Enter Full Address', 'पूरा पता दर्ज करें', 'સંપૂર્ણ સરનામું દાખલ કરો', 'Full Address Enter Karo')}'
        ],
        suggestions: [
          _localize('Main Road, Sector 5', 'मेन रोड, सेक्टर 5', 'મેઈન રોડ, સેક્ટર 5', 'Main Road, Sector 5'),
          _localize('Near Hospital', 'अस्पताल के पास', 'હોસ્પિટલ પાસે', 'Hospital ke paas')
        ],
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
          message: '''⚠️ ${_localize(
            '**Duplicate Complaint Found**',
            '**डुप्लिकेट शिकायत मिली**',
            '**ડુપ્લિકેટ ફરિયાદ મળી**',
            '**Duplicate Complaint Mili**'
          )}

${duplicateInfo['message']}

${_localize(
            '**Existing Ticket:** ${duplicateInfo['masked_ticket']}\n**Status:** ${duplicateInfo['complaint_status']}\n**Reported:** ${duplicateInfo['created_at']}',
            '**मौजूदा टिकट:** ${duplicateInfo['masked_ticket']}\n**स्थिति:** ${duplicateInfo['complaint_status']}\n**रिपोर्ट किया गया:** ${duplicateInfo['created_at']}',
            '**હાલની ટિકિટ:** ${duplicateInfo['masked_ticket']}\n**સ્થિતિ:** ${duplicateInfo['complaint_status']}\n**જાણ કરવામાં આવી:** ${duplicateInfo['created_at']}',
            '**Existing Ticket:** ${duplicateInfo['masked_ticket']}\n**Status:** ${duplicateInfo['complaint_status']}\n**Report kiya gaya:** ${duplicateInfo['created_at']}'
          )}

${_localize(
            'This issue is already being handled by our team. You can track it using the ticket number above.',
            'यह मुद्दा पहले से ही हमारी टीम द्वारा संभाला जा रहा है। आप ऊपर दिए गए टिकट नंबर का उपयोग करके इसे ट्रैक कर सकते हैं।',
            'આ મુદ્દો પહેલેથી જ અમારી ટીમ દ્વારા હેન્ડલ કરવામાં આવી રહ્યો છે. તમે ઉપરના ટિકિટ નંબરનો ઉપયોગ કરીને તેને ટ્રેક કરી શકો છો.',
            'Ye issue already hamari team handle kar rahi hai. Aap upar diye gaye ticket number se track kar sakte hain.'
          )}

🤔 ${_localize(
            'Would you like to:',
            'आप क्या करना चाहेंगे:',
            'તમે શું કરવા માંગો છો:',
            'Aap kya karna chahenge:'
          )}
• ${_localize('Track the existing complaint', 'मौजूदा शिकायत को ट्रैक करें', 'હાલની ફરિયાદને ટ્રેક કરો', 'Existing complaint track karo')}
• ${_localize('Submit a different complaint', 'एक अलग शिकायत दर्ज करें', 'અલગ ફરિયાદ સબમિટ કરો', 'Alag complaint submit karo')}''',
          buttons: [
            '📋 ${_localize('Track Existing', 'मौजूदा को ट्रैक करें', 'હાલનું ટ્રેક કરો', 'Existing Track Karo')}',
            '➕ ${_localize('New Complaint', 'नई शिकायत', 'નવી ફરિયાદ', 'Nayi Complaint')}',
            '❌ ${_localize('Cancel', 'रद्द करें', 'રદ કરો', 'Cancel')}'
          ],
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
      message: '''📍 ${_localize(
        'Location noted!',
        'स्थान नोट किया गया!',
        'સ્થાન નોંધ્યું!',
        'Location note kar liya!'
      )}

📮 ${_localize(
        'Please provide full address with pincode:',
        'कृपया पिनकोड के साथ पूरा पता प्रदान करें:',
        'કૃપા કરીને પિનકોડ સાથે સંપૂર્ણ સરનામું આપો:',
        'Please pincode ke saath full address provide karo:'
      )}

${_localize(
        '• House/Building number\n• Street/Area\n• City\n• Pincode',
        '• घर/भवन संख्या\n• सड़क/क्षेत्र\n• शहर\n• पिनकोड',
        '• ઘર/બિલ્ડિંગ નંબર\n• શેરી/વિસ્તાર\n• શહેર\n• પિનકોડ',
        '• House/Building number\n• Street/Area\n• City\n• Pincode'
      )}''',
      buttons: [
        '⏭️ ${_localize('Skip (Use location only)', 'छोड़ें (केवल स्थान का उपयोग करें)', 'છોડો (ફક્ત સ્થાન વાપરો)', 'Skip (Sirf location use karo)')}'
      ],
      suggestions: [
        '123, MG Road, Ahmedabad, 380001',
        '${_localize('Near City Hospital, Sector 5, 380015', 'सिटी अस्पताल के पास, सेक्टर 5, 380015', 'સિટી હોસ્પિટલ પાસે, સેક્ટર 5, 380015', 'City Hospital ke paas, Sector 5, 380015')}',
      ],
      step: 'address',
      showInput: true,
      inputPlaceholder: _localize('Full address with pincode...', 'पिनकोड के साथ पूरा पता...', 'પિનકોડ સાથે સંપૂર્ણ સરનામું...', 'Pincode ke saath full address...'),
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 7: Full address input - Multi-language support
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
    String photoMessage = '''📸 ${_localize(
      'Would you like to add a photo?',
      'क्या आप एक फोटो जोड़ना चाहेंगे?',
      'શું તમે ફોટો જોડવા માંગો છો?',
      'Kya aap ek photo add karna chahenge?'
    )}

✨ ${_localize(
      'Photos help:',
      'फोटो मदद करते हैं:',
      'ફોટો મદદ કરે છે:',
      'Photos help karte hain:'
    )}''';
    
    // Add department info if assigned
    if (_complaintData.containsKey('assigned_department')) {
      photoMessage = '''✅ ${_localize(
        '**Location Confirmed**',
        '**स्थान पुष्टि की गई**',
        '**સ્થાન કન્ફર્મ કર્યું**',
        '**Location Confirm Ho Gaya**'
      )}

📍 ${_localize(
        'Your complaint will be assigned to:',
        'आपकी शिकायत इसे सौंपी जाएगी:',
        'તમારી ફરિયાદ આને અસાઇન કરવામાં આવશે:',
        'Aapki complaint ise assign hogi:'
      )}
🏛️ **${_complaintData['assigned_department']}**
📞 ${_localize('Contact', 'संपर्क', 'સંપર્ક', 'Contact')}: ${_complaintData['department_phone']}
⏱️ ${_localize('Expected resolution', 'अपेक्षित समाधान', 'અપેક્ષિત સमाधाન', 'Expected resolution')}: ${_complaintData['sla_hours']} ${_localize('hours', 'घंटे', 'કલાક', 'hours')}

---

📸 ${_localize(
        'Would you like to add a photo?',
        'क्या आप एक फोटो जोड़ना चाहेंगे?',
        'શું તમે ફોટો જોડવા માંગો છો?',
        'Kya aap ek photo add karna chahenge?'
      )}

✨ ${_localize(
        'Photos help:',
        'फोटो मदद करते हैं:',
        'ફોટો મદદ કરે છે:',
        'Photos help karte hain:'
      )}''';
    }
    
    switch (categoryKey) {
      case 'police':
        photoMessage += '''\nâ€¢ ${_localize('Item bill or ownership proof', 'वस्तु का बिल या स्वामित्व प्रमाण', 'વસ્તુનું બિલ અથવા માલિકીનો પુરાવો', 'Item bill ya ownership proof')}
â€¢ ${_localize('Theft location or damaged lock photo', 'चोरी की जगह या टूटे ताले की फोटो', 'ચોરીની જગ્યા અથવા તૂટેલા તાળાની ફોટો', 'Theft location ya toote tale ki photo')}
â€¢ ${_localize('Chat screenshot, CCTV still, or suspect photo', 'चैट स्क्रीनशॉट, CCTV स्टिल, या संदिग्ध की फोटो', 'ચેટ સ્ક્રીનશોટ, CCTV સ્ટિલ, અથવા શંકાસ્પદની ફોટો', 'Chat screenshot, CCTV still, ya suspect photo')}''';
        break;
      case 'cyber':
        photoMessage += '''\nâ€¢ ${_localize('Fraud chat, email, or website screenshot', 'फ्रॉड चैट, ईमेल, या वेबसाइट का स्क्रीनशॉट', 'ફ્રોડ ચેટ, ઇમેઇલ, અથવા વેબસાઇટનો સ્ક્રીનશોટ', 'Fraud chat, email, ya website screenshot')}
â€¢ ${_localize('Payment, UPI, or order screenshot', 'पेमेंट, UPI, या ऑर्डर का स्क्रीनशॉट', 'પેમેન્ટ, UPI, અથવા ઓર્ડરનો સ્ક્રીનશોટ', 'Payment, UPI, ya order screenshot')}
â€¢ ${_localize('Complaint reference or account proof', 'शिकायत रेफरेंस या अकाउंट प्रूफ', 'ફરિયાદ રેફરન્સ અથવા અકાઉન્ટ પ્રૂફ', 'Complaint reference ya account proof')}''';
        break;
      case 'other':
        photoMessage += '''\nâ€¢ ${_localize('Relevant screenshot or notice', 'संबंधित स्क्रीनशॉट या नोटिस', 'સંબંધિત સ્ક્રીનશોટ અથવા નોટિસ', 'Relevant screenshot ya notice')}
â€¢ ${_localize('Bill, receipt, or product photo', 'बिल, रसीद, या प्रोडक्ट फोटो', 'બિલ, રસીદ, અથવા પ્રોડક્ટ ફોટો', 'Bill, receipt, ya product photo')}
â€¢ ${_localize('Location photo or damaged item', 'लोकेशन फोटो या खराब वस्तु', 'લોકેશન ફોટો અથવા નુકસાન થયેલી વસ્તુ', 'Location photo ya damaged item')}''';
        break;
      case 'water':
        photoMessage += '''\nâ€¢ ${_localize('Leakage or dirty water photo', 'लीकेज या गंदे पानी की फोटो', 'લીકેજ અથવા ગંદા પાણીની ફોટો', 'Leakage ya gande paani ki photo')}
â€¢ ${_localize('Pipe, tanker, or affected area photo', 'पाइप, टैंकर, या प्रभावित क्षेत्र की फोटो', 'પાઇપ, ટેન્કર, અથવા અસરગ્રસ્ત વિસ્તારની ફોટો', 'Pipe, tanker, ya affected area photo')}
â€¢ ${_localize('Meter or bill photo if relevant', 'जरूरत हो तो मीटर या बिल की फोटो', 'જરૂર હોય તો મીટર અથવા બિલની ફોટો', 'Meter ya bill ki photo agar relevant ho')}''';
        break;
      case 'electricity':
        photoMessage += '''\nâ€¢ ${_localize('Pole, wire, transformer, or dark streetlight photo', 'पोल, वायर, ट्रांसफॉर्मर, या बंद स्ट्रीट लाइट की फोटो', 'પોલ, વાયર, ટ્રાન્સફોર્મર, અથવા બંધ સ્ટ્રીટ લાઇટની ફોટો', 'Pole, wire, transformer, ya dark street light photo')}
â€¢ ${_localize('Meter or bill photo if relevant', 'जरूरत हो तो मीटर या बिल की फोटो', 'જરૂર હોય તો મીટર અથવા બિલની ફોટો', 'Meter ya bill ki photo agar relevant ho')}
â€¢ ${_localize('Any visible safety hazard', 'कोई भी दिखाई देने वाला सुरक्षा खतरा', 'કોઈપણ દેખાતો સુરક્ષા ખતરો', 'Koi bhi visible safety hazard')}''';
        break;
      case 'road':
        photoMessage += '''\n• ${_localize('See exact damage', 'सटीक नुकसान देखें', 'સટીક નુકસાન જુઓ', 'Exact damage dekho')}
• ${_localize('Assess severity', 'गंभीरता का आकलन करें', 'ગંભીરતાનું મૂલ્યાંકન કરો', 'Severity assess karo')}
• ${_localize('Plan repairs', 'मरम्मत की योजना बनाएं', 'રિપેયરની યોજના બનાવો', 'Repair plan banao')}''';
        break;
      case 'garbage':
        photoMessage += '''\n• ${_localize('Verify situation', 'स्थिति की पुष्टि करें', 'પરિસ્થિતિની ખાતરી કરો', 'Situation verify karo')}
• ${_localize('Take action', 'कार्रवाई करें', 'કાર્રવાઈ કરો', 'Action lo')}
• ${_localize('Prevent hazards', 'खतरों से बचाव', 'ખતરાઓથી બચાવ', 'Hazards se bachao')}''';
        break;
      default:
        photoMessage += '''\n• ${_localize('Understand issue', 'समस्या को समझें', 'સમસ્યાને સમજો', 'Issue samjho')}
• ${_localize('Respond faster', 'तेजी से जवाब दें', 'ઝડપથી જવાબ આપો', 'Jaldi response do')}
• ${_localize('Resolve better', 'बेहतर समाधान', 'વધુ સારું સमाधाન', 'Better resolve karo')}''';
    }
    
    return ConversationResponse(
      message: photoMessage,
      buttons: [
        '📷 ${_localize('Take Photo', 'फोटो खींचें', 'ફોટો ખીંચો', 'Photo Khincho')}',
        '🖼️ ${_localize('Gallery', 'गैलरी', 'ગેલરી', 'Gallery')}',
        '⏭️ ${_localize('Skip', 'छोड़ें', 'છોડો', 'Skip')}'
      ],
      suggestions: [],
      step: 'photo',
      showInput: false,
      urgencyLevel: _getUrgencyLevel(),
    );
  }

  /// Step 8: Photo upload
  Future<ConversationResponse> _handlePhotoUpload(String userInput) async {
    _complaintData['has_photo'] =
        !(_isSkipResponse(userInput) || _isNegativeResponse(userInput));
    _currentStep = 'personal_details';
    return _showPersonalDetailsConfirmation();
  }

  /// Step 9: Personal details confirmation - fetch from profile first - Multi-language support
  ConversationResponse _showPersonalDetailsConfirmation() {
    _currentStep = 'personal_details';
    
    // Extract profile data
    String? name = _userProfile?['fullName'] ?? _userName;
    String? mobile = _userProfile?['mobile'];
    String? email = _userProfile?['email'];
    
    // Check what's missing
    final missingFields = <String>[];
    if (name == null || name.isEmpty) missingFields.add(_localize('Name', 'नाम', 'નામ', 'Name'));
    if (mobile == null || mobile.isEmpty) missingFields.add(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile'));
    if (email == null || email.isEmpty) missingFields.add(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email'));
    
    // If all details available, auto-fill and confirm
    if (missingFields.isEmpty) {
      _complaintData['contact_name'] = name!;
      _complaintData['contact_mobile'] = mobile!;
      _complaintData['contact_email'] = email!;
      
      return ConversationResponse(
        message: '''👤 ${_localize(
          '**Personal Details Confirmation**',
          '**व्यक्तिगत विवरण पुष्टि**',
          '**વ્યક્તિગત વિગતોની પુષ્ટિ**',
          '**Personal Details Confirmation**'
        )}

${_localize(
          'I\'ve fetched your details from profile:',
          'मैंने आपकी प्रोफाइल से विवरण प्राप्त किए हैं:',
          'મેં તમારી પ્રોફાઇલમાંથી વિગતો મેળવી છે:',
          'Maine aapki profile se details fetch ki hain:'
        )}

📛 ${_localize('**Name:**', '**नाम:**', '**નામ:**', '**Name:**')} $name
📱 ${_localize('**Mobile:**', '**मोबाइल:**', '**મોબાઇલ:**', '**Mobile:**')} $mobile
📧 ${_localize('**Email:**', '**ईमेल:**', '**ઈમેઇલ:**', '**Email:**')} $email

---

${_localize(
          'These details will be used to contact you regarding this complaint.',
          'इन विवरणों का उपयोग इस शिकायत के संबंध में आपसे संपर्क करने के लिए किया जाएगा।',
          'આ વિગતોનો ઉપયોગ આ ફરિયાદ અંગે તમારો સંપર્ક કરવા માટે કરવામાં આવશે.',
          'Ye details is complaint ke liye aapse contact karne ke liye use hongi.'
        )}''',
        buttons: [
          '✅ ${_localize('Confirm Details', 'विवरण पुष्टि करें', 'વિગતોની પુષ્ટિ કરો', 'Details Confirm Karo')}',
          '✏️ ${_localize('Edit Details', 'विवरण संपादित करें', 'વિગતો સંપાદિત કરો', 'Details Edit Karo')}'
        ],
        suggestions: [],
        step: 'personal_details',
        showInput: false,
      );
    }
    
    // If some details available, show them and ask for missing ones
    if (missingFields.length < 3) {
      String availableInfo = '';
      if (name != null && name.isNotEmpty) {
        availableInfo += '📛 ${_localize('**Name:**', '**नाम:**', '**નામ:**', '**Name:**')} $name\n';
        _complaintData['contact_name'] = name;
      }
      if (mobile != null && mobile.isNotEmpty) {
        availableInfo += '📱 ${_localize('**Mobile:**', '**मोबाइल:**', '**મોબાઇલ:**', '**Mobile:**')} $mobile\n';
        _complaintData['contact_mobile'] = mobile;
      }
      if (email != null && email.isNotEmpty) {
        availableInfo += '📧 ${_localize('**Email:**', '**ईमेल:**', '**ઈમેઇલ:**', '**Email:**')} $email\n';
        _complaintData['contact_email'] = email;
      }
      
      return ConversationResponse(
        message: '''👤 ${_localize(
          '**Personal Details**',
          '**व्यक्तिगत विवरण**',
          '**વ્યક્તિગત વિગતો**',
          '**Personal Details**'
        )}

${_localize(
          'From your profile:',
          'आपकी प्रोफाइल से:',
          'તમારી પ્રોફાઇલમાંથી:',
          'Aapki profile se:'
        )}
$availableInfo
---

📝 ${_localize(
          'Please provide missing details:',
          'कृपया गुम विवरण प्रदान करें:',
          'કૃપા કરીને ગુમ વિગતો પ્રદાન કરો:',
          'Please missing details provide karo:'
        )}
${missingFields.map((f) => '• $f').join('\n')}

${_localize(
          'Format: ${missingFields.join(', ')}',
          'प्रारूप: ${missingFields.join(', ')}',
          'ફોર્મેટ: ${missingFields.join(', ')}',
          'Format: ${missingFields.join(', ')}'
        )}
${_localize(
          'Example: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? _localize('John Doe', 'जॉन डो', 'જોન ડો', 'John Doe') : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}',
          'उदाहरण: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? _localize('जॉन डो', 'जॉन डो', 'જોન ડો', 'John Doe') : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}',
          'ઉદાહરણ: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? _localize('જોન ડો', 'जॉन डो', 'જોન ડો', 'John Doe') : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}',
          'Example: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? 'John Doe' : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}'
        )}''',
        buttons: [],
        suggestions: [],
        step: 'personal_details',
        showInput: true,
        inputPlaceholder: missingFields.join(', '),
      );
    }
    
    // If no details available, ask for all
    return ConversationResponse(
      message: '''👤 ${_localize(
        '**Personal Details Required**',
        '**व्यक्तिगत विवरण आवश्यक**',
        '**વ્યક્તિગત વિગતો જરૂરી**',
        '**Personal Details Required**'
      )}

${_localize(
        'To process your complaint, we need your contact information.',
        'आपकी शिकायत को प्रोसेस करने के लिए, हमें आपकी संपर्क जानकारी चाहिए।',
        'તમારી ફરિયાદ પર કાર્યવાહી કરવા માટે, અમને તમારી સંપર્ક માહિતીની જરૂર છે.',
        'Aapki complaint process karne ke liye, humein aapki contact information chahiye.'
      )}

📝 ${_localize(
        'Please provide:',
        'कृपया प्रदान करें:',
        'કૃપા કરીને પ્રદાન કરો:',
        'Please provide karo:'
      )}

1️⃣ ${_localize('Your full name', 'आपका पूरा नाम', 'તમારું પૂરું નામ', 'Aapka full name')}
2️⃣ ${_localize('Mobile number', 'मोबाइल नंबर', 'મોબાઇલ નંબર', 'Mobile number')}
3️⃣ ${_localize('Email address', 'ईमेल पता', 'ઈમેઇલ સરનામું', 'Email address')}

${_localize(
        'Format: Name, Mobile, Email',
        'प्रारूप: नाम, मोबाइल, ईमेल',
        'ફોર્મેટ: નામ, મોબાઇલ, ઈમેઇલ',
        'Format: Name, Mobile, Email'
      )}
${_localize(
        'Example: John Doe, 9876543210, john@email.com',
        'उदाहरण: जॉन डो, 9876543210, john@email.com',
        'ઉદાહરણ: જોન ડો, 9876543210, john@email.com',
        'Example: John Doe, 9876543210, john@email.com'
      )}''',
      buttons: [],
      suggestions: [],
      step: 'personal_details',
      showInput: true,
      inputPlaceholder: _localize('Name, Mobile, Email', 'नाम, मोबाइल, ईमेल', 'નામ, મોબાઇલ, ઈમેઇલ', 'Name, Mobile, Email'),
    );
  }

  /// Step 10: Handle personal details - Multi-language support
  Future<ConversationResponse> _handlePersonalDetails(String userInput) async {
    final hasName = _complaintData.containsKey('contact_name') &&
        _complaintData['contact_name'].toString().isNotEmpty;
    final hasMobile = _complaintData.containsKey('contact_mobile') &&
        _complaintData['contact_mobile'].toString().isNotEmpty;
    final hasEmail = _complaintData.containsKey('contact_email') &&
        _complaintData['contact_email'].toString().isNotEmpty;
    final hasAllDetails = hasName && hasMobile && hasEmail;

    if (hasAllDetails &&
        (_matchesAnyIntentPhrase(userInput, ['confirm details', 'details confirm']) ||
            _isAffirmativeResponse(userInput))) {
      _currentStep = 'summary';
      return _showEnhancedFinalSummary();
    } else if (hasAllDetails &&
        (_isEditResponse(userInput) || _isNegativeResponse(userInput))) {
      return ConversationResponse(
        message: '''✏️ ${_localize(
          '**Update Personal Details**',
          '**व्यक्तिगत विवरण अपडेट करें**',
          '**વ્યક્તિગત વિગતો અપડેટ કરો**',
          '**Personal Details Update Karo**'
        )}

${_localize(
          'Please provide your updated information:',
          'कृपया अपनी अपडेटेड जानकारी प्रदान करें:',
          'કૃપા કરીને તમારી અપડેટ કરેલી માહિતી પ્રદાન કરો:',
          'Please apni updated information provide karo:'
        )}

${_localize(
          'Format: Name, Mobile, Email',
          'प्रारूप: नाम, मोबाइल, ईमेल',
          'ફોર્મેટ: નામ, મોબાઇલ, ઈમેઇલ',
          'Format: Name, Mobile, Email'
        )}
${_localize(
          'Example: John Doe, 9876543210, john@email.com',
          'उदाहरण: जॉन डो, 9876543210, john@email.com',
          'ઉદાહરણ: જોન ડો, 9876543210, john@email.com',
          'Example: John Doe, 9876543210, john@email.com'
        )}''',
        buttons: [],
        suggestions: [],
        step: 'personal_details',
        showInput: true,
        inputPlaceholder: _localize('Name, Mobile, Email', 'नाम, मोबाइल, ईमेल', 'નામ, મોબાઇલ, ઈમેઇલ', 'Name, Mobile, Email'),
      );
    } else {
      // Parse input based on what's missing
      final parts = userInput.split(',').map((e) => e.trim()).toList();

      final missingCount = [hasName, hasMobile, hasEmail].where((has) => !has).length;
      
      if (parts.length >= missingCount) {
        int partIndex = 0;
        
        if (!hasName && partIndex < parts.length) {
          _complaintData['contact_name'] = _normalizeContactNameValue(parts[partIndex++]);
        }
        if (!hasMobile && partIndex < parts.length) {
          _complaintData['contact_mobile'] = _normalizePhoneValue(parts[partIndex++]);
        }
        if (!hasEmail && partIndex < parts.length) {
          _complaintData['contact_email'] = _normalizeEmailValue(parts[partIndex++]);
        }
        
        _currentStep = 'summary';
        return _showEnhancedFinalSummary();
      } else {
        final missingFields = <String>[];
        if (!hasName) missingFields.add(_localize('Name', 'नाम', 'નામ', 'Name'));
        if (!hasMobile) missingFields.add(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile'));
        if (!hasEmail) missingFields.add(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email'));
        
        return ConversationResponse(
          message: '''❌ ${_localize(
            '**Invalid Format**',
            '**गलत प्रारूप**',
            '**ગલત ફોર્મેટ**',
            '**Invalid Format**'
          )}

${_localize(
            'Please provide all missing details separated by commas:',
            'कृपया कॉमा से अलग किए गए सभी गुम विवरण प्रदान करें:',
            'કૃપા કરીને કોમાથી અલગ કરેલી બધી ગુમ વિગતો પ્રદાન કરો:',
            'Please comma se separate karke sab missing details provide karo:'
          )}

${_localize(
            'Missing: ${missingFields.join(', ')}',
            'गुम: ${missingFields.join(', ')}',
            'ગુમ: ${missingFields.join(', ')}',
            'Missing: ${missingFields.join(', ')}'
          )}
${_localize(
            'Format: ${missingFields.join(', ')}',
            'प्रारूप: ${missingFields.join(', ')}',
            'ફોર્મેટ: ${missingFields.join(', ')}',
            'Format: ${missingFields.join(', ')}'
          )}
${_localize(
            'Example: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? _localize('John Doe', 'जॉन डो', 'જોન ડો', 'John Doe') : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}',
            'उदाहरण: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? _localize('जॉन डो', 'जॉन डो', 'જોન ડો', 'John Doe') : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}',
            'ઉદાહરણ: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? _localize('જોન ડો', 'जॉन डो', 'જોન ડો', 'John Doe') : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}',
            'Example: ${missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? 'John Doe' : ''}${missingFields.contains(_localize('Mobile', 'मोबाइल', 'મોબાઇલ', 'Mobile')) ? (missingFields.contains(_localize('Name', 'नाम', 'નામ', 'Name')) ? ', ' : '') + '9876543210' : ''}${missingFields.contains(_localize('Email', 'ईमेल', 'ઈમેઇલ', 'Email')) ? (missingFields.length > 1 ? ', ' : '') + 'john@email.com' : ''}'
          )}''',
          buttons: [],
          suggestions: [],
          step: 'personal_details',
          showInput: true,
          inputPlaceholder: missingFields.join(', '),
        );
      }
    }
  }

  /// Step 11: Enhanced summary - Multi-language support
  ConversationResponse _showEnhancedFinalSummary() {
    _currentStep = 'confirm';
    
    final priority = _calculatePriority();
    _complaintData['priority'] = priority;
    
    final resolutionTime = _estimateResolutionTime();
    final department = _getAssignedDepartment();
    _complaintData['department'] = department;
    
    final urgencyIndicator = _urgencyScore > 0.7 ? '⚠️ ${_localize('**URGENT**', '**तात्कालिक**', '**તાત્કાલિક**', '**URGENT**')} ' : '';
    
    final summary = '''$urgencyIndicator✅ ${_localize(
      '**Complaint Summary**',
      '**शिकायत सारांश**',
      '**ફરિયાદ સારાંશ**',
      '**Complaint Summary**'
    )}

${_complaintData['category_emoji']} ${_localize('**Category:**', '**श्रेणी:**', '**કેટેગરી:**', '**Category:**')} ${_complaintData['category']}
📋 ${_localize('**Issue:**', '**समस्या:**', '**સમસ્યા:**', '**Issue:**')} ${_complaintData['subcategory_display'] ?? _complaintData['subcategory']}
📝 ${_localize('**Description:**', '**विवरण:**', '**વિવરણ:**', '**Description:**')} ${_complaintData['description']}
📅 ${_localize('**Noticed:**', '**देखा गया:**', '**જોયું:**', '**Notice kiya:**')} ${_complaintData['date_noticed']}
📍 ${_localize('**Location:**', '**स्थान:**', '**સ્થાન:**', '**Location:**')} ${_complaintData['location']}
📱 ${_localize('**Contact:**', '**संपर्क:**', '**સંપર્ક:**', '**Contact:**')} ${_complaintData['contact_mobile']}
📧 ${_localize('**Email:**', '**ईमेल:**', '**ઈમેઇલ:**', '**Email:**')} ${_complaintData['contact_email']}
📸 ${_localize('**Photo:**', '**फोटो:**', '**ફોટો:**', '**Photo:**')} ${_complaintData['has_photo'] == true ? _localize('Yes ✅', 'हाँ ✅', 'હા ✅', 'Haan ✅') : _localize('No', 'नहीं', 'નહીં', 'Nahi')}

---

🏛️ ${_localize('**Department:**', '**विभाग:**', '**વિभाગ:**', '**Department:**')} $department
⏱️ ${_localize('**Est. Resolution:**', '**अनुमानित समाधान:**', '**અનુમાનિત સमाधाન:**', '**Expected Resolution:**')} $resolutionTime
📈 ${_localize('**Priority:**', '**प्राथमिकता:**', '**પ્રાથમિકતા:**', '**Priority:**')} $priority
📊 ${_localize('**Urgency:**', '**तात्कालिकता:**', '**તાત્કાલિકતા:**', '**Urgency:**')} ${_getUrgencyLevel()}

---

🤔 ${_localize(
      'Everything correct?',
      'क्या सब कुछ सही है?',
      'શું બધું સારું છે?',
      'Sab kuch sahi hai?'
    )}''';
    
    return ConversationResponse(
      message: summary,
      buttons: [
        '✅ ${_localize('Submit', 'सबमिट करें', 'સબમિટ કરો', 'Submit Karo')}',
        '✏️ ${_localize('Edit', 'संपादित करें', 'સંપાદિત કરો', 'Edit Karo')}',
        '❌ ${_localize('Cancel', 'रद्द करें', 'રદ કરો', 'Cancel')}'
      ],
      suggestions: [],
      step: 'confirm',
      showInput: false,
      urgencyLevel: _getUrgencyLevel(),
      estimatedResolutionTime: resolutionTime,
    );
  }

  /// Step 12: Confirmation
  Future<ConversationResponse> _handleConfirmation(String userInput) async {
    final isSubmit = _isSubmitLikeResponse(userInput);
    final isEdit = _isEditResponse(userInput);
    final isCancel = _matchesAnyIntentPhrase(userInput, [
          'cancel',
          'रद्द',
          'રદ',
        ]) ||
        _isNegativeResponse(userInput);

    if (isSubmit) {
      return ConversationResponse(
        message: _localize(
          'Please tap the **Submit** button below so I can save this complaint in the backend and generate a real complaint ID.',
          'कृपया नीचे दिए गए **सबमिट** बटन पर टैप करें, ताकि मैं शिकायत को बैकएंड में सेव कर सकूं और असली शिकायत आईडी बना सकूं।',
          'કૃપા કરીને નીચેના **સબમિટ** બટન પર ટેપ કરો, જેથી હું ફરિયાદને બેકએન્ડમાં સેવ કરી શકું અને સાચી ફરિયાદ આઈડી બનાવી શકું.',
          'Please neeche wale **Submit** button pe tap karo, tabhi backend me real complaint save hogi aur asli complaint ID milegi.'
        ),
        buttons: [
          '✅ ${_localize('Submit', 'सबमिट करें', 'સબમિટ કરો', 'Submit Karo')}',
          '✏️ ${_localize('Edit', 'संपादित करें', 'સંપાદિત કરો', 'Edit Karo')}',
          '❌ ${_localize('Cancel', 'रद्द करें', 'રદ કરો', 'Cancel')}'
        ],
        suggestions: [],
        step: 'confirm',
        showInput: false,
      );
    } else if (isEdit) {
      _currentStep = 'language_selection';
      _complaintData.clear();
      _userLanguage = 'en'; // Reset language
      return ConversationResponse(
        message: '✏️ Let\'s start fresh!\n\n🌍 Please select your language first:',
        buttons: languageOptions.values
            .map((lang) => '${lang['emoji']} ${lang['native']}')
            .toList(),
        suggestions: [],
        step: 'language_selection',
        showInput: true,
      );
    }
    if (isCancel) {
      return _resetConversation();
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
        
        debugPrint('Context Analysis: ${result['reasoning']}');
        debugPrint('Detected Intent: ${result['intent']}');
        debugPrint('Detected Category: $categoryKey');
        
        if (categoryKey != null && categoryKey != 'null') {
          final matchedCategory = _findCategoryByKey(categoryKey.toString());
          if (matchedCategory != null) {
            return matchedCategory;
          }
        }
      }
    } catch (e) {
      debugPrint('Context analysis error: $e');
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
${_getCategories().map((category) => '- ${category['key']}: ${category['name']} (${category['emoji']})').join('\n')}

Examples:
- "maru bag chorai gyu chhe" → police (theft in Gujarati)
- "road ma khado chhe" → road (pothole in Gujarati)
- "pani nathi avtu" → water (no water in Gujarati)
- "light nathi" → electricity (no power in Gujarati)
- "kachra pado chhe" → garbage (garbage lying in Gujarati)

Respond with ONLY the category key from the list above.
No explanation, just the key.''';

      final response = await _callGroqAPI(prompt, maxTokens: 50, temperature: 0.1);
      
      if (response != null) {
        final categoryKey = response.trim().toLowerCase();
        
        final matchedCategory = _findCategoryByKey(categoryKey);
        if (matchedCategory != null) {
          debugPrint('Groq AI detected category: $categoryKey for input: $input');
          return matchedCategory;
        }
      }
    } catch (e) {
      debugPrint('Groq AI error: $e');
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      }
    } catch (e) {
      debugPrint('Groq API failed: $e');
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
      debugPrint('Validation error: $e');
    }
    
    return true;
  }

  String? _getDescriptionQualityError(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return _localize(
        'Please enter the complaint details.',
        'कृपया शिकायत का विवरण दर्ज करें।',
        'કૃપા કરીને ફરિયાદની વિગતો લખો.',
        'Please complaint details likho.',
      );
    }

    if (normalized.length < 12) {
      return _localize(
        'Please add at least one full line of details.',
        'कृपया कम से कम एक पूरी लाइन का विवरण जोड़ें।',
        'કૃપા કરીને ઓછામાં ઓછી એક પૂરી લાઇનની વિગત ઉમેરો.',
        'Please kam se kam ek full line detail add karo.',
      );
    }

    final words = normalized
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.length < 3) {
      return _localize(
        'Please describe the issue in a meaningful sentence, not just a few words.',
        'कृपया समस्या को एक अर्थपूर्ण वाक्य में बताएं, केवल कुछ शब्दों में नहीं।',
        'કૃપા કરીને સમસ્યાને થોડા શબ્દોમાં નહીં પરંતુ અર્થપૂર્ણ વાક્યમાં લખો.',
        'Please issue ko sirf kuch words mein nahi, meaningful sentence mein likho.',
      );
    }

    if (_looksLikeGibberish(normalized)) {
      return _localize(
        'Random letters are not enough. Please explain the real issue clearly.',
        'रैंडम अक्षर पर्याप्त नहीं हैं। कृपया असली समस्या को साफ़ लिखें।',
        'રેન્ડમ અક્ષરો પૂરતા નથી. કૃપા કરીને સાચી સમસ્યાને સ્પષ્ટ લખો.',
        'Random letters enough nahi hain. Please real issue ko clear likho.',
      );
    }

    return null;
  }

  bool _looksLikeGibberish(String input) {
    final normalized = input.trim();
    final latinWords = normalized
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'[^A-Za-z]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();

    if (latinWords.isEmpty) {
      return false;
    }

    final hasMeaningfulWord = latinWords.any((word) => word.length >= 4);
    if (!hasMeaningfulWord) {
      return true;
    }

    final vowelFreeLongWords = latinWords.where(
      (word) => word.length >= 6 && !RegExp(r'[aeiouAEIOU]').hasMatch(word),
    );
    if (vowelFreeLongWords.isNotEmpty) {
      return true;
    }

    if (latinWords.length == 1 && latinWords.first.length >= 6) {
      return true;
    }

    final uniqueWords = latinWords.map((word) => word.toLowerCase()).toSet();
    if (uniqueWords.length == 1 && latinWords.length >= 2) {
      return true;
    }

    return false;
  }

  /// Detect multiple issues in user input
  List<Map<String, String>>? _detectMultipleIssues(String input) {
    final lower = input.toLowerCase();
    final detectedCategories = <Map<String, String>>[];
    
    for (final category in _getCategories()) {
      final key = (category['key'] ?? '').toString();
      if (key.isEmpty) continue;
      final keywords = _getCategoryKeywords(key);
      
      for (var keyword in keywords) {
        if (lower.contains(keyword)) {
          if (!detectedCategories.any((c) => c['key'] == key)) {
            detectedCategories.add({
              'key': key,
              'name': (category['name'] ?? key).toString(),
              'emoji': (category['emoji'] ?? '📝').toString(),
            });
          }
          break;
        }
      }
    }
    
    return detectedCategories.length > 1 ? detectedCategories : null;
  }
  
  /// Get keywords for category detection
  List<String> _getCategoryKeywords(String categoryKey) {
    final dynamicKeywords = <String>{};
    final categoryMeta = _getCategories().firstWhere(
      (category) => category['key'] == categoryKey,
      orElse: () => const <String, String>{},
    );
    final categoryName = (categoryMeta['name'] ?? '').toString().trim();
    if (categoryName.isNotEmpty) {
      dynamicKeywords.add(_normalizeTextForMatching(categoryName));
      for (final token in _extractMeaningfulTokens(categoryName)) {
        dynamicKeywords.add(token);
      }
    }
    for (final subcategory in _getSubcategories(categoryKey)) {
      final normalizedSubcategory = _normalizeTextForMatching(subcategory);
      if (normalizedSubcategory.isNotEmpty) {
        dynamicKeywords.add(normalizedSubcategory);
      }
      for (final token in _extractMeaningfulTokens(subcategory)) {
        dynamicKeywords.add(token);
      }
    }

    switch (categoryKey) {
      case 'road':
        dynamicKeywords.addAll(['road', 'pothole', 'khado', 'sadak', 'rasta', 'street']);
        break;
      case 'water':
        dynamicKeywords.addAll(['water', 'pani', 'paani', 'tap', 'supply']);
        break;
      case 'electricity':
        dynamicKeywords.addAll(['electricity', 'power', 'light', 'bijli', 'current']);
        break;
      case 'garbage':
        dynamicKeywords.addAll(['garbage', 'trash', 'kachra', 'waste', 'dustbin']);
        break;
      case 'drainage':
        dynamicKeywords.addAll(['drain', 'sewage', 'nali', 'gutter']);
        break;
      case 'traffic':
        dynamicKeywords.addAll(['traffic', 'signal', 'jam']);
        break;
      case 'police':
        dynamicKeywords.addAll(['police', 'theft', 'stolen', 'chorai', 'chori', 'robbery']);
        break;
      case 'construction':
        dynamicKeywords.addAll(['construction', 'building']);
        break;
      case 'cyber':
        dynamicKeywords.addAll(['cyber', 'fraud', 'scam', 'hacked']);
        break;
      default:
        dynamicKeywords.add(_normalizeTextForMatching(categoryKey));
        break;
    }
    return dynamicKeywords.where((keyword) => keyword.trim().isNotEmpty).toList();
  }

  List<String> _extractMeaningfulTokens(String input) {
    final normalized = _normalizeTextForMatching(input);
    if (normalized.isEmpty) return const <String>[];
    return normalized
        .split(RegExp(r'[^a-z0-9\u0900-\u097F\u0A80-\u0AFF]+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 3)
        .toList();
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
    final normalizedInput = _normalizeTextForMatching(input);

    final categoryScores = <String, int>{};
    for (final category in _getCategories()) {
      final key = (category['key'] ?? '').toString().trim();
      final name = (category['name'] ?? '').toString().trim();
      if (key.isEmpty) continue;

      var score = 0;
      final normalizedKey = _normalizeTextForMatching(key);
      final normalizedName = _normalizeTextForMatching(name);

      if (normalizedKey.isNotEmpty && normalizedInput.contains(normalizedKey)) {
        score += 5;
      }
      if (normalizedName.isNotEmpty) {
        if (normalizedInput == normalizedName) {
          score += 8;
        } else if (normalizedInput.contains(normalizedName) ||
            normalizedName.contains(normalizedInput)) {
          score += 5;
        }
      }

      for (final keyword in _getCategoryKeywords(key)) {
        final normalizedKeyword = _normalizeTextForMatching(keyword);
        if (normalizedKeyword.isEmpty) continue;
        if (normalizedInput == normalizedKeyword) {
          score += 6;
        } else if (normalizedInput.contains(normalizedKeyword)) {
          score += 2;
        }
      }

      if (score > 0) {
        categoryScores[key] = score;
      }
    }

    if (categoryScores.isNotEmpty) {
      final bestEntry = categoryScores.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      if (bestEntry.value >= 4) {
        final bestCategory = _findCategoryByKey(bestEntry.key);
        if (bestCategory != null) {
          return bestCategory;
        }
      }
    }

    if (_strictBackendTaxonomy) {
      return null;
    }
    
    // Check each category for matches
    for (var entry in categories.entries) {
      final key = entry.key;
      final category = entry.value;
      
      // Check key and all language names
      if (lower.contains(key) || 
          lower.contains(category['en']!.toLowerCase()) ||
          lower.contains(category['hi']!.toLowerCase()) ||
          lower.contains(category['gu']!.toLowerCase()) ||
          lower.contains(category['hinglish']!.toLowerCase())) {
        return {
          'key': key,
          'name': _getCategoryName(key),
          'emoji': category['emoji']!,
        };
      }
    }

    for (final category in _getCategories()) {
      final key = (category['key'] ?? '').toString();
      final name = (category['name'] ?? '').toString();
      if (key.isEmpty || name.isEmpty) continue;

      final normalizedName = _normalizeTextForMatching(name);
      if (lower.contains(key) ||
          normalizedInput.contains(normalizedName) ||
          normalizedName.contains(normalizedInput)) {
        final matched = _findCategoryByKey(key);
        if (matched != null) {
          return matched;
        }
      }
    }
    
    // Find category by key helper
    Map<String, String>? findByKey(String key) {
      return _findCategoryByKey(key);
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
    final normalizedInput = _convertDigitsToAscii(input).trim();
    final lower = normalizedInput.toLowerCase();
    final now = DateTime.now();

    String iso(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

    if (lower.contains('today') || lower.contains('आज') || lower.contains('આજે') || lower.contains('aaj')) {
      return iso(now);
    }
    if (lower.contains('yesterday') || lower.contains('कल') || lower.contains('ગઈકાલે') || lower.contains('kal')) {
      return iso(now.subtract(const Duration(days: 1)));
    }
    if (lower.contains('2-3') || lower.contains('few') || lower.contains('कुछ दिन') || lower.contains('કેટલાક દિવસ')) {
      return iso(now.subtract(const Duration(days: 3)));
    }
    if (lower.contains('last week') || lower.contains('पिछले सप्ताह') || lower.contains('ગયા અઠવાડિયે')) {
      return iso(now.subtract(const Duration(days: 7)));
    }
    if (lower.contains('week') || lower.contains('सप्ताह') || lower.contains('અઠવાડિયા') || lower.contains('haft')) {
      return iso(now.subtract(const Duration(days: 7)));
    }
    if (lower.contains('weeks') || lower.contains('हफ्तों') || lower.contains('અઠવાડિયાઓ')) {
      return iso(now.subtract(const Duration(days: 14)));
    }

    for (final fmt in ['yyyy-MM-dd', 'dd/MM/yyyy', 'd/M/yyyy', 'dd-MM-yyyy', 'd-M-yyyy', 'dd MMM yyyy', 'd MMM yyyy']) {
      try {
        final parsed = DateFormat(fmt).parseStrict(normalizedInput);
        return iso(parsed);
      } catch (_) {}
    }

    return normalizedInput;
  }

  /// Calculate duration
  int _calculateDuration(String dateStr) {
    for (final fmt in ['yyyy-MM-dd', 'dd MMM yyyy', 'dd/MM/yyyy', 'dd-MM-yyyy']) {
      try {
        final date = DateFormat(fmt).parseStrict(dateStr);
        return DateTime.now().difference(date).inDays;
      } catch (_) {}
    }
    return 1;
  }

  /// Get smart suggestions
  List<String> _getSmartSuggestions(String categoryKey) {
    final dynamicSubs = _getSubcategories(categoryKey);
    if (dynamicSubs.isNotEmpty && dynamicSubs.first != 'Other') {
      return dynamicSubs.take(3).toList();
    }

    final subs = subcategories[categoryKey];
    if (subs == null) return ['Other'];
    
    switch (_userLanguage) {
      case 'hi':
        final hiSubs = subs['hi'] ?? subs['en'] ?? ['अन्य'];
        return hiSubs.take(3).toList();
      case 'gu':
        final guSubs = subs['gu'] ?? subs['en'] ?? ['અન્ય'];
        return guSubs.take(3).toList();
      case 'hinglish':
        final hinglishSubs = subs['hinglish'] ?? subs['en'] ?? ['Other'];
        return hinglishSubs.take(3).toList();
      default:
        final enSubs = subs['en'] ?? ['Other'];
        return enSubs.take(3).toList();
    }
  }

  /// Get smart questions
  String _getSmartQuestions(String categoryKey) {
    switch (categoryKey) {
      case 'road': 
        return _localize(
          '• Location & landmarks\n• Size of damage\n• Causing accidents?\n• Traffic impact',
          '• स्थान और लैंडमार्क\n• नुकसान का आकार\n• दुर्घटना का कारण?\n• ट्रैफिक पर प्रभाव',
          '• સ્થાન અને લેન્ડમાર્ક\n• નુકસાનનો આકાર\n• અકસ્માતનો કારણ?\n• ટ્રાફિક પર અસર',
          '• Location aur landmarks\n• Damage ka size\n• Accident ho rahe hain?\n• Traffic impact'
        );
      case 'water': 
        return _localize(
          '• Your area\n• How long?\n• Many houses affected?\n• Visible leaks?',
          '• आपका क्षेत्र\n• कितने समय से?\n• कई घर प्रभावित?\n• दिखाई देने वाला रिसाव?',
          '• તમારો વિસ્તાર\n• કેટલા સમયથી?\n• કેટલાં ઘરો પ્રભાવિત?\n• દિખાઈ દેતો લીકેજ?',
          '• Aapka area\n• Kitne time se?\n• Kitne ghar affected?\n• Leak dikh raha hai?'
        );
      case 'electricity': 
        return _localize(
          '• Affected area\n• Duration\n• Safety hazards?\n• Pole/transformer number',
          '• प्रभावित क्षेत्र\n• अवधि\n• सुरक्षा खतरे?\n• पोल/ट्रांसफार्मर नंबर',
          '• પ્રભાવિત વિસ્તાર\n• અવધિ\n• સુરક્ષા ખતરા?\n• પોલ/ટ્રાન્સફોર્મર નંબર',
          '• Affected area\n• Kitni der se?\n• Safety hazard hai?\n• Pole/transformer number'
        );
      case 'garbage': 
        return _localize(
          '• Location\n• How long?\n• Type of waste\n• Health hazards?',
          '• स्थान\n• कितने समय से?\n• कचरे का प्रकार\n• स्वास्थ्य खतरे?',
          '• સ્થાન\n• કેટલા સમયથી?\n• કચરાનો પ્રકાર\n• આરોગ્યના ખતરા?',
          '• Location\n• Kitne time se?\n• Kya type ka waste?\n• Health hazard hai?'
        );
      default: 
        return _localize(
          '• Where exactly?\n• When noticed?\n• How severe?\n• Immediate risks?',
          '• कहां वास्तव में?\n• कब देखा?\n• कितना गंभीर?\n• तत्काल जोखिम?',
          '• ક્યાં વાસ્તવમાં?\n• ક્યારે દેખ્યું?\n• કેટલું ગંભીર?\n• તાત્કાલિક જોખમ?',
          '• Exactly kahan?\n• Kab notice kiya?\n• Kitna severe?\n• Immediate risk hai?'
        );
    }
  }

  /// Get detailed suggestions
  List<String> _getDetailedSuggestions(String categoryKey) {
    switch (categoryKey) {
      case 'road':
        return [
          _localize('Deep pothole causing accidents', 'दुर्घटना का कारण बनने वाला गहरा गड्ढा', 'અકસ્માતનો કારણ બનતો ગહેરો ખાડો', 'Accident ka karan banne wala gehra khada'),
          _localize('Road broken for 100 meters', '100 मीटर तक टूटी सड़क', '100 મીટર સુધી તૂટેલો રસ્તો', '100 meter tak tooti sadak'),
          _localize('Water accumulation', 'पानी का जमाव', 'પાણી જમા થવું', 'Paani jama hona')
        ];
      case 'water':
        return [
          _localize('No water for 3 days', '3 दिन से पानी नहीं', '3 દિવસથી પાણી નથી', '3 din se paani nahi'),
          _localize('Major pipe leaking', 'मुख्य पाइप में रिसाव', 'મુખ્ય પાઇપમાં લીકેજ', 'Main pipe mein leakage'),
          _localize('Very low pressure', 'बहुत कम दबाव', 'બહુ ઓછું દબાણ', 'Bahut kam pressure')
        ];
      case 'electricity':
        return [
          _localize('Daily 5+ hour cuts', 'रोजाना 5+ घंटे की कटौती', 'રોજ વધુ 5+ કલાકની કાપ', 'Roz 5+ ghante ki katouti'),
          _localize('Exposed wire hanging', 'खुला तार लटक रहा', 'ખુલ્લો વાયર લટકી રહ્યો', 'Khula wire latka hua'),
          _localize('All lights not working', 'सभी लाइटें काम नहीं कर रहीं', 'બધી લાઇટો કામ નથી કરતી', 'Saari lights kaam nahi kar rahi')
        ];
      case 'garbage':
        return [
          _localize('Not collected for week', 'एक हफ्ते से नहीं उठाया', 'એક અઠવાડિયાથી ઉપાડ્યો નથી', 'Ek hafte se nahi uthaya'),
          _localize('Bins overflowing', 'डस्टबिन भर रहे हैं', 'ડસ્ટબિન ભરાઈ ગયા છે', 'Dustbin bhar gaye hain'),
          _localize('Illegal dumping', 'अवैध कचरा फेंकना', 'ગેરકાયદેસર કચરો ફેંકવો', 'Galat jagah kachra phenkna')
        ];
      default:
        return [
          _localize('Describe in detail', 'विस्तार से बताएं', 'વિસ્તારમાં કહો', 'Detail mein batao'),
          _localize('Mention severity', 'गंभीरता का उल्लेख करें', 'ગંભીરતાનો ઉલ્લેખ કરો', 'Kitna serious hai batao'),
          _localize('Any dangers?', 'कोई खतरा?', 'કોઈ ખતરો?', 'Koi khatra hai?')
        ];
    }
  }

  /// Reset conversation
  ConversationResponse _resetConversation() {
    _currentStep = 'language_selection';
    _complaintData.clear();
    _conversationHistory.clear();
    _userLanguage = 'en'; // Reset to default
    
    return ConversationResponse(
      message: '❌ Cancelled.\n\nStart again anytime!',
      buttons: ['Start New'],
      suggestions: [],
      step: 'language_selection',
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
    _currentStep = 'language_selection';
    _complaintData.clear();
    _conversationHistory.clear();
    _retryCount = 0;
    _sentiment = 'neutral';
    _urgencyScore = 0.5;
    _aiContext.clear();
    _conversationStartTime = DateTime.now();
    _userLanguage = 'en'; // Reset to default
    _currentChatId = null;
  }
  
  /// Set the app's selected language for AI responses
  void setAppLanguage(String languageCode) {
    if (['en', 'hi', 'gu'].contains(languageCode)) {
      _userLanguage = languageCode;
      debugPrint('✅ App language set to: $languageCode');
    }
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
        Uri.parse(ApiConfig.aiCheckDuplicate),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'category': _complaintData['category'],
          'subcategory': _complaintData['subcategory'],
          'description': _complaintData['description'] ?? _complaintData['raw_description'],
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Duplicate check error: $e');
    }
    return null;
  }
  
  /// Get nearest department using backend API
  Future<Map<String, dynamic>?> _getNearestDepartment(double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.aiGetDepartment),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'category': _complaintData['category'],
          'city': _userCity,
          'state': _complaintData['state'] ?? '',
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Department lookup error: $e');
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
  
  /// Localize text based on user language (English, Hindi, Gujarati, Hinglish)
  String _localize(String en, String hi, String gu, String hinglish) {
    switch (_userLanguage) {
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
