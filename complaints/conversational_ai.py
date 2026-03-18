from __future__ import annotations

from dataclasses import dataclass, field
from datetime import timedelta
import hashlib
import re
import threading
from typing import Any, Dict, List, Optional, Tuple

from django.conf import settings
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

    TAXONOMY = {
        "Road/Pothole": {
            "Pothole": ["pothole", "gadda", "hole in road", "road broken"],
            "Water Logging": ["water logging", "waterlogged", "pani jama", "road flooded"],
            "Road Blocked": ["road blocked", "rasta band", "road closed"],
            "Broken Road": ["broken road", "cracked road", "sadak kharab"],
        },
        "Drainage/Sewage": {
            "Blocked Drain": ["drain blocked", "nali jam", "sewer blocked"],
            "Sewer Overflow": ["sewer overflow", "gutter overflow", "nali se pani"],
            "Foul Smell": ["bad smell", "foul odor", "badbu"],
            "Manhole Open": ["open manhole", "manhole cover missing", "manhole khula"],
        },
        "Garbage/Sanitation": {
            "Garbage Not Collected": ["garbage not collected", "trash not picked", "kachra jama"],
            "Overflowing Bin": ["overflowing bin", "dustbin full", "bin overflow"],
            "Dead Animal": ["dead animal", "animal carcass", "mara janwar"],
            "Littering": ["littering", "throwing garbage", "kachra fenkna"],
        },
        "Electricity": {
            "Power Outage": ["power cut", "no electricity", "bijli gayi", "light nahi"],
            "Street Light": ["street light off", "pole light off", "street lamp not working"],
            "Exposed Wires": ["open wire", "exposed wire", "khuli wire"],
            "Transformer Issue": ["transformer problem", "transformer blast"],
        },
        "Water Supply": {
            "No Water": ["no water", "water not coming", "pani nahi aa raha"],
            "Water Leakage": ["water leak", "pipe leak", "pani leak"],
            "Dirty Water": ["dirty water", "contaminated water", "ganda pani"],
            "Low Pressure": ["low pressure", "weak water flow", "kam pressure"],
        },
        "Traffic": {
            "Illegal Parking": ["illegal parking", "wrong parking", "galat parking"],
            "Broken Signal": ["signal not working", "traffic light broken", "signal kharab"],
            "Wrong Side": ["wrong side driving", "one way violation", "wrong side"],
            "Overspeeding": ["overspeeding", "fast driving", "rash driving", "tez gaadi"],
        },
        "Cyber Crime": {
            "Online Fraud": ["fraud", "scam", "online fraud", "money lost", "dhoka"],
            "UPI Scam": ["upi fraud", "payment scam", "phonepe fraud"],
            "Phishing": ["phishing", "fake link", "suspicious link"],
            "Identity Theft": ["identity theft", "account hacked", "data stolen"],
        },
        "Construction": {
            "Illegal Construction": ["illegal building", "unauthorized construction"],
            "Construction Debris": ["debris", "construction waste", "malba"],
            "Noise Pollution": ["construction noise", "loud noise", "shor"],
        },
    }

    CATEGORY_ALIASES = {
        "Road/Pothole": ["road", "sadak", "gadda", "pothole"],
        "Drainage/Sewage": ["drain", "nali", "sewer", "gutter"],
        "Garbage/Sanitation": ["garbage", "kachra", "kooda", "waste"],
        "Electricity": ["bijli", "light", "power", "wire"],
        "Water Supply": ["water", "pani", "tap", "pipeline"],
        "Traffic": ["traffic", "signal", "parking"],
        "Cyber Crime": ["cyber", "fraud", "upi", "phishing"],
        "Construction": ["construction", "building", "debris", "noise"],
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

    def __init__(self) -> None:
        self.model = None
        self.genai_client = None
        self.genai_backend = "none"
        self.model_name = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")
        api_key = getattr(settings, "GEMINI_API_KEY", None)
        if api_key and google_genai is not None:
            try:
                self.genai_client = google_genai.Client(api_key=api_key)
                self.genai_backend = "google.genai"
            except Exception:
                self.genai_client = None
                self.genai_backend = "none"
        if self.genai_client is None and api_key:
            try:
                global legacy_genai
                if legacy_genai is None:
                    import google.generativeai as legacy_genai  # type: ignore
                legacy_genai.configure(api_key=api_key)
                self.model = legacy_genai.GenerativeModel(self.model_name)
                self.genai_backend = "legacy"
            except Exception:
                self.model = None
                self.genai_backend = "none"
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
                return cls._sessions[sid]
            obj = cls()
            cls._sessions[sid] = obj
            return obj

    @classmethod
    def clear_session(cls, session_id: str) -> None:
        sid = cls._clean_session_id(session_id)
        with cls._sessions_lock:
            cls._sessions.pop(sid, None)

    def get_history(self) -> List[Dict[str, Any]]:
        return [dict(item) for item in self.conversation_history]

    @classmethod
    def _clean_session_id(cls, session_id: Optional[str]) -> str:
        raw = (session_id or "default").strip() or "default"
        if len(raw) > 128:
            raw = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        return re.sub(r"[^a-zA-Z0-9_\-.]", "_", raw)

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
        for intent, pattern in self.INTENTS.items():
            if pattern.search(lower):
                return intent
        return "complaint"

    def generate_response(self, user_input: str, user_email: Optional[str] = None) -> Dict[str, Any]:
        text = (user_input or "").strip()
        if not text:
            return {"response": "Please describe your issue so I can help.", "detected_category": None, "urgency": "medium", "emotion": "neutral", "language": "english", "next_step": "issue_capture"}

        lang = self.detect_language(text)
        emotion = self.detect_emotion(text)
        urgency = self.detect_urgency(text)
        emergency = self.is_emergency(text, urgency)
        intent = self.detect_intent(text)

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
        second = scored[1][2] if len(scored) > 1 else 0.0
        conf = max(0.22, min(0.98, best[2] / max(1.0, best[2] + second)))
        alternatives = [f"{s} ({c})" for c, s, sc, _ in scored[1:] if sc >= max(2.0, best[2] - 2.5)]
        return best[0], best[1], conf, list(dict.fromkeys(alternatives))[:4], best[3][:4]

    def _detect_with_corpus(self, norm: str) -> List[Tuple[str, str, float, List[str]]]:
        tokens = {t for t in norm.split() if len(t) >= 3}
        if not tokens:
            return []
        out: Dict[Tuple[str, str], float] = {}
        sig: Dict[Tuple[str, str], List[str]] = {}
        for row in KNOWLEDGE_CORPUS[:20000]:
            row_text = self._normalize(str(row.get("text", "")))
            row_tokens = {x for x in row_text.split() if len(x) >= 3}
            if not row_tokens:
                continue
            overlap = len(tokens & row_tokens)
            if overlap == 0:
                continue
            key = (str(row.get("category", "")), str(row.get("subcategory", "")))
            out[key] = out.get(key, 0.0) + (overlap / max(1, len(row_tokens))) * 3.0
            sig.setdefault(key, []).extend(list(tokens & row_tokens)[:3])
        ranked = sorted(out.items(), key=lambda kv: kv[1], reverse=True)[:8]
        return [(k[0], k[1], v, list(dict.fromkeys(sig.get(k, [])))[:4]) for k, v in ranked if v >= 1.5]

    def _offline_reply(self, analysis: Analysis, missing: List[str], actions: List[str]) -> str:
        if analysis.intent == "greeting":
            return "Hello! I am your Smart City AI assistant. Tell me your issue and I will map category, urgency, and next actions."
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
            return "Your safety comes first. If there is immediate danger, call 112 now.\n\nPlease share exact location and nearest landmark immediately."

        if analysis.category and analysis.subcategory:
            core = f"Detected issue: {analysis.subcategory} under {analysis.category} (confidence {int(analysis.confidence * 100)}%)."
        elif analysis.alternatives:
            core = f"I found close matches: {', '.join(analysis.alternatives[:3])}."
        else:
            core = "I am analyzing your issue and need one more detail for accurate categorization."

        question = self._next_question(missing, analysis)
        action_text = "\n".join([f"{i + 1}. {a}" for i, a in enumerate(actions[:3])])
        return f"{core}\n\nStill needed: {', '.join(missing) if missing else 'none'}.\n{question}\nNext actions:\n{action_text}"

    def _maybe_model_reply(self, user_text: str, analysis: Analysis, missing: List[str], fallback: str) -> str:
        if self.genai_client is None and self.model is None:
            return fallback
        prompt = f"Return one concise helpful answer. language={analysis.language}, intent={analysis.intent}, category={analysis.category}, subcategory={analysis.subcategory}, urgency={analysis.urgency}, emergency={analysis.is_emergency}, missing={missing}, alternatives={analysis.alternatives}. user={user_text}. fallback={fallback}"
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
            return "Is this related to road, drainage, water, electricity, garbage, traffic, cyber, or construction?"
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
