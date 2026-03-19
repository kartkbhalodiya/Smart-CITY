"""
Converts the Smart City corpus + taxonomy into training data for CityFix LLM.
Run: python data/prepare_data.py
Output: data/train.json, data/vocab.json, data/label_map.json
"""
import sys, os, json, re

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# ── Inline taxonomy (mirrors conversational_ai.py TAXONOMY) ──────────────────
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

URGENCY_SIGNALS = {
    "critical": ["fire", "blast", "collapse", "dead body", "murder", "rape", "kidnap", "accident", "emergency", "112"],
    "high": ["urgent", "danger", "dangerous", "immediate", "bleeding", "attack", "threat", "exposed wire", "live wire"],
    "medium": ["since 3 days", "since yesterday", "for 2 days", "not fixed", "happening daily", "repeat"],
    "low": [],
}

EMOTION_SIGNALS = {
    "frustrated": ["not fixed", "again", "still", "nobody", "no action", "useless", "pathetic", "fed up"],
    "scared": ["scared", "afraid", "fear", "danger", "unsafe", "threat", "help me"],
    "angry": ["angry", "disgusting", "worst", "terrible", "shame", "irresponsible"],
    "neutral": [],
}

LOCATION_PATTERNS = [
    r"(?:near|at|beside|behind|around|in|on|opposite|next to)\s+([A-Za-z0-9\s]{3,40}?)(?:\s+(?:since|for|very|needs|causing|affecting|happening|not|road|area|ward|sector|gate|mall|hospital|school|temple|bus|stand|market)|\.|,|$)",
    r"(?:ward|sector|area|road|street|nagar|colony|chowk|circle|gate)\s+\w+",
]

HINDI_LOCATION_PATTERNS = [
    r"(?:ke paas|mein|par|ke samne|ke peeche)\s+([^\s,।]+(?:\s+[^\s,।]+){0,3})",
]

TIME_PATTERNS = [
    r"since\s+(yesterday|last\s+\w+|\d+\s+days?|\d+\s+hours?|\d+\s+weeks?)",
    r"for\s+(\d+\s+days?|\d+\s+hours?|\d+\s+weeks?)",
    r"(\d+\s+din\s+se|\d+\s+ghante\s+se)",
]

EMERGENCY_KEYWORDS = [
    "fire", "blast", "collapse", "dead body", "murder", "rape", "kidnap",
    "accident", "emergency", "112", "help help", "maaro", "bachao", "save me",
    "exposed wire", "live wire", "gas leak",
]


def normalize(text):
    return re.sub(r"\s+", " ", re.sub(r"[^a-zA-Z0-9\u0900-\u097F\u0A80-\u0AFF\s]", " ", text.lower())).strip()


def detect_urgency(text):
    t = text.lower()
    for level in ["critical", "high", "medium"]:
        for kw in URGENCY_SIGNALS[level]:
            if kw in t:
                return level
    return "low"


def detect_emotion(text):
    t = text.lower()
    for emotion in ["frustrated", "scared", "angry"]:
        for kw in EMOTION_SIGNALS[emotion]:
            if kw in t:
                return emotion
    return "neutral"


def detect_language(text):
    if re.search(r"[\u0900-\u097F]", text):
        return "hindi"
    if re.search(r"[\u0A80-\u0AFF]", text):
        return "gujarati"
    return "english"


def is_emergency(text):
    t = text.lower()
    return any(kw in t for kw in EMERGENCY_KEYWORDS)


def extract_location(text):
    for pat in LOCATION_PATTERNS:
        m = re.search(pat, text, re.I)
        if m:
            return m.group(1).strip() if m.lastindex else m.group(0).strip()
    for pat in HINDI_LOCATION_PATTERNS:
        m = re.search(pat, text)
        if m:
            return m.group(1).strip()
    return None


def extract_time(text):
    for pat in TIME_PATTERNS:
        m = re.search(pat, text, re.I)
        if m:
            return m.group(1).strip()
    return None


def apply_typo(word):
    typo_map = {
        "a": "s", "s": "a", "i": "u", "o": "p", "e": "r",
        "n": "m", "t": "y", "r": "t", "l": "k", "d": "s",
    }
    if len(word) < 3:
        return word
    for c in word:
        if c in typo_map:
            return word.replace(c, typo_map[c], 1)
    return word


def add_typo_phrases(text, variant_index):
    words = text.split()
    idx = variant_index % len(words)
    if idx < 0:
        idx = 0
    words[idx] = apply_typo(words[idx])
    if variant_index % 7 == 0 and len(words) > 2:
        words[-1] = apply_typo(words[-1])
    return " ".join(words)


