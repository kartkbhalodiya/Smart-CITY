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

    INTENTS = {
        "greeting": re.compile(r"\b(hi|hello|hey|namaste)\b", re.I),
        "full_catalog": re.compile(r"\b(full list|complete list|all categories|all subcategories|entire catalog)\b", re.I),
        "category_catalog": re.compile(r"\b(category|categories|catogory|catagory|issue type|list categories)\b", re.I),
        "subcategory_catalog": re.compile(r"\b(subcategory|subcategories|subcatgory|under|inside|types in)\b", re.I),
        "summary": re.compile(r"\b(summary|summarize|ready to submit|submit now)\b", re.I),
    }

    LOC_RE = re.compile(r"\b(?:at|near|in|on|around|beside|opposite)\s+([a-z0-9 ,.-]{3,100})", re.I)
    TIME_RE = re.compile(r"\b(today|yesterday|tonight|this morning|this evening|last night|\d+\s*(?:hour|hours|day|days|week|weeks)\s*(?:ago)?)\b", re.I)

    def __init__(self, session_id: Optional[str] = None) -> None:
        self.session_id = self._clean_session_id(session_id)
        self.model_name = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")
        self._ensure_shared_model_client()
        self.model = self.__class__._shared_legacy_model
        self.genai_client = self.__class__._shared_genai_client
        self.genai_backend = self.__class__._shared_backend
        self.conversation_history: List[Dict[str, Any]] = []
        self.user_context: Dict[str, Any] = {}
        self.complaint_data: Dict[str, Any] = {}
        self.last_active = timezone.now()

    @classmethod
    def for_session(cls, session_id: str) -> "SmartCityAI":
        sid = cls._clean_session_id(session_id)
        with cls._sessions_lock:
            cls._prune_locked()
            if sid in cls._sessions:
                cls._sessions[sid].last_active = timezone.now()
                cls._sessions[sid]._load_cached_state()
                return cls._sessions[sid]
            obj = cls(sid)
            obj._load_cached_state()
            cls._sessions[sid] = obj
            return obj

    @classmethod
    def clear_session(cls, session_id: str) -> None:
        sid = cls._clean_session_id(session_id)
        with cls._sessions_lock:
            cls._sessions.pop(sid, None)
        cache.delete(cls._cache_key(sid))

    def get_history(self) -> List[Dict[str, Any]]:
        return [dict(item) for item in self.conversation_history]

    @classmethod
    def _clean_session_id(cls, session_id: Optional[str]) -> str:
        raw = (session_id or "default").strip() or "default"
        if len(raw) > 128:
            raw = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        return re.sub(r"[^a-zA-Z0-9_\-.]", "_", raw)

    @classmethod
    def _cache_key(cls, session_id: str) -> str:
        return f"{cls._cache_prefix}:{session_id}"

    @classmethod
    def _ensure_shared_model_client(cls) -> None:
        if cls._shared_client_ready:
            return
        with cls._client_lock:
            if cls._shared_client_ready:
                return
            model_name = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")
            api_key = getattr(settings, "GEMINI_API_KEY", None)
            if api_key and google_genai is not None:
                try:
                    cls._shared_genai_client = google_genai.Client(api_key=api_key)
                    cls._shared_backend = "google.genai"
                except Exception:
                    cls._shared_genai_client = None
                    cls._shared_backend = "none"
            if cls._shared_genai_client is None and api_key:
                try:
                    global legacy_genai
                    if legacy_genai is None:
                        import google.generativeai as legacy_genai  # type: ignore
                    legacy_genai.configure(api_key=api_key)
                    cls._shared_legacy_model = legacy_genai.GenerativeModel(
                        model_name,
                    )
                    cls._shared_backend = "legacy"
                except Exception:
                    cls._shared_legacy_model = None
                    cls._shared_backend = "none"
            cls._shared_client_ready = True

    def _load_cached_state(self) -> None:
        payload = cache.get(self._cache_key(self.session_id))
        if not isinstance(payload, dict):
            return
        self.conversation_history = list(payload.get("conversation_history", []))
        self.user_context = dict(payload.get("user_context", {}))
        self.complaint_data = dict(payload.get("complaint_data", {}))
        updated = payload.get("last_active")
        self.last_active = updated if isinstance(updated, type(timezone.now())) else timezone.now()

    def _persist_cached_state(self) -> None:
        payload = {
            "conversation_history": self.conversation_history[-40:],
            "user_context": self.user_context,
            "complaint_data": self.complaint_data,
            "last_active": timezone.now(),
        }
        cache.set(
            self._cache_key(self.session_id),
            payload,
            int(self._session_ttl.total_seconds()),
        )

    @classmethod
    def _prune_locked(cls) -> None:
        now = timezone.now()
        stale = [k for k, v in cls._sessions.items() if now - v.last_active > cls._session_ttl]
        for k in stale:
            cls._sessions.pop(k, None)
        if len(cls._sessions) <= cls._max_sessions:
            return
        ordered = sorted(cls._sessions.items(), key=lambda kv: kv[1].last_active)
        for k, _ in ordered[: len(cls._sessions) - cls._max_sessions]:
            cls._sessions.pop(k, None)

    @classmethod
    def _ensure_corpus_index(cls) -> None:
        if cls._corpus_index_ready:
            return
        with cls._corpus_index_lock:
            if cls._corpus_index_ready:
                return
            token_index: Dict[str, List[int]] = {}
            for idx, row in enumerate(KNOWLEDGE_CORPUS[:20000]):
                row_text = cls._normalize_static(str(row.get("text", "")))
                tokens = {token for token in row_text.split() if len(token) >= 3}
                for token in tokens:
                    token_index.setdefault(token, []).append(idx)
            cls._corpus_token_index = token_index
            cls._corpus_index_ready = True

    def detect_language(self, text: str) -> str:
        if re.search(r"[\u0A80-\u0AFF]", text):
            return "gujarati"
        if re.search(r"[\u0900-\u097F]", text):
            return "hindi"
        if self._is_hinglish(text):
            return "hinglish"
        return "english"

    def _is_hinglish(self, text: str) -> bool:
        words = ["aap", "mujhe", "nahi", "kya", "pani", "bijli", "problem"]
        lower = text.lower()
        return bool(re.search(r"[a-z]", lower)) and any(re.search(rf"\b{re.escape(w)}\b", lower) for w in words)

    def detect_emotion(self, text: str) -> str:
        lower = text.lower()
        if re.search(r"\b(angry|mad|furious|gussa)\b", lower):
            return "angry"
        if re.search(r"\b(frustrated|irritated|pareshan|fed up)\b", lower):
            return "frustrated"
        if re.search(r"\b(worried|concerned|scared|unsafe)\b", lower):
            return "worried"
        if re.search(r"\b(sad|upset|disappointed)\b", lower):
            return "sad"
        return "neutral"

    def detect_urgency(self, text: str) -> str:
        lower = text.lower()
        if re.search(r"\b(fire|electrocution|accident|explosion|serious injury|life threatening)\b", lower):
            return "critical"
        if re.search(r"\b(emergency|urgent|danger|unsafe|immediate|jaldi)\b", lower):
            return "high"
        return "medium"

    def is_emergency(self, text: str, urgency: str) -> bool:
        return urgency == "critical" or bool(re.search(r"\b(help now|not safe|live wire|gas leak|collapse|blast)\b", text.lower()))

    def detect_intent(self, text: str) -> str:
        lower = text.lower()
        compact = self._normalize(lower)
        greeting_match = self.INTENTS["greeting"].fullmatch(compact)
        if greeting_match and len(compact.split()) <= 3:
            return "greeting"
        for intent, pattern in self.INTENTS.items():
            if intent == "greeting":
                continue
            if pattern.search(lower):
                return intent
        return "complaint"

    def generate_response(
        self,
        user_input: str,
        user_email: Optional[str] = None,
        user_name: Optional[str] = None,
        preferred_language: Optional[str] = None,
    ) -> Dict[str, Any]:
        text = (user_input or "").strip()
        if not text:
            return {"response": "Please describe your issue so I can help.", "detected_category": None, "urgency": "medium", "emotion": "neutral", "language": "english", "next_step": "issue_capture"}

        language_hint = self._normalize_language_preference(preferred_language)
        lang = language_hint or self.detect_language(text)
        emotion = self.detect_emotion(text)
        urgency = self.detect_urgency(text)
        emergency = self.is_emergency(text, urgency)
        intent = self.detect_intent(text)

        if user_name:
            self.user_context["user_name"] = user_name.strip()
        if language_hint:
            self.user_context["preferred_language"] = language_hint
        self.user_context.update({"language": lang, "emotion": emotion, "email": user_email, "urgency": urgency, "is_emergency": emergency})

        category, subcategory, confidence, alternatives, signals = self._detect_category(text)
        analysis = Analysis(
            language=lang,
            emotion=emotion,
            urgency=urgency,
            is_emergency=emergency,
            intent=intent,
            category=category,
            subcategory=subcategory,
            confidence=confidence,
            alternatives=alternatives,
            signals=signals,
            location_hint=self._extract_location(text),
            time_hint=self._extract_time(text),
        )

        missing = self._missing_fields(analysis)
        actions = self._actions(analysis)
        self._merge(analysis, text)

        fallback = self._offline_reply(analysis, missing, actions)
        response = self._maybe_model_reply(text, analysis, missing, fallback)

        self._push_turn("user", text)
        self._push_turn("assistant", response)
        self._persist_cached_state()

        return {
            "response": response,
            "detected_category": analysis.category or self.complaint_data.get("category"),
            "subcategory": analysis.subcategory or self.complaint_data.get("subcategory"),
            "urgency": analysis.urgency,
            "emotion": analysis.emotion,
            "language": analysis.language,
            "next_step": self._next_step(missing),
            "missing_fields": missing,
            "action_checklist": actions,
            "confidence": round(analysis.confidence, 3),
            "analysis": {"intent": analysis.intent, "alternatives": alternatives, "signals": signals, "location_hint": analysis.location_hint, "time_hint": analysis.time_hint, "is_emergency": analysis.is_emergency},
        }

    def generate_reengagement_nudge(self) -> Dict[str, str]:
        language = self._normalize_language_preference(
            self.user_context.get("preferred_language") or self.user_context.get("language")
        ) or "english"
        name = self._display_name()
        category = self.complaint_data.get("category")
        location = self.complaint_data.get("location_hint")
        if language == "gujarati":
            title = f"{name}, તમારી ફરિયાદ અધૂરી છે 📍"
            if category:
                body = f"તમે {category} અંગે ફરિયાદ શરૂ કરી હતી. આવો, બાકી રહેલી માહિતી આપી તેને પૂર્ણ કરીએ."
            else:
                body = "તમે ફરિયાદ શરૂ કરી હતી. આવો, થોડી વધુ માહિતી આપી તેને પૂર્ણ કરીએ."
            if location:
                body += f" હાલની સ્થાન માહિતી: {location}."
            return {"title": title, "body": body}
        if language == "hindi" or language == "hinglish":
            title = f"{name}, aapki complaint abhi adhuri hai 📍"
            if category:
                body = f"Aapne {category} ke liye complaint shuru ki thi. Wapas aaiye, ek-do details aur dekar ise complete kar dete hain."
            else:
                body = "Aapne complaint shuru ki thi. Wapas aaiye, thodi aur details dekar ise submit kar dete hain."
            if location:
                body += f" Location hint: {location}."
            return {"title": title, "body": body}
        title = f"{name}, your complaint is still pending 📍"
        if category:
            body = f"You started a {category} complaint. Come back and add the last details so we can complete it."
        else:
            body = "You started a complaint. Come back and add the remaining details so we can complete it."
        if location:
            body += f" Current saved location hint: {location}."
        return {"title": title, "body": body}

    def extract_complaint_info(self) -> Dict[str, Any]:
        return {
            "category": self.complaint_data.get("category"),
            "subcategory": self.complaint_data.get("subcategory"),
            "urgency": self.complaint_data.get("urgency", "medium"),
            "is_emergency": bool(self.complaint_data.get("is_emergency")),
            "description": self._extract_description(),
            "location": self.complaint_data.get("location_hint") or self._extract_location_from_history(),
            "time_hint": self.complaint_data.get("time_hint"),
            "language": self.user_context.get("language", "english"),
            "emotion": self.user_context.get("emotion", "neutral"),
            "missing_fields": self._missing_fields(None),
            "conversation_summary": self._conversation_summary(),
            "confidence": self.complaint_data.get("confidence", 0.0),
            "updated_at": self.complaint_data.get("updated_at"),
        }

    def reset_conversation(self) -> None:
        self.conversation_history = []
        self.user_context = {}
        self.complaint_data = {}
        self.last_active = timezone.now()
        self._persist_cached_state()

    def _detect_category(self, text: str) -> Tuple[Optional[str], Optional[str], float, List[str], List[str]]:
        norm = self._normalize(text)
        scored: List[Tuple[str, str, float, List[str]]] = []
        for cat, sub_map in self.TAXONOMY.items():
            for sub, keywords in sub_map.items():
                score = 0.0
                signals = []
                if self._normalize(cat) in norm:
                    score += 4.0
                    signals.append(cat)
                if self._normalize(sub) in norm:
                    score += 6.0
                    signals.append(sub)
                for alias in self.CATEGORY_ALIASES.get(cat, []):
                    alias_k = self._normalize(alias)
                    if alias_k and alias_k in norm:
                        score += 2.5 if " " not in alias_k else 3.5
                        signals.append(alias)
                for boost_phrase in self.CATEGORY_SIGNAL_BOOSTS.get(cat, []):
                    boost_key = self._normalize(boost_phrase)
                    if boost_key and boost_key in norm:
                        score += 5.0
                        signals.append(boost_phrase)
                for kw in keywords:
                    kw_k = self._normalize(kw)
                    if not kw_k:
                        continue
                    if kw_k in norm:
                        score += 2.0 if " " not in kw_k else 4.0
                        signals.append(kw)
                    elif self._token_overlap(norm, kw_k) >= 0.7:
                        score += 1.0
                        signals.append(kw)
                if score > 0:
                    scored.append((cat, sub, score, list(dict.fromkeys(signals))[:6]))

        if not scored and KNOWLEDGE_CORPUS:
            scored.extend(self._detect_with_corpus(norm))
        if not scored:
            return None, None, 0.0, self._category_hints(norm), []

        scored.sort(key=lambda x: x[2], reverse=True)
        best = scored[0]
        if best[1] == "Other":
            for candidate in scored[1:]:
                if candidate[1] != "Other" and candidate[2] >= max(1.5, best[2] - 3.0):
                    best = candidate
                    break
        second = 0.0
        for candidate in scored:
            if candidate != best:
                second = candidate[2]
                break
        conf = max(0.22, min(0.98, best[2] / max(1.0, best[2] + second)))
        alternatives = [f"{s} ({c})" for c, s, sc, _ in scored[1:] if sc >= max(2.0, best[2] - 2.5)]
        return best[0], best[1], conf, list(dict.fromkeys(alternatives))[:4], best[3][:4]

    def _detect_with_corpus(self, norm: str) -> List[Tuple[str, str, float, List[str]]]:
        tokens = {t for t in norm.split() if len(t) >= 3}
        if not tokens:
            return []
        self._ensure_corpus_index()
        candidate_rows: Dict[int, float] = {}
        for token in tokens:
            for row_idx in self._corpus_token_index.get(token, []):
                candidate_rows[row_idx] = candidate_rows.get(row_idx, 0.0) + 1.0
        if not candidate_rows:
            return []

        out: Dict[Tuple[str, str], float] = {}
        sig: Dict[Tuple[str, str], List[str]] = {}
        for row_idx, base_score in sorted(
            candidate_rows.items(),
            key=lambda item: item[1],
            reverse=True,
        )[:120]:
            row = KNOWLEDGE_CORPUS[row_idx]
            row_text = self._normalize(str(row.get("text", "")))
            row_tokens = {x for x in row_text.split() if len(x) >= 3}
            if not row_tokens:
                continue
            overlap = len(tokens & row_tokens)
            if overlap == 0:
                continue
            key = (str(row.get("category", "")), str(row.get("subcategory", "")))
            normalized_overlap = overlap / max(1, len(row_tokens))
            out[key] = out.get(key, 0.0) + base_score + (normalized_overlap * 3.0)
            sig.setdefault(key, []).extend(list(tokens & row_tokens)[:4])
        ranked = sorted(out.items(), key=lambda kv: kv[1], reverse=True)[:8]
        return [(k[0], k[1], v, list(dict.fromkeys(sig.get(k, [])))[:4]) for k, v in ranked if v >= 1.5]

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
            return "Complaint summary:\n" + "\n".join([f"Category: {data.get('category') or 'Not set'}", f"Subcategory: {data.get('subcategory') or 'Not set'}", f"Urgency: {data.get('urgency')}", f"Location: {data.get('location') or 'Not set'}", f"Description: {data.get('description') or 'Not set'}"])
        if analysis.is_emergency:
            return "This looks urgent 🚨 If there is immediate danger, call 112 first.\n\nPlease share the exact location and nearest landmark right now."

        if analysis.category and analysis.subcategory:
            core = f"I detected {analysis.subcategory} under {analysis.category}."
        elif analysis.alternatives:
            core = f"I found close matches: {', '.join(analysis.alternatives[:3])}."
        else:
            core = "I am analyzing your issue and need one more detail to classify it correctly."

        question = self._next_question(missing, analysis)
        action_text = "\n".join([f"{i + 1}. {a}" for i, a in enumerate(actions[:3])])
        progress = self._draft_progress_message(missing)
        return f"{progress}\n\n{core}\nStill needed: {self._format_missing_fields(missing)}.\n{question}\nNext actions:\n{action_text}"

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

    def _next_question(self, missing: List[str], analysis: Analysis) -> str:
        if "issue_category" in missing and analysis.alternatives:
            return f"Please confirm closest option: {', '.join(analysis.alternatives[:3])}."
        if "issue_category" in missing:
            return (
                "Is this related to police, traffic, construction, water, electricity, "
                "garbage, road, drainage, illegal activity, transportation, cyber, or other?"
            )
        if "exact_location" in missing:
            return "Please share exact area, street, and nearby landmark."
        if "issue_description" in missing:
            return "Please describe what happened in one clear sentence."
        return "Should I prepare final complaint summary for submission?"

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

    def _category_catalog_reply(self) -> str:
        lines = [f"- {cat} ({len(subs)} subcategories)" for cat, subs in sorted(self.TAXONOMY.items())]
        return "Available complaint categories:\n" + "\n".join(lines) + "\n\nTell any category name and I will list subcategories."

    def _subcategory_catalog_reply(self, category: str) -> str:
        sub_map = self.TAXONOMY.get(category)
        if not sub_map:
            return "Category not found."
        lines = [f"- {sub} -> {', '.join(keys[:2])}" for sub, keys in sub_map.items()]
        return f"{category} includes:\n" + "\n".join(lines)

    def _full_catalog_reply(self) -> str:
        blocks = []
        for category, sub_map in sorted(self.TAXONOMY.items()):
            rows = [f"{category}:"]
            for sub, keys in sub_map.items():
                rows.append(f"  - {sub} ({', '.join(keys[:2])})")
            blocks.append("\n".join(rows))
        return "Complete category-subcategory catalog:\n\n" + "\n\n".join(blocks)

    def _is_short_category_trigger(self, user_text: str, analysis: Analysis) -> bool:
        normalized = self._normalize(user_text)
        if not analysis.category or not normalized:
            return False
        token_count = len(normalized.split())
        if token_count <= 3:
            return True
        return bool(re.fullmatch(rf"(?:{re.escape(self._normalize(analysis.category))})(?: complaint)?", normalized))

    def _category_intake_reply(self, analysis: Analysis, missing: List[str]) -> Optional[str]:
        if not self._is_short_category_trigger(self.complaint_data.get("last_user_message", "") or analysis.category or "", analysis):
            return None
        if not analysis.category:
            return None

        subcategories = list(self.TAXONOMY.get(analysis.category, {}).keys())
        highlighted = ", ".join(subcategories[:4])
        safety_line = ""
        if analysis.category == "Police Complaint":
            safety_line = " If anyone is in immediate danger, call 112 first."
        elif analysis.category == "Cyber Crime":
            safety_line = " If money was lost, secure the bank account or card immediately."

        question = self._next_question(missing, analysis)
        return (
            f"This looks like {analysis.category}{' 🚨' if analysis.category in ['Police Complaint', 'Cyber Crime'] else ''}.{safety_line}\n\n"
            f"Common issue types here: {highlighted}.\n"
            f"Current match: {analysis.subcategory or 'category detected, subcategory pending'}.\n"
            f"Please tell me what happened, where it happened, and when it happened.\n"
            f"{question}"
        )

    def _draft_progress_message(self, missing: List[str]) -> str:
        if not missing:
            return "You have already shared most complaint details ✅ We are now at the final complaint step."
        if len(missing) == 1:
            return "Your complaint draft is almost ready ✅ I just need one last detail."
        if len(missing) == 2:
            return "Your complaint draft is moving well. I just need two more details to prepare it properly."
        return "I am building your complaint draft step by step so we can submit the right issue."

    def _format_missing_fields(self, missing: List[str]) -> str:
        labels = {
            "issue_category": "category",
            "exact_location": "exact location",
            "issue_description": "issue description",
            "issue_timing": "time or repeat issue history",
        }
        if not missing:
            return "none"
        return ", ".join([labels.get(item, item.replace("_", " ")) for item in missing])

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
