const Map<String, dynamic> complaintCategories = {
  "Road/Pothole": {
    "Pothole": {
      "keywords": {
        "en": ["pothole", "hole in road", "road broken", "damaged road", "crater", "pit", "road damage", "deep hole", "road cavity", "pavement hole"],
        "hi": ["गड्ढा", "सड़क टूटी", "सड़क में गड्ढा", "खराब सड़क", "टूटी सड़क", "सड़क क्षतिग्रस्त"],
        "hinglish": ["gadda", "road pe hole", "road kharab", "sadak tuti", "road me gadda", "tuta hua road"],
        "guj": ["ખાડો", "રોડ તૂટેલો", "રસ્તામાં ખાડો", "ખરાબ રસ્તો"]
      },
      "questions": ["How big is the pothole?", "Is it dangerous for vehicles?", "How deep is it?"]
    },
    "Water Logging": {
      "keywords": {
        "en": ["water logging", "road flooded", "waterlogged", "standing water", "flood on road", "water accumulation"],
        "hi": ["पानी जमा", "जलभराव", "सड़क पर पानी", "पानी भरा"],
        "hinglish": ["pani jama", "road pe pani", "pani bhara", "waterlogging"],
        "guj": ["પાણી ભરાયું", "રસ્તા પર પાણી"]
      },
      "questions": ["How deep is the water?", "Is traffic blocked?"]
    },
    "Road Blocked": {
      "keywords": {
        "en": ["road blocked", "construction blocking", "obstruction", "road closed", "blocked path"],
        "hi": ["रास्ता बंद", "सड़क बंद", "रुकावट"],
        "hinglish": ["road band", "rasta band", "block hai"],
        "guj": ["રસ્તો બંધ", "અવરોધ"]
      }
    },
    "Broken Road": {
      "keywords": {
        "en": ["broken road", "cracked road", "damaged pavement", "road cracks"],
        "hi": ["टूटी सड़क", "दरार वाली सड़क"],
        "hinglish": ["tuti sadak", "crack wali road"],
        "guj": ["તૂટેલો રસ્તો"]
      }
    }
  },
  
  "Drainage/Sewage": {
    "Blocked Drain": {
      "keywords": {
        "en": ["drain blocked", "clogged drain", "drainage problem", "sewer blocked", "drain jam"],
        "hi": ["नाली बंद", "नाली जाम", "नाली में रुकावट"],
        "hinglish": ["nali jam", "nali band", "drain block"],
        "guj": ["નાળી બંધ", "ગટર બંધ"]
      },
      "questions": ["Is water overflowing?", "How long has it been blocked?"]
    },
    "Sewer Overflow": {
      "keywords": {
        "en": ["sewer overflow", "gutter overflow", "sewage leak", "drain overflow"],
        "hi": ["सीवर ओवरफ्लो", "गटर भरा", "नाली से पानी"],
        "hinglish": ["gutter overflow", "nali se pani", "sewage bahar"],
        "guj": ["ગટર છલકાય", "ગટર ભરાઈ"]
      }
    },
    "Foul Smell": {
      "keywords": {
        "en": ["bad smell", "foul odor", "stink", "sewage smell", "drain smell"],
        "hi": ["बदबू", "गंदी बदबू", "सीवर की बदबू"],
        "hinglish": ["badbu", "gandi smell", "buri smell"],
        "guj": ["દુર્ગંધ", "ખરાબ ગંધ"]
      }
    },
    "Manhole Open": {
      "keywords": {
        "en": ["open manhole", "manhole cover missing", "uncovered manhole"],
        "hi": ["खुला मैनहोल", "मैनहोल खुला"],
        "hinglish": ["manhole khula", "cover nahi hai"],
        "guj": ["ખુલ્લું મેનહોલ"]
      }
    }
  },

  "Garbage/Sanitation": {
    "Garbage Not Collected": {
      "keywords": {
        "en": ["garbage not collected", "trash not picked", "waste not removed", "garbage pile"],
        "hi": ["कचरा नहीं उठाया", "कूड़ा पड़ा है", "कचरा जमा"],
        "hinglish": ["kachra nahi uthaya", "garbage pada hai", "kooda jama"],
        "guj": ["કચરો ઉઠાવ્યો નથી", "કચરો પડ્યો છે"]
      },
      "questions": ["How many days has it been?", "Is it causing health issues?"]
    },
    "Overflowing Bin": {
      "keywords": {
        "en": ["overflowing bin", "dustbin full", "garbage bin overflow"],
        "hi": ["कचरा भरा हुआ", "डस्टबिन भरा"],
        "hinglish": ["dustbin full", "kachra bhara", "bin overflow"],
        "guj": ["ડસ્ટબિન ભરેલું", "કચરો છલકાય"]
      }
    },
    "Dead Animal": {
      "keywords": {
        "en": ["dead animal", "animal carcass", "dead dog", "dead cow"],
        "hi": ["मरा हुआ जानवर", "मृत पशु"],
        "hinglish": ["dead animal", "mara janwar"],
        "guj": ["મરેલું પ્રાણી"]
      }
    },
    "Littering": {
      "keywords": {
        "en": ["littering", "throwing garbage", "dumping waste"],
        "hi": ["कचरा फेंकना", "गंदगी फैलाना"],
        "hinglish": ["kachra fenkna", "gandi failana"],
        "guj": ["કચરો ફેંકવો"]
      }
    }
  },

  "Electricity": {
    "Power Outage": {
      "keywords": {
        "en": ["no electricity", "power cut", "blackout", "no power", "electricity gone"],
        "hi": ["बिजली नहीं", "बिजली गई", "पावर कट"],
        "hinglish": ["light nahi", "bijli gayi", "power cut"],
        "guj": ["લાઇટ નથી", "વીજળી ગઈ"]
      },
      "questions": ["How long has power been out?", "Is it affecting the whole area?"]
    },
    "Street Light": {
      "keywords": {
        "en": ["street light off", "street lamp not working", "pole light broken"],
        "hi": ["स्ट्रीट लाइट बंद", "सड़क की बत्ती नहीं"],
        "hinglish": ["light band", "street light nahi", "pole light off"],
        "guj": ["સ્ટ્રીટ લાઇટ બંધ"]
      }
    },
    "Exposed Wires": {
      "keywords": {
        "en": ["open wire", "exposed wire", "hanging wire", "dangerous wire"],
        "hi": ["खुली तार", "लटकती तार", "खतरनाक तार"],
        "hinglish": ["khuli wire", "latakti wire", "dangerous wire"],
        "guj": ["ખુલ્લી વાયર", "લટકતી વાયર"]
      }
    },
    "Transformer Issue": {
      "keywords": {
        "en": ["transformer problem", "transformer blast", "transformer noise"],
        "hi": ["ट्रांसफार्मर खराब", "ट्रांसफार्मर फटा"],
        "hinglish": ["transformer kharab", "transformer blast"],
        "guj": ["ટ્રાન્સફોર્મર ખરાબ"]
      }
    }
  },

  "Water Supply": {
    "No Water": {
      "keywords": {
        "en": ["no water", "water not coming", "no water supply", "tap dry"],
        "hi": ["पानी नहीं", "पानी नहीं आ रहा", "नल सूखा"],
        "hinglish": ["pani nahi", "pani nahi aa raha", "nal me pani nahi"],
        "guj": ["પાણી નથી", "પાણી આવતું નથી"]
      },
      "questions": ["How many days without water?", "Is it affecting the whole area?"]
    },
    "Water Leakage": {
      "keywords": {
        "en": ["water leak", "pipe leak", "water wastage", "leaking pipe"],
        "hi": ["पानी लीक", "पाइप टूटा", "पानी बर्बाद"],
        "hinglish": ["pani leak", "pipe tuta", "pani waste"],
        "guj": ["પાણી લીક", "પાઈપ તૂટ્યો"]
      }
    },
    "Dirty Water": {
      "keywords": {
        "en": ["dirty water", "contaminated water", "muddy water", "brown water"],
        "hi": ["गंदा पानी", "मैला पानी", "दूषित पानी"],
        "hinglish": ["ganda pani", "maila pani", "dirty pani"],
        "guj": ["ગંદું પાણી", "દૂષિત પાણી"]
      }
    },
    "Low Pressure": {
      "keywords": {
        "en": ["low pressure", "weak water flow", "slow water"],
        "hi": ["कम दबाव", "धीमा पानी"],
        "hinglish": ["kam pressure", "slow pani"],
        "guj": ["ઓછું દબાણ"]
      }
    }
  },

  "Traffic": {
    "Illegal Parking": {
      "keywords": {
        "en": ["illegal parking", "wrong parking", "blocking road", "parked wrongly"],
        "hi": ["गलत पार्किंग", "अवैध पार्किंग"],
        "hinglish": ["galat parking", "wrong parking"],
        "guj": ["ગેરકાયદે પાર્કિંગ"]
      }
    },
    "Broken Signal": {
      "keywords": {
        "en": ["signal not working", "traffic light broken", "signal off"],
        "hi": ["सिग्नल खराब", "ट्रैफिक लाइट बंद"],
        "hinglish": ["signal kharab", "traffic light off"],
        "guj": ["સિગ્નલ ખરાબ"]
      }
    },
    "Wrong Side": {
      "keywords": {
        "en": ["wrong side driving", "one way violation"],
        "hi": ["गलत दिशा", "वन वे तोड़ना"],
        "hinglish": ["wrong side", "one way tod"],
        "guj": ["ખોટી દિશા"]
      }
    },
    "Overspeeding": {
      "keywords": {
        "en": ["overspeeding", "fast driving", "rash driving"],
        "hi": ["तेज गाड़ी", "लापरवाह ड्राइविंग"],
        "hinglish": ["fast driving", "tez gaadi"],
        "guj": ["ઝડપી વાહન"]
      }
    }
  },

  "Cyber Crime": {
    "Online Fraud": {
      "keywords": {
        "en": ["fraud", "scam", "cheating", "online fraud", "money lost"],
        "hi": ["धोखा", "ठगी", "फ्रॉड"],
        "hinglish": ["fraud", "scam", "dhoka"],
        "guj": ["છેતરપિંડી", "ઠગાઈ"]
      },
      "questions": ["When did this happen?", "How much money was lost?", "Do you have transaction details?"]
    },
    "UPI Scam": {
      "keywords": {
        "en": ["upi fraud", "payment scam", "phonepe fraud", "paytm fraud"],
        "hi": ["यूपीआई फ्रॉड", "पेमेंट धोखा"],
        "hinglish": ["upi scam", "payment fraud"],
        "guj": ["UPI છેતરપિંડી"]
      }
    },
    "Phishing": {
      "keywords": {
        "en": ["phishing", "fake link", "suspicious link", "spam message"],
        "hi": ["फिशिंग", "नकली लिंक"],
        "hinglish": ["fake link", "phishing"],
        "guj": ["ફિશિંગ", "નકલી લિંક"]
      }
    },
    "Identity Theft": {
      "keywords": {
        "en": ["identity theft", "account hacked", "data stolen"],
        "hi": ["पहचान चोरी", "अकाउंट हैक"],
        "hinglish": ["account hack", "data chori"],
        "guj": ["ઓળખ ચોરી"]
      }
    }
  },

  "Construction": {
    "Illegal Construction": {
      "keywords": {
        "en": ["illegal building", "unauthorized construction", "illegal structure"],
        "hi": ["अवैध निर्माण", "गैरकानूनी इमारत"],
        "hinglish": ["illegal construction", "bina permission building"],
        "guj": ["ગેરકાયદે બાંધકામ"]
      }
    },
    "Construction Debris": {
      "keywords": {
        "en": ["debris", "construction waste", "rubble"],
        "hi": ["मलबा", "निर्माण कचरा"],
        "hinglish": ["malba", "construction waste"],
        "guj": ["બાંધકામ કચરો", "મલબો"]
      }
    },
    "Noise Pollution": {
      "keywords": {
        "en": ["construction noise", "loud noise", "drilling sound"],
        "hi": ["शोर", "निर्माण शोर"],
        "hinglish": ["shor", "noise pollution"],
        "guj": ["ઘોંઘાટ"]
      }
    }
  }
};