LANGUAGE_MAPPING = {
    "water": ["pani", "paani"],
    "power": ["bijli"],
    "road": ["sadak"],
    "pothole": ["gadda"],
    "garbage": ["kachra", "kooda"],
    "drain": ["nali"],
    "police": ["thana", "polis"],
    "signal": ["traffic light"],
    "construction": ["nirman", "tamak"],
    "leak": ["leakage", "leak"],
    "illegal": ["anaidhik", "hatyare"],
    "urgent": ["turant", "jaldi"],
    "help": ["madad", "help"],
    "issue": ["problem", "masla"],
    "not": ["nahi"],
}


def translate_to_hinglish(text, variant_index):
    words = text.split()
    changed = []
    for i, token in enumerate(words):
        key = re.sub(r"[^a-zA-Z]", "", token.lower())
        if key in LANGUAGE_MAPPING and (variant_index + i) % 4 == 0:
            changed_word = LANGUAGE_MAPPING[key][(variant_index + i) % len(LANGUAGE_MAPPING[key])]
            changed.append(changed_word)
        else:
            changed.append(token)
    return " ".join(changed)


gu_jrati_replacements = {
    "help": ["મદદ", "help"],
    "water": ["પાણી"],
    "power": ["બિજળી"],
    "road": ["રસ્તો"],
    "police": ["પોલીસ"],
    "garbage": ["કચરો"],
    "unsafe": ["ખતરો"],
}


def translate_to_gujarati(text, variant_index):
    words = text.split()
    changed = []
    for i, token in enumerate(words):
        key = re.sub(r"[^a-zA-Z]", "", token.lower())
        if key in gu_jrati_replacements and (variant_index + i) % 5 == 0:
            changed_word = gu_jrati_replacements[key][(variant_index + i) % len(gu_jrati_replacements[key])]
            changed.append(changed_word)
        else:
            changed.append(token)
    return " ".join(changed)


CITIZEN_FILLERS = [
    "yaar", "bhai", "please", "fatafat", "jaldi", "suno", "sir", "madad karo",
    "assistance", "abhi", "abhi tak", "firse", "again", "hat-dam", "bahut","bahen" ]

STRUCTURE_TEMPLATES = [
    "{prefix} {keyword} {location} {time}",
    "{prefix} {keyword} {location}",
    "{keyword} {location} {time}",
    "{prefix} {keyword} {time}",
    "{prefix} {keyword}",
    "{keyword} {time}",
    "{keyword} {location}",
    "{keyword} ka problem {location} {time}",
    "{location} mein {keyword} {time}",
]


def sample_with_citizen_style(text, variant_index):
    if variant_index % 3 == 0:
        text = f"{CITIZEN_FILLERS[variant_index % len(CITIZEN_FILLERS)]} {text}"
    if variant_index % 11 == 0:
        text = f"{text} {CITIZEN_FILLERS[(variant_index + 1) % len(CITIZEN_FILLERS)]}"
    if variant_index % 13 == 0:
        text = text.replace(" ", " ", 1)
    return text


def make_variant(base, variant_index):
    text = base["text"]
    text = STRUCTURE_TEMPLATES[variant_index % len(STRUCTURE_TEMPLATES)].format(
        prefix=CITIZEN_FILLERS[variant_index % len(CITIZEN_FILLERS)],
        keyword=base["text"],
        location="in ward 15" if "ward" not in base["text"] else "in ward 15",
        time="since 2 din se" if "since" not in base["text"] else "since 2 din se",
    ) if variant_index % 5 == 0 else text

    if variant_index % 2 == 0:
        text = translate_to_hinglish(text, variant_index)
    if variant_index % 3 == 0:
        text = translate_to_gujarati(text, variant_index)

    text = add_typo_phrases(text, variant_index)
    text = sample_with_citizen_style(text, variant_index)
    text = normalize(text)

    return {
        "text": text,
        "category": base["category"],
        "subcategory": base["subcategory"],
        "urgency": detect_urgency(text),
        "emotion": detect_emotion(text),
        "language": detect_language(text),
        "is_emergency": is_emergency(text),
        "location": extract_location(text),
        "time_hint": extract_time(text),
    }


def augment_samples(samples, target_count=1000000):
    base_samples = list(samples)
    augmented = []
    idx = 0
    while len(samples) + len(augmented) < target_count:
        base = base_samples[idx % len(base_samples)]
        variant = make_variant(base, idx)
        augmented.append(variant)
        idx += 1
    return samples + augmented


