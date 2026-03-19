from __future__ import annotations

from dataclasses import dataclass, field
from datetime import timedelta
import hashlib
import re
import threading
from typing import Any, Dict, List, Optional, Tuple

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

try:
    from google import genai as google_genai
except Exception:  # pragma: no cover
    google_genai = None

legacy_genai = None

try:
    from .ai_corpus_data import KNOWLEDGE_CORPUS
except Exception:  # pragma: no cover
    KNOWLEDGE_CORPUS = []


@dataclass
class Analysis:
    language: str
    emotion: str
    urgency: str
    is_emergency: bool
    intent: str
    category: Optional[str] = None
    subcategory: Optional[str] = None
    confidence: float = 0.0
    alternatives: List[str] = field(default_factory=list)
    signals: List[str] = field(default_factory=list)
    location_hint: Optional[str] = None
    time_hint: Optional[str] = None


class SmartCityAI:
    _sessions: Dict[str, "SmartCityAI"] = {}
    _sessions_lock = threading.Lock()
    _session_ttl = timedelta(hours=8)
    _max_sessions = 500
    _cache_prefix = "smartcity_ai_session"
    _client_lock = threading.Lock()
    _shared_client_ready = False
    _shared_genai_client = None
    _shared_legacy_model = None
    _shared_backend = "none"
    _corpus_index_lock = threading.Lock()
    _corpus_index_ready = False
    _corpus_token_index: Dict[str, List[int]] = {}

    TAXONOMY = {
        "Police Complaint": {
            "Theft / Robbery": ["theft", "robbery", "stolen", "chori", "loot"],
            "Domestic Violence": ["domestic violence", "ghar mein maarpeet", "family abuse"],
            "Missing Person": ["missing person", "laapata", "not found"],
            "Physical Assault": ["assault", "attack", "maarpeet", "beaten"],
            "Harassment / Threat": ["harassment", "threat", "blackmail", "dhamki"],
            "Property Damage": ["property damage", "vandalism", "tod phod"],
            "Drug / Narcotics": ["drug", "narcotics", "ganja", "smuggling"],
            "Fraud / Scam": ["fraud", "scam", "cheating", "dhoka"],
            "Illegal Activity": ["illegal activity", "crime", "suspicious person"],
            "Other": ["police complaint", "crime complaint", "fir"],
        },
        "Traffic Complaint": {
            "Signal Jumping": ["signal jumping", "red light cross"],
            "Wrong Side Driving": ["wrong side", "one way violation"],
            "Overspeeding": ["overspeeding", "rash driving", "fast vehicle"],
            "Illegal Parking": ["illegal parking", "wrong parking", "road blocked by parking"],
            "No Helmet / Triple Riding": ["no helmet", "triple riding"],
            "No Seatbelt": ["no seatbelt"],
            "Drunk Driving": ["drunk driving", "drink and drive"],
            "Traffic Obstruction": ["traffic obstruction", "jam", "block traffic"],
            "Heavy Vehicle Violation": ["heavy vehicle violation", "truck violation"],
            "Other": ["traffic complaint", "signal issue", "traffic problem"],
        },
        "Construction Complaint": {
            "Road Damage / Potholes": ["road damage", "pothole", "gadda", "broken road"],
            "Footpath / Sidewalk Damage": ["footpath broken", "sidewalk damage"],
            "Bridge / Flyover Issue": ["bridge issue", "flyover crack"],
            "Illegal Construction": ["illegal construction", "unauthorized building"],
            "Construction Debris": ["construction debris", "malba", "rubble"],
            "Structure Collapse Risk": ["collapse risk", "unsafe structure"],
            "Unsafe Excavation": ["unsafe excavation", "deep digging"],
            "Public Building Damage": ["public building damage"],
            "Drainage Construction Issues": ["drainage construction issue"],
            "Other": ["construction complaint", "building work issue"],
        },
        "Water Supply": {
            "No Water Supply": ["no water", "water not coming", "pani nahi aa raha"],
            "Low Water Pressure": ["low pressure", "weak flow", "kam pressure"],
            "Water Leakage": ["water leak", "pipe leak", "pani leak"],
            "Burst Water Pipeline": ["burst pipeline", "pipeline phat gaya"],
            "Dirty / Contaminated Water": ["dirty water", "contaminated water", "ganda pani"],
            "Water Tank Overflow": ["water tank overflow"],
            "Broken Water Tap": ["broken tap", "tap broken"],
            "Water Meter Problem": ["water meter issue"],
            "Water Tanker Complaint": ["water tanker complaint"],
            "Other": ["water complaint", "water supply issue"],
        },
        "Electricity": {
            "Power Outage": ["power cut", "no electricity", "bijli gayi"],
            "Frequent Power Cuts": ["frequent power cut", "light blink"],
            "Street Light Not Working": ["street light off", "pole light off"],
            "Exposed Electrical Wires": ["open wire", "exposed wire", "khuli wire"],
            "Electric Pole Damage": ["electric pole damage"],
            "Transformer Issue": ["transformer issue", "transformer blast"],
            "Electric Spark": ["electric spark", "current spark"],
            "Electricity Meter Problem": ["meter problem", "electric meter issue"],
            "Illegal Connection": ["illegal connection", "power theft"],
            "Other": ["electricity complaint", "light issue"],
        },
        "Garbage/Sanitation": {
            "Garbage Not Collected": ["garbage not collected", "kachra jama", "kooda pada"],
            "Overflowing Garbage Bin": ["overflowing bin", "dustbin full"],
            "Illegal Garbage Dumping": ["illegal dumping", "waste dumping"],
            "Dead Animal Removal": ["dead animal", "animal carcass"],
            "Garbage Burning": ["garbage burning", "kachra jalana"],
            "Public Dustbin Damage": ["dustbin damage", "bin broken"],
            "Missed Door-to-Door": ["missed collection", "door to door miss"],
            "Garbage Truck Issue": ["garbage truck issue"],
            "Construction Waste": ["construction waste", "malba"],
            "Other": ["garbage complaint", "sanitation issue"],
        },
        "Road/Pothole": {
            "Pothole on Road": ["pothole", "gadda", "hole in road"],
            "Broken Road": ["broken road", "cracked road", "sadak kharab"],
            "Water Logging on Road": ["water logging", "waterlogged road", "pani jama"],
            "Road Construction Delay": ["construction delay", "road work delay"],
            "Road Blocked by Materials": ["road blocked", "materials on road"],
            "Missing Road Markings": ["road marking missing"],
            "Speed Breaker Issue": ["speed breaker issue"],
            "Road Shoulder Damage": ["road shoulder damage"],
            "Dangerous Conditions": ["dangerous road", "unsafe road"],
            "Other": ["road complaint", "road issue"],
        },
        "Drainage/Sewage": {
            "Blocked Drain": ["drain blocked", "nali jam", "sewer blocked"],
            "Drain Overflow": ["drain overflow", "gutter overflow"],
            "Water Logging Area": ["water logging area", "pani jama area"],
            "Broken Drain Cover": ["drain cover broken"],
            "Damaged Drain Structure": ["drain structure damage"],
            "Sewage Leakage": ["sewage leakage", "ganda paani leak"],
            "Illegal Drain Connection": ["illegal drain connection"],
            "Drain Cleaning Required": ["drain cleaning required"],
            "Manhole Issue": ["manhole open", "manhole issue"],
            "Other": ["drainage complaint", "sewage issue"],
        },
        "Illegal Activities": {
            "Illegal Construction": ["illegal construction", "unauthorized building"],
            "Unauthorized Street Vendors": ["unauthorized vendor", "encroachment"],
            "Illegal Waste Dumping": ["illegal dumping", "waste dumping"],
            "Unauthorized Water Connection": ["illegal water connection"],
            "Power Theft": ["power theft", "electric theft"],
            "Illegal Parking": ["illegal parking"],
            "Illegal Advertisement": ["illegal hoarding", "illegal advertisement"],
            "Noise Pollution": ["noise pollution", "loudspeaker issue"],
            "Unauthorized Business": ["unauthorized business"],
            "Other": ["illegal activity complaint"],
        },
        "Transportation": {
            "Public Bus Issue": ["bus issue", "public bus complaint"],
            "Bus Stop Issue": ["bus stop issue"],
            "Traffic Signal Failure": ["signal failure", "signal not working"],
            "Traffic Congestion": ["traffic congestion", "traffic jam"],
            "Illegal Parking (Transport)": ["transport illegal parking"],
            "Damaged Road Sign": ["road sign damaged"],
            "Auto / Taxi Complaint": ["auto complaint", "taxi complaint"],
            "Pedestrian Crossing Issue": ["pedestrian crossing issue"],
            "Railway Crossing Issue": ["railway crossing issue"],
            "Other": ["transport complaint", "transportation issue"],
        },
        "Cyber Crime": {
            "Online Payment Fraud": ["online payment fraud", "payment scam"],
            "Phishing Scam": ["phishing", "fake link", "suspicious link"],
            "OTP / Banking Fraud": ["otp fraud", "banking fraud"],
            "Social Media Hacking": ["social media hacked", "instagram hack"],
            "Online Shopping Fraud": ["shopping fraud", "fake ecommerce"],
            "Identity Theft": ["identity theft", "data stolen"],
            "Fake Job Scam": ["fake job scam"],
            "Investment Fraud": ["investment fraud"],
            "Mobile App Fraud": ["mobile app fraud"],
            "Other": ["cyber complaint", "online fraud"],
        },
        "Other Complaint": {
            "Public Facility Issue": ["public facility issue"],
            "Animal Related Issue": ["animal issue", "stray animal"],
            "Noise Complaint": ["noise complaint", "loud noise"],
            "Public Safety Concern": ["public safety concern"],
            "Government Service Complaint": ["government service complaint"],
            "Public Park Issue": ["park issue"],
            "Public Event Disturbance": ["event disturbance"],
            "Environmental Issue": ["environment issue", "pollution issue"],
            "General Complaint": ["general complaint"],
            "Other": ["other complaint", "misc complaint"],
        },
    }

    CATEGORY_ALIASES = {
        "Police Complaint": ["police", "fir", "crime", "chori", "assault", "threat"],
        "Traffic Complaint": ["traffic", "signal", "parking", "overspeeding", "wrong side"],
        "Construction Complaint": ["construction", "building", "malba", "collapse"],
        "Water Supply": ["water", "pani", "tap", "pipeline", "leakage"],
        "Electricity": ["bijli", "light", "power", "wire", "transformer"],
        "Garbage/Sanitation": ["garbage", "kachra", "kooda", "dustbin", "waste"],
        "Road/Pothole": ["road", "sadak", "gadda", "pothole"],
        "Drainage/Sewage": ["drain", "nali", "sewer", "gutter", "manhole"],
        "Illegal Activities": ["illegal", "encroachment", "unauthorized", "power theft"],
        "Transportation": ["transport", "bus", "taxi", "auto", "road sign"],
        "Cyber Crime": ["cyber", "upi", "fraud", "phishing", "hacked"],
        "Other Complaint": ["other", "general", "misc"],
    }

    CATEGORY_SIGNAL_BOOSTS = {
        "Police Complaint": ["police", "fir", "theft", "robbery", "assault", "harassment", "threat"],
        "Cyber Crime": ["otp", "upi", "phishing", "hacked", "online scam"],
        "Traffic Complaint": ["signal jumping", "wrong side", "no helmet", "drunk driving"],
    }

    LANGUAGE_TOKEN_TRANSLATIONS = {
        "hindi": {
            "Police": "पुलिस",
            "Complaint": "शिकायत",
            "Theft": "चोरी",
            "Robbery": "डकैती",
            "Domestic": "घरेलू",
            "Violence": "हिंसा",
            "Missing": "गुम",
            "Person": "व्यक्ति",
            "Physical": "शारीरिक",
            "Assault": "हमला",
            "Harassment": "उत्पीड़न",
            "Threat": "धमकी",
            "Property": "संपत्ति",
            "Damage": "क्षति",
            "Drug": "नशा",
            "Narcotics": "नशीली दवाएं",
            "Fraud": "धोखाधड़ी",
            "Scam": "ठगी",
            "Illegal": "अवैध",
            "Activity": "गतिविधि",
            "Traffic": "यातायात",
            "Signal": "सिग्नल",
            "Jumping": "छलांग",
            "Wrong": "गलत",
            "Side": "पक्ष",
            "Driving": "ड्राइविंग",
            "Overspeeding": "अति गति",
            "Parking": "पार्किंग",
            "No": "नहीं",
            "Helmet": "हेलमेट",
            "Triple": "त्रि",
            "Riding": "सवारी",
            "Seatbelt": "सीट बेल्ट",
            "Drunk": "नशे में",
            "Construction": "निर्माण",
            "Road": "सड़क",
            "Pothole": "गड्ढा",
            "Footpath": "फुटपाथ",
            "Sidewalk": "फुटपाथ",
            "Bridge": "पुल",
            "Flyover": "फ्लाईओवर",
            "Debris": "मलबा",
            "Structure": "संरचना",
            "Collapse": "गिरावट",
            "Unsafe": "असुरक्षित",
            "Excavation": "खोदाई",
            "Public": "सार्वजनिक",
            "Building": "इमारत",
            "Water": "पानी",
            "Supply": "आपूर्ति",
            "Low": "कम",
            "Pressure": "दबाव",
            "Leakage": "लीक",
            "Burst": "फटा",
            "Pipeline": "पाइपलाइन",
            "Dirty": "गंदा",
            "Contaminated": "प्रदूषित",
            "Tank": "टैंक",
            "Overflow": "अधिभार",
            "Tap": "नल",
            "Meter": "मीटर",
            "Electricity": "बिजली",
            "Power": "शक्ति",
            "Outage": "कटौती",
            "Frequent": "बार-बार",
            "Street": "सड़क",
            "Light": "प्रकाश",
            "Exposed": "खुला",
            "Electrical": "विद्युत",
            "Wires": "तार",
            "Pole": "खंभा",
            "Transformer": "ट्रांसफार्मर",
            "Spark": "चिंगारी",
            "Garbage": "कचरा",
            "Sanitation": "स्वच्छता",
            "Collected": "एकत्र",
            "Overflowing": "अधिकोभर",
            "Dumping": "डंपिंग",
            "Dead": "मृत",
            "Animal": "जानवर",
            "Burning": "जलना",
            "Dustbin": "कचरा पात्र",
            "Truck": "ट्रक",
            "Waterlogging": "पानी भरा",
            "Delay": "देरी",
            "Blocked": "अवरुद्ध",
            "Markings": "निशान",
            "Speed": "गति",
            "Breaker": "ब्रैकर",
            "Drainage": "ड्रेनेज",
            "Sewage": "सीवेज",
            "Cover": "ढक्कन",
            "Manhole": "मैनहोल",
            "Unauthorized": "अनधिकृत",
            "Vendors": "विक्रेता",
            "Advertisement": "विज्ञापन",
            "Noise": "शोर",
            "Pollution": "प्रदूषण",
            "Transportation": "परिवहन",
            "Bus": "बस",
            "Stop": "स्टॉप",
            "Congestion": "जाम",
            "Damaged": "क्षतिग्रस्त",
            "Sign": "संकेत",
            "Auto": "ऑटो",
            "Taxi": "टैक्सी",
            "Pedestrian": "पैदल यात्री",
            "Crossing": "पार करना",
            "Railway": "रेलवे",
            "Cyber": "साइबर",
            "Online": "ऑनलाइन",
            "Payment": "भुगतान",
            "Phishing": "फिशिंग",
            "OTP": "ओटीपी",
            "Banking": "बैंकिंग",
            "Social": "सामाजिक",
            "Media": "मीडिया",
            "Hacking": "हैकिंग",
            "Shopping": "खरीदारी",
            "Identity": "पहचान",
            "Investment": "निवेश",
            "Mobile": "मोबाइल",
            "App": "ऐप",
            "General": "सामान्य",
            "Facility": "सुविधा",
            "Safety": "सुरक्षा",
            "Concern": "चिंता",
            "Government": "सरकारी",
            "Service": "सेवा",
            "Park": "पार्क",
            "Event": "घटना",
            "Environmental": "पर्यावरणीय",
            "Issue": "मुद्दा",
            "Other": "अन्य",
        },
        "gujarati": {
            "Police": "પોલીસ",
            "Complaint": "ફરિયાદ",
            "Theft": "ચોરી",
            "Robbery": "ડાકાયત",
            "Domestic": "ઘરેલું",
            "Violence": "હિંસા",
            "Missing": "ગાયબ",
            "Person": "વ્યક્તિ",
            "Physical": "શારીરિક",
            "Assault": "હમલો",
            "Harassment": "ઉત્પીડન",
            "Threat": "ધમકી",
            "Property": "મુલ્કીય",
            "Damage": "નુકસાન",
            "Drug": "નશીલો",
            "Narcotics": "નશીલી દવાઓ",
            "Fraud": "ઠગાઈ",
            "Scam": "સ્કેમ",
            "Illegal": "ગુનાહિત",
            "Activity": "પ્રવૃત્તિ",
            "Traffic": "ટ્રાફિક",
            "Signal": "સિગ્નલ",
            "Jumping": "કૂદવું",
            "Wrong": "ખોટું",
            "Side": "બાજુ",
            "Driving": "ડ્રાઇવિંગ",
            "Overspeeding": "અતિ ઝડપ",
            "Parking": "પાર્કિંગ",
            "No": "ના",
            "Helmet": "હેલ્મેટ",
            "Triple": "ત્રિગું",
            "Riding": "સવારી",
            "Seatbelt": "સીટબેલ્ટ",
            "Drunk": "નશામાં",
            "Construction": "બાંધકામ",
            "Road": "રસ્તો",
            "Pothole": "ખાડો",
            "Footpath": "ફૂટપાથ",
            "Sidewalk": "ફૂટપાથ",
            "Bridge": "પુર",
            "Flyover": "ફ્લાયઓવર",
            "Debris": "ખંડર",
            "Structure": "રચના",
            "Collapse": "ધસાવ",
            "Unsafe": "અસુરક્ષિત",
            "Excavation": "ખોદકામ",
            "Public": "સર્વજન",
            "Building": "બિલ્ડિંગ",
            "Water": "પાણી",
            "Supply": "પુરવઠો",
            "Low": "ઓછું",
            "Pressure": "દબાણ",
            "Leakage": "લીક",
            "Burst": "ફાટ",
            "Pipeline": "પાઇપલાઇન",
            "Dirty": "ગંદું",
            "Contaminated": "દૂષિત",
            "Tank": "ટાંક",
            "Overflow": "અતિભરવાનું",
            "Tap": "નળ",
            "Meter": "મીટર",
            "Electricity": "વીજળી",
            "Power": "શક્તિ",
            "Outage": "બંધ",
            "Frequent": "વારંવાર",
            "Street": "ગલી",
            "Light": "પ્રકાશ",
            "Exposed": "ખુલ્લું",
            "Electrical": "ઈલેક્ટ્રિકલ",
            "Wires": "તાર",
            "Pole": "ખંભો",
            "Transformer": "ટ્રાન્સફોર્મર",
            "Spark": "ચમકાર",
            "Garbage": "કચરો",
            "Sanitation": "સફાઈ",
            "Collected": "એકત્રિત",
            "Overflowing": "અતિપૂર્તી",
            "Dumping": "ડમ્પીંગ",
            "Dead": "મૃત",
            "Animal": "પ્રાણી",
            "Burning": "ઝળતા",
            "Dustbin": "કચરાનું થેલો",
            "Truck": "ટ્રક",
            "Waterlogging": "પાણી ભરાવ",
            "Delay": "વિલંબ",
            "Blocked": "બંધાયેલ",
            "Markings": "મોરકા",
            "Speed": "ગતિ",
            "Breaker": "બ્રેકર",
            "Drainage": "નિકાસ",
            "Sewage": "ગંદકીય પાણી",
            "Cover": "ઢાંકણી",
            "Manhole": "મેનહોલ",
            "Unauthorized": "અનાધિકૃત",
            "Vendors": "વેંઠાઓ",
            "Advertisement": "જાહેરાત",
            "Noise": "શોર",
            "Pollution": "દૂષણ",
            "Transportation": "પરિવહન",
            "Bus": "બસ",
            "Stop": "સ્ટૉપ",
            "Congestion": "જામ",
            "Damaged": "નુકસાન થયેલું",
            "Sign": "સંकेत",
            "Auto": "ઓટો",
            "Taxi": "ટેક્સી",
            "Pedestrian": "પદયાત્રી",
            "Crossing": "પારગતિ",
            "Railway": "રેલવે",
            "Cyber": "સાયબર",
            "Online": "ઓનલાઇન",
            "Payment": "ચુકવણી",
            "Phishing": "ફિશિંગ",
            "OTP": "ઓટીપી",
            "Banking": "બેંકીંગ",
            "Social": "સામાજિક",
            "Media": "મીડિયા",
            "Hacking": "હેકિંગ",
            "Shopping": "શોપિંગ",
            "Identity": "ઓળખ",
            "Investment": "નિવેશ",
            "Mobile": "મોબાઇલ",
            "App": "એપ",
            "General": "સામાન્ય",
            "Facility": "સુવિધા",
            "Safety": "સુરક્ષા",
            "Concern": "ચિંતા",
            "Government": "સરકારી",
            "Service": "સેવા",
            "Park": "ઉદ્યાન",
            "Event": "પ્રકરણ",
            "Environmental": "વાર્તમાન",
            "Issue": "મામલો",
            "Other": "અન્ય",
        },
    }

    INTENTS = {
        "greeting": re.compile(r"\b(hi|hello|hey|namaste)\b", re.I),
        "full_catalog": re.compile(r"\b(full list|complete list|all categories|all subcategories|entire catalog)\b", re.I),
        "category_catalog": re.compile(r"\b(category|categories|catogory|catagory|issue type|list categories)\b", re.I),
        "subcategory_catalog": re.compile(r"\b(subcategory|subcategories|subcatgory|under|inside|types in)\b", re.I),
        "summary": re.compile(r"\b(summary|summarize|ready to submit|submit now)\b", re.I),
    }

    def _translate_phrase(self, phrase: str, language: str) -> str:
        if not phrase or not language or language == "english":
            return phrase
        tokens = re.split(r"(\s+|/|,|\\(|\\))", phrase)
        map_dict = self.LANGUAGE_TOKEN_TRANSLATIONS.get(language, {})
        translated = "".join([map_dict.get(token, map_dict.get(token.strip(), token)) for token in tokens])
        return translated

    def _localized_category_name(self, category: Optional[str], language: str) -> str:
        if not category:
            return ""
        if language == "english":
            return category
        return self._translate_phrase(category, language)

    def _localized_subcategory_name(self, category: Optional[str], subcategory: Optional[str], language: str) -> str:
        if not subcategory:
            return ""
        if language == "english":
            return subcategory
        return self._translate_phrase(subcategory, language)

    def _localized_text(self, key: str, language: str, **kwargs: Any) -> str:
        base = {
            "detected_match": {
                "english": "I detected {subcategory} under {category}.",
                "hindi": "मैंने {subcategory} को {category} के अंतर्गत पहचाना।",
                "gujarati": "હુંએ {subcategory} ને {category} હેઠળ ઓળખ્યું છે.",
            },
            "found_matches": {
                "english": "I found close matches: {matches}.",
                "hindi": "मुझे ये निकटतम मिलते-जुलते मिले: {matches}.",
                "gujarati": "મને આ નજીકના મેળ મળ્યા: {matches}.",
            },
            "need_detail": {
                "english": "I am analyzing your issue and need one more detail to classify it correctly.",
                "hindi": "मैं आपकी समस्या का विश्लेषण कर रहा हूँ और इसे सही ढंग से वर्गीकृत करने के लिए एक और विवरण चाहिए।",
                "gujarati": "હું તમારી સમસ્યાનો વિશ્લેષણ કરી રહ્યો છું અને તેને યોગ્ય રીતે વર્ગીકૃત કરવા માટે વધુ એક વિગતો જોઈએ છે.",
            },
            "missing_question_category": {
                "english": "Is this related to police, traffic, construction, water, electricity, garbage, road, drainage, illegal activity, transportation, cyber, or other?",
                "hindi": "क्या यह पुलिस, ट्रैफिक, निर्माण, पानी, बिजली, कचरा, सड़क, नाली, अवैध गतिविधि, परिवहन, साइबर या अन्य से संबंधित है?",
                "gujarati": "શું આ પોલીસ, ટ્રાફિક, બાંધકામ, પાણી, વીજળી, કચરો, માર્ગ, નિકાસ, ગેરકાયદેસર પ્રવૃત્તિ, પરિવહન, સાયબર કે અન્ય સંબંધિત છે?",
            },
            "missing_question_location": {
                "english": "Please share exact area, street, and nearby landmark.",
                "hindi": "कृपया सटीक क्षेत्र, सड़क और नजदीकी लैंडमार्क साझा करें।",
                "gujarati": "કૃપા કરીને ચોક્કસ વિસ્તાર, રોડ અને નજીકનું લેન્ડમાર્ક જણાવો.",
            },
            "missing_question_description": {
                "english": "Please describe what happened in one clear sentence.",
                "hindi": "कृपया एक स्पष्ट वाक्य में बताएं कि क्या हुआ।",
                "gujarati": "કૃપા કરીને એક સ્પષ્ટ વાક્યમાં જણાવો શું થયું.",
            },
            "ready_submit": {
                "english": "Should I prepare final complaint summary for submission?",
                "hindi": "क्या मैं सबमिशन के लिए अंतिम शिकायत सारांश तैयार करूं?",
                "gujarati": "શું હું રજૂઆત માટે આખરી ફરિયાદનું સારાંશ તૈયાર કરું?",
            },
            "urgent_advice": {
                "english": "This looks urgent 🚨 If there is immediate danger, call 112 first.\n\nPlease share the exact location and nearest landmark right now.",
                "hindi": "यह आपातकालीन लगता है 🚨 यदि तुरंत खतरा है तो पहले 112 पर कॉल करें।\n\nकृपया अभी सटीक स्थान और नजदीकी लैंडमार्क साझा करें।",
                "gujarati": "આ તાત્કાલિક લાગે છે 🚨 જો turant જોખમ હોય તો પહેલા 112 પર કૉલ કરો.\n\nકૃપા કરીને હવે ચોક્કસ સ્થાન અને નજીકનો લૅન્ડમાર્ક જણાવો.",
            },
        }
        template = base.get(key, {}).get(language, base.get(key, {}).get("english", ""))
        return template.format(**kwargs)

    def _category_catalog_reply(self) -> str:
        language = self._current_language()
        lines = []
        for cat, subs in sorted(self.TAXONOMY.items()):
            name = self._localized_category_name(cat, language)
            lines.append(f"- {name} ({len(subs)} subcategories)")
        header = {
            "english": "Available complaint categories:",
            "hindi": "उपलब्ध शिकायत श्रेणियाँ:",
            "gujarati": "ઉપલબ્ધ ફરિયાદ શ્રેણીઓ:",
        }[language]
        return header + "\n" + "\n".join(lines) + "\n\n" + {
            "english": "Tell any category name and I will list subcategories.",
            "hindi": "किसी भी श्रेणी का नाम बताएं और मैं उपश्रेणियाँ सूचीबद्ध करूंगा।",
            "gujarati": "કોઈ પણ શ્રેણીનું નામ કહો અને હું તેની ઉપશ્રેણીઓ બતાવ્યશ.",
        }[language]

    def _subcategory_catalog_reply(self, category: str) -> str:
        language = self._current_language()
        sub_map = self.TAXONOMY.get(category)
        if not sub_map:
            return {
                "english": "Category not found.",
                "hindi": "श्रेणी नहीं मिली।",
                "gujarati": "શ્રેણી મળી નથી.",
            }[language]
        cat_name = self._localized_category_name(category, language)
        lines = []
        for sub, keys in sub_map.items():
            sub_name = self._localized_subcategory_name(category, sub, language)
            primer = ", ".join([self._translate_phrase(k, language) for k in keys[:2]])
            lines.append(f"- {sub_name} -> {primer}")
        return {
            "english": f"{cat_name} includes:",
            "hindi": f"{cat_name} में शामिल हैं:",
            "gujarati": f"{cat_name} માં શામેલ છે:",
        }[language] + "\n" + "\n".join(lines)

    def _full_catalog_reply(self) -> str:
        language = self._current_language()
        blocks = []
        for category, sub_map in sorted(self.TAXONOMY.items()):
            category_name = self._localized_category_name(category, language)
            rows = [f"{category_name}:"]
            for sub, keys in sub_map.items():
                sub_name = self._localized_subcategory_name(category, sub, language)
                rows.append(f"  - {sub_name} ({', '.join([self._translate_phrase(k, language) for k in keys[:2]])})")
            blocks.append("\n".join(rows))
        prefix = {
            "english": "Complete category-subcategory catalog:",
            "hindi": "पूर्ण श्रेणी-उपश्रेणी सूची:",
            "gujarati": "સંપૂર્ણ શ્રેણી-ઉપશ્રેણી કેટલોગ:",
        }[language]
        return prefix + "\n\n" + "\n\n".join(blocks)

    def _next_question(self, missing: List[str], analysis: Analysis) -> str:
        language = analysis.language or self._current_language()
        if "issue_category" in missing and analysis.alternatives:
            candidates = ", ".join(analysis.alternatives[:3])
            return {
                "english": f"Please confirm closest option: {candidates}.",
                "hindi": f"कृपया सबसे नज़दीकी विकल्प की पुष्टि करें: {candidates}.",
                "gujarati": f"કૃપા કરીને સૌથી નજીકના વિકલ્પની પુષ્ટિ કરો: {candidates}.",
            }[language]
        if "issue_category" in missing:
            return self._localized_text("missing_question_category", language)
        if "exact_location" in missing:
            return self._localized_text("missing_question_location", language)
        if "issue_description" in missing:
            return self._localized_text("missing_question_description", language)
        return self._localized_text("ready_submit", language)

    def _draft_progress_message(self, missing: List[str]) -> str:
        language = self._current_language()
        if not missing:
            return {
                "english": "You have already shared most complaint details ✅ We are now at the final complaint step.",
                "hindi": "आपने पहले ही अधिकांश शिकायत विवरण साझा कर दिए हैं ✅ अब हम अंतिम शिकायत चरण पर हैं।",
                "gujarati": "તમે પહેલેથી જ મોટાભાગના ફરિયાદ વિગતો શેર કરી છે ✅ હવે અમે અંતિમ ફરિયાદ પગલે છીએ.",
            }[language]
        if len(missing) == 1:
            return {
                "english": "Your complaint draft is almost ready ✅ I just need one last detail.",
                "hindi": "आपका शिकायत मसौदा लगभग तैयार है ✅ मुझे बस एक आखिरी विवरण चाहिए।",
                "gujarati": "તમારો ફરિયાદ ડ્રાફ્ટ લગભગ તૈયાર છે ✅ મને માત્ર એક છેલ્લી વિગતો જોઈતી છે.",
            }[language]
        if len(missing) == 2:
            return {
                "english": "Your complaint draft is moving well. I just need two more details to prepare it properly.",
                "hindi": "आपका शिकायत मसौदा अच्छी प्रगति पर है। इसे सही तरीके से तैयार करने के लिए मुझे दो और विवरण चाहिए।",
                "gujarati": "તમારો ફરિયાદ ડ્રાફ્ટ સારી રીતે આગળ વધી રહ્યો છે. યોગ્ય રીતે તૈયાર કરવા માટે મને વધારાની બે વિગતો જોઈએ.",
            }[language]
        return {
            "english": "I am building your complaint draft step by step so we can submit the right issue.",
            "hindi": "मैं आपका शिकायत मसौदा चरण-दर-चरण बनाकर सही मुद्दा प्रस्तुत कर रहा हूँ।",
            "gujarati": "હું તમારા ફરિયાદ ડ્રાફ્ટને પગલે-પગલે બનાવી રહ્યો છું જેથી અમે યોગ્ય મુદ્દો રજૂ કરી શકીએ.",
        }[language]

    def _format_missing_fields(self, missing: List[str]) -> str:
        language = self._current_language()
        labels = {
            "issue_category": {
                "english": "category",
                "hindi": "श्रेणी",
                "gujarati": "શ્રેણી",
            },
            "exact_location": {
                "english": "exact location",
                "hindi": "सटीक स्थान",
                "gujarati": "ચોક્કસ સ્થળ",
            },
            "issue_description": {
                "english": "issue description",
                "hindi": "मुद्दा विवरण",
                "gujarati": "મુદ્દા વર્ણન",
            },
            "issue_timing": {
                "english": "time or repeat issue history",
                "hindi": "समय या समस्या दोहराव इतिहास",
                "gujarati": "સમય અથવા મુદ્દાની પુનરાવર્તન ઇતિહાસ",
            },
        }
        if not missing:
            return {
                "english": "none",
                "hindi": "कोई नहीं",
                "gujarati": "કોઈ નહીં",
            }[language]
        return ", ".join([labels.get(item, {}).get(language, item.replace("_", " ")) for item in missing])

    def _offline_reply(self, analysis: Analysis, missing: List[str], actions: List[str]) -> str:
        category_intake = self._category_intake_reply(analysis, missing)
        if category_intake:
            return category_intake
        if analysis.intent == "greeting":
            return self._greeting_reply()
        if analysis.intent == "full_catalog":
            return self._full_catalog_reply()
        if analysis.intent == "category_catalog":
            return self._category_catalog_reply()
        if analysis.intent == "subcategory_catalog":
            cat = analysis.category or self.complaint_data.get("category")
            return self._subcategory_catalog_reply(cat) if cat else "Tell category name first and I will list subcategories."
        if analysis.intent == "summary":
            data = self.extract_complaint_info()
            language = analysis.language or self._current_language()
            prefix = {
                "english": "Complaint summary:\n",
                "hindi": "शिकायत सारांश:\n",
                "gujarati": "ફરિયાદ સારાંશ:\n",
            }[language]
            lines = [
                {
                    "english": f"Category: {data.get('category') or 'Not set'}",
                    "hindi": f"श्रेणी: {data.get('category') or 'निरधारित'}",
                    "gujarati": f"શ્રેણી: {data.get('category') or 'નિર્ધારિત નથી'}",
                }[language],
                {
                    "english": f"Subcategory: {data.get('subcategory') or 'Not set'}",
                    "hindi": f"उपश्रेणी: {data.get('subcategory') or 'निरधारित'}",
                    "gujarati": f"ઉપશ્રેણી: {data.get('subcategory') or 'નિર્ધારિત નથી'}",
                }[language],
                {
                    "english": f"Urgency: {data.get('urgency')}",
                    "hindi": f"तत्कालता: {data.get('urgency')}",
                    "gujarati": f"તાત્કાલિકતા: {data.get('urgency')}",
                }[language],
                {
                    "english": f"Location: {data.get('location') or 'Not set'}",
                    "hindi": f"स्थान: {data.get('location') or 'निरधारित'}",
                    "gujarati": f"સ્થાન: {data.get('location') or 'નિર્ધારિત નથી'}",
                }[language],
                {
                    "english": f"Description: {data.get('description') or 'Not set'}",
                    "hindi": f"विवरण: {data.get('description') or 'निरधारित'}",
                    "gujarati": f"વર્ણન: {data.get('description') or 'નિર્ધારિત નથી'}",
                }[language],
            ]
            return prefix + "\n".join(lines)
        if analysis.is_emergency:
            return self._localized_text("urgent_advice", analysis.language or self._current_language())

        language = analysis.language or self._current_language()
        if analysis.category and analysis.subcategory:
            core = self._localized_text(
                "detected_match",
                language,
                category=self._localized_category_name(analysis.category, language),
                subcategory=self._localized_subcategory_name(analysis.category, analysis.subcategory, language),
            )
        elif analysis.alternatives:
            core = self._localized_text("found_matches", language, matches=", ".join(analysis.alternatives[:3]))
        else:
            core = self._localized_text("need_detail", language)

        question = self._next_question(missing, analysis)
        action_text = "\n".join([f"{i + 1}. {a}" for i, a in enumerate(actions[:3])])
        progress = self._draft_progress_message(missing)
        still_needed = {
            "english": "Still needed",
            "hindi": "अभी भी आवश्यक",
            "gujarati": "હજુ જરૂરી",
        }[language]
        next_actions = {
            "english": "Next actions:",
            "hindi": "अगली कार्रवाई:",
            "gujarati": "આગામી પગલાં:",
        }[language]
        return f"{progress}\n\n{core}\n{still_needed}: {self._format_missing_fields(missing)}.\n{question}\n{next_actions}\n{action_text}"

    def _maybe_model_reply(self, user_text: str, analysis: Analysis, missing: List[str], fallback: str) -> str:
        if self.genai_client is None and self.model is None:
            return fallback
        prompt = self._build_model_prompt(user_text, analysis, missing, fallback)
        try:
            text = ""
            if self.genai_client is not None:
                result = self.genai_client.models.generate_content(
                    model=self.model_name,
                    contents=prompt,
                )
                text = (getattr(result, "text", "") or "").strip()
            elif self.model is not None:
                result = self.model.generate_content(prompt)
                text = (result.text or "").strip()
            if not text:
                return fallback
            if "?" not in text and missing:
                text += "\n\n" + self._next_question(missing, analysis)
            return text[:2400]
        except Exception:
            return fallback

    def _build_model_prompt(self, user_text: str, analysis: Analysis, missing: List[str], fallback: str) -> str:
        catalog_lines = []
        for cat, sub_map in self.TAXONOMY.items():
            catalog_lines.append(f"{cat}: {', '.join(sub_map.keys())}")
        catalog_text = " | ".join(catalog_lines)
        direct_mode = self._is_short_category_trigger(user_text, analysis)
        progress = self._draft_progress_message(missing)
        return (
            "You are Smart City AI Complaint Assistant. "
            "You help citizens register complaints in a smart, human, practical, and emotionally aware way. "
            "You are not a generic chatbot. Never say vague lines like 'How can I help you?' if the user already gave a complaint signal. "
            "Your job is to guide the citizen from confusion to a complete complaint draft for submission.\n"
            "Follow this complaint intake flow step by step:\n"
            "1. Identify intent: greeting, complaint booking, category list request, subcategory list request, summary request, edit previous complaint detail, confirm complaint, or unclear but likely complaint.\n"
            "2. Detect complaint category from the message.\n"
            "3. Detect best subcategory using user words, issue signals, project taxonomy, previous context, and evidence if available.\n"
            "4. Detect urgency: low, medium, high, or critical.\n"
            "5. Detect emergency. If immediate danger, violence, active crime, major accident, exposed live wire, or serious threat exists, advise urgent safety action first.\n"
            "6. Collect missing complaint fields. Required: category, subcategory, exact location, issue description. Useful extras: time/date, photo/video, current location, repeat issue history, landmark, and severity details.\n"
            "7. Ask only one best next question.\n"
            "8. Keep a running complaint draft in memory.\n"
            "9. When enough details are collected, generate final complaint summary.\n"
            "10. Ask for confirmation before final submission.\n"
            "Conversation behavior rules:\n"
            "- Be direct, calm, practical, and supportive.\n"
            "- Sound human, not robotic.\n"
            "- If the user writes in a broken or incomplete way, still infer likely meaning and continue.\n"
            "- If the user changes the complaint details later, update the draft intelligently without losing valid data.\n"
            "- If the user says only a category word such as police, cyber, water, electricity, garbage, road, or traffic, immediately acknowledge the category, show likely subcategories, and ask the strongest next complaint question.\n"
            "- If confidence is low, suggest top options and ask for confirmation.\n"
            "- If category is Police Complaint or Cyber Crime, ask incident type, location, and time early.\n"
            "- If the complaint draft is nearly complete, say that clearly, for example: 'You have already shared most complaint details ✅' or 'We are now at the final complaint step.'\n"
            "- Use light helpful emojis only where they improve clarity, such as 🚨 for danger, 📍 for location, 📷 for evidence, and ✅ for completion. Do not spam emojis.\n"
            "- If the user greets you, reply warmly using their name if available and the correct time-of-day greeting like good morning, good afternoon, or good evening.\n"
            "- Make each answer feel like a skilled human complaint support executive, not an AI template.\n"
            "- Every reply must move the user toward complaint completion.\n"
            "- Mention one focused next question, not many.\n"
            "- Use exact category and subcategory names from the project taxonomy.\n"
            "Output should feel next-level, useful, and citizen-friendly.\n"
            f"user_name={self._display_name()}\n"
            f"language={analysis.language}\n"
            f"intent={analysis.intent}\n"
            f"category={analysis.category}\n"
            f"subcategory={analysis.subcategory}\n"
            f"urgency={analysis.urgency}\n"
            f"emergency={analysis.is_emergency}\n"
            f"confidence={analysis.confidence}\n"
            f"signals={analysis.signals}\n"
            f"missing={missing}\n"
            f"alternatives={analysis.alternatives}\n"
            f"direct_mode={direct_mode}\n"
            f"draft_progress={progress}\n"
            f"catalog={catalog_text}\n"
            f"user={user_text}\n"
            f"fallback={fallback}"
        )

    def _missing_fields(self, analysis: Optional[Analysis]) -> List[str]:
        payload = self.complaint_data.copy()
        if analysis is not None:
            payload.update({"category": analysis.category or payload.get("category"), "subcategory": analysis.subcategory or payload.get("subcategory"), "location_hint": analysis.location_hint or payload.get("location_hint"), "time_hint": analysis.time_hint or payload.get("time_hint")})
        out = []
        if not payload.get("category"):
            out.append("issue_category")
        if not payload.get("location_hint"):
            out.append("exact_location")
        if not self._extract_description():
            out.append("issue_description")
        if self._looks_recurring() and not payload.get("time_hint"):
            out.append("issue_timing")
        return out

    def _actions(self, analysis: Analysis) -> List[str]:
        if analysis.is_emergency:
            return ["Call emergency helpline 112 if danger is immediate", "Move to safe area", "Share exact location"]
        if analysis.category is None and analysis.alternatives:
            return [f"Pick closest issue type: {', '.join(analysis.alternatives[:3])}", "Share exact location and nearest landmark", "Attach one photo or video if available"]
        return [f"Issue tagged as {analysis.subcategory or analysis.category or 'pending category'}", "Share exact location and nearest landmark", "Attach one photo or video if available"]

    # localised _next_question is already defined earlier. This placeholder avoids duplicate legacy method definitions.
    # def _next_question(self, missing: List[str], analysis: Analysis) -> str: ...

    def _next_step(self, missing: List[str]) -> str:
        if not missing:
            return "ready_to_submit"
        if "issue_category" in missing:
            return "category_detection"
        if "exact_location" in missing:
            return "location_gathering"
        return "detail_gathering"

    def _merge(self, analysis: Analysis, text: str) -> None:
        if analysis.category:
            self.complaint_data["category"] = analysis.category
        if analysis.subcategory:
            self.complaint_data["subcategory"] = analysis.subcategory
        if analysis.location_hint:
            self.complaint_data["location_hint"] = analysis.location_hint
        if analysis.time_hint:
            self.complaint_data["time_hint"] = analysis.time_hint
        self.complaint_data.update({"urgency": analysis.urgency, "is_emergency": analysis.is_emergency, "confidence": analysis.confidence, "alternatives": analysis.alternatives or [], "matched_signals": analysis.signals or [], "last_user_message": text, "updated_at": timezone.now().isoformat()})

    def _extract_location(self, text: str) -> Optional[str]:
        m = self.LOC_RE.search(text)
        return (m.group(1).strip().strip(".,;!?") if m else None) or None

    def _extract_time(self, text: str) -> Optional[str]:
        m = self.TIME_RE.search(text)
        return (m.group(1).strip() if m else None) or None

    def _extract_description(self) -> Optional[str]:
        msgs = [str(m.get("content", "")).strip() for m in self.conversation_history if m.get("role") == "user"]
        long_msgs = [m for m in msgs if len(m) >= 20]
        return " | ".join(long_msgs[:3]) if long_msgs else None

    def _extract_location_from_history(self) -> Optional[str]:
        for msg in reversed(self.conversation_history):
            if msg.get("role") != "user":
                continue
            loc = self._extract_location(str(msg.get("content", "")))
            if loc:
                return loc
        return None

    def _looks_recurring(self) -> bool:
        last = str(self.complaint_data.get("last_user_message", "")).lower()
        return bool(re.search(r"\b(every day|daily|again|still not fixed|for many days|repeat)\b", last))

    def _conversation_summary(self) -> str:
        msgs = [str(m.get("content", "")).strip() for m in self.conversation_history if m.get("role") == "user"]
        return " | ".join(msgs[:6])

    def _push_turn(self, role: str, content: str) -> None:
        self.conversation_history.append({"role": role, "content": content, "timestamp": timezone.now().isoformat()})
        if len(self.conversation_history) > 40:
            self.conversation_history = self.conversation_history[-40:]

    def _normalize(self, text: str) -> str:
        return self._normalize_static(text)

    @staticmethod
    def _normalize_static(text: str) -> str:
        cleaned = re.sub(r"[^a-zA-Z0-9\u0900-\u097F\u0A80-\u0AFF\s]", " ", text.lower())
        return re.sub(r"\s+", " ", cleaned).strip()

    def _token_overlap(self, a: str, b: str) -> float:
        ta = {x for x in a.split() if len(x) >= 3}
        tb = {x for x in b.split() if len(x) >= 3}
        if not ta or not tb:
            return 0.0
        return len(ta & tb) / max(1, len(tb))

    def _category_hints(self, normalized_text: str) -> List[str]:
        scored = []
        for category, aliases in self.CATEGORY_ALIASES.items():
            score = 0
            if self._normalize(category) in normalized_text:
                score += 6
            for alias in aliases:
                k = self._normalize(alias)
                if k and k in normalized_text:
                    score += 2
            if score > 0:
                scored.append((category, score))
        scored.sort(key=lambda x: x[1], reverse=True)
        return [c for c, _ in scored[:4]]

    def _greeting_reply(self) -> str:
        greeting = self._time_based_greeting()
        name = self._display_name()
        language = self._normalize_language_preference(
            self.user_context.get("preferred_language") or self.user_context.get("language")
        ) or "english"
        if language == "gujarati":
            return f"{greeting}, {name} 😊 હું તમારો સ્માર્ટ સિટી ફરિયાદ સહાયક છું. તમે તમારી સમસ્યા ટૂંકમાં લખો, હું કેટેગરી, તાત્કાલિકતા અને આગળનું પગલું તરત સમજાવી દઈશ."
        if language == "hindi" or language == "hinglish":
            return f"{greeting}, {name} 😊 Main aapka Smart City complaint assistant hoon. Aap apni problem short mein likhiye, main category, urgency aur next step turant bataunga."
        return f"{greeting}, {name} 😊 I am your Smart City complaint assistant. Share your issue in one line and I will detect the category, urgency, and the next best step."

    def _time_based_greeting(self) -> str:
        hour = timezone.localtime().hour
        language = self._normalize_language_preference(
            self.user_context.get("preferred_language") or self.user_context.get("language")
        ) or "english"
        if language == "gujarati":
            if hour < 12:
                return "સુપ્રભાત"
            if hour < 17:
                return "શુભ બપોર"
            return "શુભ સાંજ"
        if language == "hindi" or language == "hinglish":
            if hour < 12:
                return "Good morning"
            if hour < 17:
                return "Good afternoon"
            return "Good evening"
        if hour < 12:
            return "Good morning"
        if hour < 17:
            return "Good afternoon"
        return "Good evening"

    def _display_name(self) -> str:
        raw = str(self.user_context.get("user_name") or "").strip()
        if raw:
            first = raw.split()[0].strip()
            if first:
                return first
        return "Citizen"

    def _normalize_language_preference(self, value: Optional[str]) -> Optional[str]:
        if not value:
            return None
        normalized = str(value).strip().lower()
        mapping = {
            "en": "english",
            "english": "english",
            "hi": "hindi",
            "hindi": "hindi",
            "hinglish": "hinglish",
            "gu": "gujarati",
            "gujarati": "gujarati",
            "mr": "marathi",
            "marathi": "marathi",
        }
        return mapping.get(normalized, normalized)

    def __init__(self, session_id: str = "default"):
        self.session_id = session_id
        self.complaint_data = {
            "category": None,
            "subcategory": None,
            "location_hint": None,
            "time_hint": None,
            "urgency": "low",
            "is_emergency": False,
            "confidence": 0.0,
            "alternatives": [],
            "matched_signals": [],
            "last_user_message": "",
            "updated_at": timezone.now().isoformat(),
        }
        self.conversation_history = []
        self.user_context = {"user_name": "Citizen", "preferred_language": "english", "language": "english"}
        self.genai_client = None
        self.model = None
        self.model_name = getattr(settings, "GENAI_MODEL", "gpt-4o")

    @classmethod
    def for_session(cls, session_id: str = "default") -> "SmartCityAI":
        with cls._sessions_lock:
            if session_id not in cls._sessions:
                cls._sessions[session_id] = cls(session_id=session_id)
            return cls._sessions[session_id]

    @classmethod
    def clear_session(cls, session_id: str) -> None:
        with cls._sessions_lock:
            if session_id in cls._sessions:
                del cls._sessions[session_id]
        try:
            cache.delete(f"{cls._cache_prefix}:{session_id}")
        except Exception:
            pass

    def _persist_cached_state(self):
        try:
            cache.set(f"{self._cache_prefix}:{self.session_id}", {
                "complaint_data": self.complaint_data,
                "conversation_history": self.conversation_history,
                "user_context": self.user_context,
            }, timeout=int(self._session_ttl.total_seconds()))
        except Exception:
            pass

    def _current_language(self) -> str:
        lang = self._normalize_language_preference(
            self.user_context.get("preferred_language") or self.user_context.get("language")
        ) or "english"
        if lang == "hinglish":
            lang = "hindi"
        return lang

    def _detect_intent(self, text: str) -> str:
        for intent, regex in self.INTENTS.items():
            if regex.search(text):
                return intent
        return "unknown"

    def _category_intake_reply(self, analysis: Analysis, missing: List[str]) -> Optional[str]:
        if "issue_category" in missing and analysis.alternatives:
            candidates = ", ".join(analysis.alternatives[:3])
            language = analysis.language or self._current_language()
            return {
                "english": f"I think you may be referring to: {candidates}.",
                "hindi": f"मुझे लगता है कि आप इनका जिक्र कर रहे हैं: {candidates}.",
                "gujarati": f"હું માનું છું કે તમે આ વિશે કહી રહ્યા છો: {candidates}.",
            }[language]
        return None

    def _is_short_category_trigger(self, text: str, analysis: Analysis) -> bool:
        return bool(analysis.category and not analysis.subcategory)

    def detect_language(self, text: str) -> str:
        # Basic language detection using keywords
        text_lower = (text or "").lower()
        if re.search(r"\b(नहीं|कृपया|शिकायत|पुलिस|ट्रैफिक)\b", text_lower):
            return "hindi"
        if re.search(r"\b(તમારી|ફરિયાદ|પોલીસ|ટ્રાફિક)\b", text_lower):
            return "gujarati"
        return "english"

    def _analyze_text(self, text: str) -> Analysis:
        language = self.detect_language(text)
        intent = self._detect_intent(text)
        normalized_text = self._normalize(text)
        category_candidates = self._category_hints(normalized_text)
        return Analysis(
            language=language,
            emotion="neutral",
            urgency="low",
            is_emergency=False,
            intent=intent,
            category=category_candidates[0] if category_candidates else None,
            subcategory=None,
            confidence=0.5 if category_candidates else 0.2,
            alternatives=category_candidates,
            signals=[],
        )

    def generate_response(self, user_text: str, user_email: Optional[str] = None, user_name: Optional[str] = None, preferred_language: Optional[str] = None) -> Dict[str, Any]:
        self.conversation_history.append({"role": "user", "content": user_text, "timestamp": timezone.now().isoformat()})
        if user_name:
            self.user_context["user_name"] = user_name
        if preferred_language:
            self.user_context["preferred_language"] = self._normalize_language_preference(preferred_language)
        if user_email:
            self.user_context["user_email"] = user_email

        analysis = self._analyze_text(user_text)
        missing = self._missing_fields(analysis)

        # Basic extraction from text: location and description heuristics
        if not self.complaint_data.get("location_hint"):
            self.complaint_data["location_hint"] = self._extract_location(user_text)
        if not self.complaint_data.get("time_hint"):
            self.complaint_data["time_hint"] = self._extract_time(user_text)
        if not self.complaint_data.get("subcategory") and analysis.category and analysis.alternatives:
            self.complaint_data["category"] = analysis.category

        self._merge(analysis, user_text)
        response_text = self._offline_reply(analysis, missing, self._actions(analysis))
        self._persist_cached_state()

        return {
            "response": response_text,
            "detected_category": analysis.category,
            "urgency": analysis.urgency,
            "emotion": analysis.emotion,
            "language": analysis.language,
            "next_step": self._next_step(missing),
        }

    def extract_complaint_info(self) -> Dict[str, Any]:
        missing = self._missing_fields(None)
        return {
            "category": self.complaint_data.get("category"),
            "subcategory": self.complaint_data.get("subcategory"),
            "location": self.complaint_data.get("location_hint"),
            "description": self._extract_description(),
            "urgency": self.complaint_data.get("urgency"),
            "is_emergency": self.complaint_data.get("is_emergency"),
            "language": self._current_language(),
            "missing_fields": missing,
        }

    def get_history(self) -> List[Dict[str, str]]:
        return self.conversation_history

    def generate_reengagement_nudge(self) -> Dict[str, str]:
        message = self._draft_progress_message(self._missing_fields(None))
        lang = self._current_language()
        if lang == "hindi":
            title = "आपकी शिकायत लगभग तैयार है"
            body = message
        elif lang == "gujarati":
            title = "તમારી ફરિયાદ લગભગ તૈયાર છે"
            body = message
        else:
            title = "Your complaint is nearly ready"
            body = message
        return {"title": title, "body": body}