const String aiSystemPrompt = '''You are an AI-powered Smart City Complaint Assistant for India.

CORE CAPABILITIES:
- Support Hindi, English, Gujarati, and Hinglish
- Understand natural conversational speech
- Automatically detect complaint category from keywords
- Ask minimal, relevant questions
- Complete complaint in under 60 seconds

CONVERSATION FLOW:
1. Greet user and ask preferred language
2. Ask "What problem are you facing?"
3. Detect category automatically from keywords
4. Confirm: "You are reporting [category]. Correct?"
5. Ask 1-2 relevant follow-up questions
6. Collect location (auto-captured via GPS)
7. Ask for photo (optional)
8. Confirm contact details
9. Submit complaint

INTELLIGENCE RULES:
- Match keywords across all languages
- Handle synonyms: "gadda"="pothole", "kooda"="garbage"
- If multiple issues mentioned, ask user to pick one
- Check for duplicate complaints at same location
- Use fuzzy matching for typos

TONE:
- Friendly, conversational, simple
- No technical jargon
- One question at a time
- Like talking to a helpful human

EXAMPLE CONVERSATION:
User: "road pe bada gadda hai"
AI: "Aap pothole ki complaint kar rahe hain. Sahi hai?"
User: "haan"
AI: "Gadda kitna bada hai? Gaadi ke liye khatarnak hai?"
User: "bahut bada, accident ho sakta hai"
AI: "Samjha. Kya aap photo upload karna chahenge?"
''';