def build_samples():
    samples = []

    # ── From taxonomy keywords ────────────────────────────────────────────────
    prefixes = [
        "please report", "need complaint for", "register issue",
        "urgent issue", "citizen reporting", "help me with",
        "please fix", "request action on", "immediately solve",
        "book complaint for", "i want to report", "there is a problem with",
        "complaint about", "issue regarding",
    ]
    locations = [
        "near main road", "at market area", "beside school", "in ward 12",
        "near bus stand", "at society gate", "around hospital",
        "near temple road", "in sector 9", "behind mall",
        "near railway station", "at city center", "in old city area",
    ]
    suffixes = [
        "since yesterday", "for 3 days", "very urgent", "causing danger",
        "needs immediate action", "affecting many people",
        "happening daily", "not fixed yet", "since last week",
        "please help", "take action",
    ]

    for cat, sub_map in TAXONOMY.items():
        for sub, keywords in sub_map.items():
            for kw in keywords:
                for prefix in prefixes[:6]:
                    for loc in locations[:5]:
                        for suf in suffixes[:4]:
                            text = f"{prefix} {kw} {loc} {suf}"
                            samples.append({
                                "text": text,
                                "category": cat,
                                "subcategory": sub,
                                "urgency": detect_urgency(text),
                                "emotion": detect_emotion(text),
                                "language": detect_language(text),
                                "is_emergency": is_emergency(text),
                                "location": extract_location(text),
                                "time_hint": extract_time(text),
                            })

    # ── Natural language variations ───────────────────────────────────────────
    natural = [
        ("mera ghar ke paas pani nahi aa raha 3 din se", "Water Supply", "No Water Supply"),
        ("bijli gayi hai subah se abhi tak nahi aayi", "Electricity", "Power Outage"),
        ("sadak mein bada gadda hai gaadi toot gayi", "Road/Pothole", "Pothole on Road"),
        ("nali jam gayi hai paani bhar raha hai", "Drainage/Sewage", "Blocked Drain"),
        ("kachra collect nahi hua 5 din se", "Garbage/Sanitation", "Garbage Not Collected"),
        ("mere mobile se otp lekar paisa nikal liya", "Cyber Crime", "OTP / Banking Fraud"),
        ("ghar ke samne illegal construction ho raha hai", "Illegal Activities", "Illegal Construction"),
        ("bus stop pe koi shelter nahi hai", "Transportation", "Bus Stop Issue"),
        ("traffic signal kaam nahi kar raha", "Transportation", "Traffic Signal Failure"),
        ("street light band hai raat ko andhera rehta hai", "Electricity", "Street Light Not Working"),
        ("pipe se paani leak ho raha hai", "Water Supply", "Water Leakage"),
        ("dustbin full ho gayi hai overflow ho rahi hai", "Garbage/Sanitation", "Overflowing Garbage Bin"),
        ("road pe paani bhar gaya hai waterlogging", "Road/Pothole", "Water Logging on Road"),
        ("khuli wire hai bijli ka khatra hai", "Electricity", "Exposed Electrical Wires"),
        ("manhole khula hua hai accident ho sakta hai", "Drainage/Sewage", "Manhole Issue"),
        ("mera phone hack ho gaya instagram", "Cyber Crime", "Social Media Hacking"),
        ("ghar mein maarpeet ho rahi hai help karo", "Police Complaint", "Domestic Violence"),
        ("chori ho gayi ghar mein", "Police Complaint", "Theft / Robbery"),
        ("drunk driving kar raha tha woh", "Traffic Complaint", "Drunk Driving"),
        ("no helmet triple riding near school", "Traffic Complaint", "No Helmet / Triple Riding"),
        ("pothole on main road very dangerous", "Road/Pothole", "Pothole on Road"),
        ("garbage not collected since 5 days smell is very bad", "Garbage/Sanitation", "Garbage Not Collected"),
        ("water supply stopped since morning", "Water Supply", "No Water Supply"),
        ("power cut since 6 hours no electricity", "Electricity", "Power Outage"),
        ("drain is blocked water logging in street", "Drainage/Sewage", "Blocked Drain"),
        ("illegal construction going on without permission", "Illegal Activities", "Illegal Construction"),
        ("online fraud happened lost money upi", "Cyber Crime", "Online Payment Fraud"),
        ("stray dogs attacking people near park", "Other Complaint", "Animal Related Issue"),
        ("loud music at night noise pollution", "Other Complaint", "Noise Complaint"),
        ("road broken after rain many potholes", "Road/Pothole", "Broken Road"),
        ("transformer blast near our colony", "Electricity", "Transformer Issue"),
        ("sewage leaking on road ganda paani", "Drainage/Sewage", "Sewage Leakage"),
        ("bus not coming on time route 42", "Transportation", "Public Bus Issue"),
        ("road sign damaged cant see direction", "Transportation", "Damaged Road Sign"),
        ("construction debris blocking road malba", "Construction Complaint", "Construction Debris"),
        ("flyover has cracks dangerous", "Construction Complaint", "Bridge / Flyover Issue"),
        ("water meter showing wrong reading", "Water Supply", "Water Meter Problem"),
        ("fake job offer scam lost money", "Cyber Crime", "Fake Job Scam"),
        ("missing person my child is missing", "Police Complaint", "Missing Person"),
        ("drug selling happening near school", "Police Complaint", "Drug / Narcotics"),
    ]

    for text, cat, sub in natural:
        samples.append({
            "text": text,
            "category": cat,
            "subcategory": sub,
            "urgency": detect_urgency(text),
            "emotion": detect_emotion(text),
            "language": detect_language(text),
            "is_emergency": is_emergency(text),
            "location": extract_location(text),
            "time_hint": extract_time(text),
        })

    return samples


