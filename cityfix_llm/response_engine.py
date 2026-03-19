"""
CityFix LLM — Response Engine
Converts model predictions + conversation state into natural responses.
Supports English, Hindi, Gujarati, Hinglish.
"""
import re
from typing import Optional


# ── Response Templates ─────────────────────────────────────────────────────────
TEMPLATES = {
    "greeting": {
        "english":  "Hello {name} 😊 I'm CityFix AI. Tell me your issue in one line — I'll detect the category, urgency, and guide you to submit it.",
        "hindi":    "Namaste {name} 😊 Main CityFix AI hoon. Apni problem ek line mein batao — main category, urgency aur next step turant bataunga.",
        "gujarati": "Namaste {name} 😊 Hu CityFix AI chhu. Tamari samasya ek line ma kaho — hu category, taatkalikata ane aage nu paglun batavish.",
    },
    "emergency": {
        "english":  "🚨 This looks like an emergency! Call 112 immediately if there is danger.\n\nPlease share your exact location and nearest landmark right now.",
        "hindi":    "🚨 Yeh emergency lagti hai! Agar khatara hai toh abhi 112 call karo.\n\nKripya abhi apna exact location aur nearest landmark share karo.",
        "gujarati": "🚨 Aa taatkaalik lagey chhe! Jokhe hoy to haman 112 par call karo.\n\nKrupaya haman tamaro exact location ane najikno landmark share karo.",
    },
    "detected": {
        "english":  "Got it ✅ I've detected this as **{category}** → **{subcategory}**.\nUrgency: {urgency} | Emotion: {emotion}\n\n{next_question}",
        "hindi":    "Samajh gaya ✅ Yeh **{category}** → **{subcategory}** hai.\nUrgency: {urgency} | Emotion: {emotion}\n\n{next_question}",
        "gujarati": "Samjhi gayo ✅ Aa **{category}** → **{subcategory}** chhe.\nTaatkalikata: {urgency} | Lagni: {emotion}\n\n{next_question}",
    },
    "low_confidence": {
        "english":  "🔍 Hmm, I’m guessing this is: {alternatives}. Could you please check and share the exact issue?",
        "hindi":    "🔍 Lagta hai yeh ho sakta hai: {alternatives}. Kripya confirm karke bataiye.",
        "gujarati": "🔍 Lagey chhe aa hoi shake chhe: {alternatives}. Krupaya confirm kari ne bataavo.",
    },
    "fallback": {
        "english":  "😅 Oops, I didn’t catch that clearly — can you rephrase the issue in simple words? We’ll solve it together.",
        "hindi":    "😅 Arre, thoda sa clear nahi hua — kya aap phir se simple shabdon mein bata sakte hain? Hum saath milke solve karenge.",
        "gujarati": "😅 Oho, thodu spasht nathi thatu — tame fari ek saaro saaro shabdoma kahi shako? Aapde sathma solve kariye.",
    },
    "ask_location": {
        "english":  "📍 Please share the exact area, street name, and nearest landmark.",
        "hindi":    "📍 Kripya exact area, street ka naam aur nearest landmark batao.",
        "gujarati": "📍 Krupaya exact area, street nu naam ane najikno landmark janaavo.",
    },
    "ask_description": {
        "english":  "Please describe what happened in one clear sentence.",
        "hindi":    "Kripya ek clear sentence mein batao kya hua.",
        "gujarati": "Krupaya ek spashtpane vakya ma janaavo shu thayun.",
    },
    "ask_time": {
        "english":  "When did this start? Is it happening repeatedly?",
        "hindi":    "Yeh kab se ho raha hai? Kya yeh baar baar hota hai?",
        "gujarati": "Aa kyaarthi sharu thayun? Shya aa vaarthi vaart thay chhe?",
    },
    "summary_ready": {
        "english":  "✅ Your complaint draft is ready!\n\n📋 Category: {category}\n🔖 Subcategory: {subcategory}\n📍 Location: {location}\n⚡ Urgency: {urgency}\n📝 Description: {description}\n\nShall I submit this complaint?",
        "hindi":    "✅ Aapka complaint draft taiyar hai!\n\n📋 Category: {category}\n🔖 Subcategory: {subcategory}\n📍 Location: {location}\n⚡ Urgency: {urgency}\n📝 Description: {description}\n\nKya main yeh complaint submit karun?",
        "gujarati": "✅ Tamaro fariyad draft taiyar chhe!\n\n📋 Category: {category}\n🔖 Subcategory: {subcategory}\n📍 Location: {location}\n⚡ Urgency: {urgency}\n📝 Description: {description}\n\nShya hu aa fariyad submit karu?",
    },
    "progress_1_missing": {
        "english":  "Almost there ✅ Just one more detail needed.",
        "hindi":    "Bas ek aur detail chahiye ✅",
        "gujarati": "Bas ek vat jankari joiye ✅",
    },
    "progress_2_missing": {
        "english":  "Good progress! I need two more details.",
        "hindi":    "Achha progress! Mujhe do aur details chahiye.",
        "gujarati": "Saaru progress! Mane be vat jankari joiye.",
    },
    "progress_many_missing": {
        "english":  "Let me help you file this complaint step by step.",
        "hindi":    "Main aapko step by step complaint file karne mein help karunga.",
        "gujarati": "Hu tamne step by step fariyad file karva madadrup thavish.",
    },
}