def build_vocab(samples, min_freq=1):
    from collections import Counter
    counter = Counter()
    for s in samples:
        tokens = normalize(s["text"]).split()
        counter.update(tokens)
    vocab = {"<PAD>": 0, "<UNK>": 1}
    for word, freq in counter.items():
        if freq >= min_freq:
            vocab[word] = len(vocab)
    return vocab


def build_label_maps(samples):
    cats = sorted(set(s["category"] for s in samples))
    subs = sorted(set(f"{s['category']}||{s['subcategory']}" for s in samples))
    urgencies = ["low", "medium", "high", "critical"]
    emotions = ["neutral", "frustrated", "scared", "angry"]
    languages = ["english", "hindi", "gujarati"]
    locations = ["no", "yes"]
    times = ["no", "yes"]
    return {
        "category": {c: i for i, c in enumerate(cats)},
        "category_inv": {i: c for i, c in enumerate(cats)},
        "subcategory": {s: i for i, s in enumerate(subs)},
        "subcategory_inv": {i: s for i, s in enumerate(subs)},
        "urgency": {u: i for i, u in enumerate(urgencies)},
        "urgency_inv": {i: u for i, u in enumerate(urgencies)},
        "emotion": {e: i for i, e in enumerate(emotions)},
        "emotion_inv": {i: e for i, e in enumerate(emotions)},
        "language": {l: i for i, l in enumerate(languages)},
        "language_inv": {i: l for i, l in enumerate(languages)},
        "location": {l: i for i, l in enumerate(locations)},
        "location_inv": {i: l for i, l in enumerate(locations)},
        "time": {t: i for i, t in enumerate(times)},
        "time_inv": {i: t for i, t in enumerate(times)},
    }


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate CityFix training data")
    parser.add_argument("--target", type=int, default=100000, help="Target number of samples after augmentation (e.g., 70000, 100000, 1000000)")
    parser.add_argument("--min_freq", type=int, default=1, help="Minimum frequency for vocab inclusion")
    args = parser.parse_args()

    out_dir = os.path.dirname(__file__)
    print("Building samples...")
    samples = build_samples()
    print(f"Base samples: {len(samples)}")

    target = max(args.target, len(samples))
    print(f"Augmenting up to {target} samples...")
    samples = augment_samples(samples, target_count=target)
    print(f"Total samples after augmentation: {len(samples)}")

    vocab = build_vocab(samples, min_freq=args.min_freq)
    label_maps = build_label_maps(samples)

    with open(os.path.join(out_dir, "train.json"), "w", encoding="utf-8") as f:
        json.dump(samples, f, ensure_ascii=False, indent=2)

    with open(os.path.join(out_dir, "vocab.json"), "w", encoding="utf-8") as f:
        json.dump(vocab, f, ensure_ascii=False, indent=2)

    with open(os.path.join(out_dir, "label_map.json"), "w", encoding="utf-8") as f:
        json.dump(label_maps, f, ensure_ascii=False, indent=2)

    print(f"Vocab size: {len(vocab)}")
    print(f"Categories: {len(label_maps['category'])}")
    print(f"Subcategories: {len(label_maps['subcategory'])}")
    print("Saved: data/train.json, data/vocab.json, data/label_map.json")