NEXT_QUESTIONS = {
    "issue_category": {
        "english":  "Is this related to police, traffic, water, electricity, garbage, road, drainage, construction, cyber, or other?",
        "hindi":    "Kya yeh police, traffic, paani, bijli, kachra, sadak, nali, nirman, cyber ya kuch aur se related hai?",
        "gujarati": "Shya aa police, traffic, paani, veeji, kachro, rasto, nali, bandhkam, cyber ke bija koi vishay sathe sambandhi chhe?",
    },
    "exact_location": {
        "english":  "📍 Where exactly is this happening? Share area, street, and landmark.",
        "hindi":    "📍 Yeh exactly kahan ho raha hai? Area, street aur landmark batao.",
        "gujarati": "📍 Aa exactly kyaa thay chhe? Area, street ane landmark janaavo.",
    },
    "issue_description": {
        "english":  "Can you describe the issue in one sentence?",
        "hindi":    "Kya aap ek sentence mein problem describe kar sakte hain?",
        "gujarati": "Shya tame ek vakya ma samasya describe kari shako?",
    },
}

URGENCY_LABELS = {
    "english":  {"low": "Low", "medium": "Medium", "high": "High", "critical": "Critical 🚨"},
    "hindi":    {"low": "Kam", "medium": "Madhyam", "high": "Zyada", "critical": "Atyant Zaruri 🚨"},
    "gujarati": {"low": "Ochhu", "medium": "Madhyam", "high": "Vadhu", "critical": "Taatkaalik 🚨"},
}

EMOTION_LABELS = {
    "english":  {"neutral": "Calm", "frustrated": "Frustrated", "scared": "Scared", "angry": "Angry"},
    "hindi":    {"neutral": "Shaant", "frustrated": "Pareshan", "scared": "Dara hua", "angry": "Gusse mein"},
    "gujarati": {"neutral": "Shaant", "frustrated": "Pareshaan", "scared": "Dareloo", "angry": "Gusse ma"},
}


class ResponseEngine:
    def __init__(self):
        pass

    def _lang(self, language: str) -> str:
        if language in ("hindi", "hinglish"):
            return "hindi"
        if language == "gujarati":
            return "gujarati"
        return "english"

    def _tpl(self, key: str, language: str, **kwargs) -> str:
        lang = self._lang(language)
        tpl = TEMPLATES.get(key, {}).get(lang, TEMPLATES.get(key, {}).get("english", ""))
        return tpl.format(**kwargs)

    def _urgency_label(self, urgency: str, language: str) -> str:
        lang = self._lang(language)
        return URGENCY_LABELS.get(lang, URGENCY_LABELS["english"]).get(urgency, urgency)

    def _emotion_label(self, emotion: str, language: str) -> str:
        lang = self._lang(language)
        return EMOTION_LABELS.get(lang, EMOTION_LABELS["english"]).get(emotion, emotion)

    def _next_q(self, missing: list, language: str) -> str:
        lang = self._lang(language)
        for field in ["issue_category", "exact_location", "issue_description"]:
            if field in missing:
                return NEXT_QUESTIONS[field].get(lang, NEXT_QUESTIONS[field]["english"])
        return ""

    def _progress_msg(self, missing: list, language: str) -> str:
        lang = self._lang(language)
        if len(missing) == 0:
            return TEMPLATES["summary_ready"].get(lang, "")
        if len(missing) == 1:
            return TEMPLATES["progress_1_missing"].get(lang, "")
        if len(missing) == 2:
            return TEMPLATES["progress_2_missing"].get(lang, "")
        return TEMPLATES["progress_many_missing"].get(lang, "")

    def build(
        self,
        prediction: dict,
        session: dict,
        user_name: str = "Citizen",
    ) -> dict:
        """
        prediction: output from CityFixInference.predict()
        session: {
            category, subcategory, location, description, time_hint,
            conversation_history, intent
        }
        Returns: { response, next_step, missing_fields }
        """
        lang      = prediction.get("language", "english")
        category  = prediction.get("category")
        subcat    = prediction.get("subcategory")
        urgency   = prediction.get("urgency", "low")
        emotion   = prediction.get("emotion", "neutral")
        emergency = prediction.get("is_emergency", False)
        confidence = prediction.get("confidence", 0.0)
        alternatives = prediction.get("alternatives", [])
        intent    = session.get("intent", "complaint")

        # Update session
        if category:
            session["category"] = category
        if subcat:
            session["subcategory"] = subcat
        if prediction.get("location"):
            session["location"] = prediction["location"]
        if prediction.get("time_hint"):
            session["time_hint"] = prediction["time_hint"]

        # Determine missing fields
        missing = []
        if not session.get("category"):
            missing.append("issue_category")
        if not session.get("location"):
            missing.append("exact_location")
        if not session.get("description"):
            missing.append("issue_description")

        # ── Emergency ──────────────────────────────────────────────────────────
        if emergency:
            response = self._tpl("emergency", lang)
            return {"response": response, "next_step": "emergency", "missing_fields": missing}

        # ── Greeting ───────────────────────────────────────────────────────────
        if intent == "greeting":
            response = self._tpl("greeting", lang, name=user_name)
            return {"response": response, "next_step": "intake", "missing_fields": missing}

        # ── Summary request ────────────────────────────────────────────────────
        if intent == "summary" and not missing:
            response = self._tpl(
                "summary_ready", lang,
                category=session.get("category", "—"),
                subcategory=session.get("subcategory", "—"),
                location=session.get("location", "—"),
                urgency=self._urgency_label(urgency, lang),
                description=session.get("description", "—"),
            )
            return {"response": response, "next_step": "ready_to_submit", "missing_fields": []}

        # ── Low confidence / fallback ─────────────────────────────────────────
        if confidence < 0.25:
            response = self._tpl("fallback", lang)
            return {"response": response, "next_step": "gather_clarification", "missing_fields": missing}

        if confidence < 0.4 and alternatives:
            alts = ", ".join(alternatives[:3])
            response = self._tpl("low_confidence", lang, alternatives=alts)
            return {"response": response, "next_step": "clarify_category", "missing_fields": missing}

        # ── Normal detected flow ───────────────────────────────────────────────
        progress = self._progress_msg(missing, lang)
        next_q   = self._next_q(missing, lang)

        if category and subcat:
            core = self._tpl(
                "detected", lang,
                category=category,
                subcategory=subcat,
                urgency=self._urgency_label(urgency, lang),
                emotion=self._emotion_label(emotion, lang),
                next_question=next_q,
            )
        else:
            core = next_q

        response = f"{progress}\n\n{core}".strip() if progress != core else core

        next_step = "ready_to_submit" if not missing else (
            "category_detection" if "issue_category" in missing else
            "location_gathering" if "exact_location" in missing else
            "detail_gathering"
        )

        return {
            "response":      response,
            "next_step":     next_step,
            "missing_fields": missing,
            "category":      session.get("category"),
            "subcategory":   session.get("subcategory"),
            "urgency":       urgency,
            "emotion":       emotion,
            "language":      lang,
            "is_emergency":  emergency,
            "confidence":    confidence,
        }
