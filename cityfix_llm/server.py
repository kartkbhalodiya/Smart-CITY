"""
CityFix LLM — FastAPI Server
Deploy: uvicorn server:app --host 0.0.0.0 --port $PORT
"""
import os
import re
import time
import uuid
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ── Lazy imports (loaded at startup) ──────────────────────────────────────────
inference_engine = None
response_engine  = None
import os
sessions: dict   = {}   # in-memory session store (replace with Redis in prod)
PORT = int(os.environ.get("PORT", 7860))


@asynccontextmanager
async def lifespan(app: FastAPI):
    global inference_engine, response_engine
    print("Loading CityFix LLM model...")
    t0 = time.time()
    try:
        from model import CityFixInference
        from response_engine import ResponseEngine
        inference_engine = CityFixInference()
        response_engine  = ResponseEngine()
        print(f"Model loaded in {time.time()-t0:.2f}s ✅")
    except Exception as e:
        print(f"Model load failed: {e} — running in fallback mode")
    yield
    print("Shutting down CityFix LLM server")


app = FastAPI(
    title="CityFix LLM",
    description="Domain-specific AI for Smart City complaint assistance",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response Schemas ─────────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    user_name: Optional[str] = "Citizen"
    user_email: Optional[str] = None
    preferred_language: Optional[str] = "english"


class ChatResponse(BaseModel):
    response: str
    session_id: str
    detected_category: Optional[str]
    detected_subcategory: Optional[str]
    urgency: str
    emotion: str
    language: str
    is_emergency: bool
    confidence: float
    next_step: str
    missing_fields: list
    alternatives: list
    processing_ms: int


class PredictRequest(BaseModel):
    text: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    version: str


# ── Helpers ────────────────────────────────────────────────────────────────────
GREETING_RE = re.compile(r"\b(hi|hello|hey|namaste|helo|hii)\b", re.I)
SUMMARY_RE  = re.compile(r"\b(summary|summarize|submit now|ready to submit|show summary)\b", re.I)

EMERGENCY_KEYWORDS = [
    "fire", "blast", "collapse", "dead body", "murder", "rape", "kidnap",
    "accident", "emergency", "112", "help help", "maaro", "bachao", "save me",
    "exposed wire", "live wire", "gas leak",
]

FALLBACK_RESPONSES = {
    "english":  "I understand your concern. Could you tell me more about the issue — what type of problem is it and where is it located?",
    "hindi":    "Main aapki baat samajh raha hoon. Kya aap problem ke baare mein aur bata sakte hain — kya problem hai aur kahan hai?",
    "gujarati": "Hu tamari vat samjhu chhu. Shya tame samasya vishe vadhu kahi shako — shu samasya chhe ane kyaa chhe?",
}


def detect_intent(text: str) -> str:
    if GREETING_RE.search(text):
        return "greeting"
    if SUMMARY_RE.search(text):
        return "summary"
    t = text.lower()
    if any(kw in t for kw in EMERGENCY_KEYWORDS):
        return "emergency"
    return "complaint"


def get_or_create_session(session_id: Optional[str], user_name: str, preferred_language: str) -> tuple[str, dict]:
    if not session_id or session_id not in sessions:
        session_id = session_id or str(uuid.uuid4())
        sessions[session_id] = {
            "category":    None,
            "subcategory": None,
            "location":    None,
            "description": None,
            "time_hint":   None,
            "user_name":   user_name,
            "language":    preferred_language,
            "history":     [],
            "intent":      "complaint",
        }
    return session_id, sessions[session_id]


def extract_description(session: dict, text: str) -> None:
    """Store long messages as description."""
    if len(text) >= 20 and not session.get("description"):
        session["description"] = text


# ── Routes ─────────────────────────────────────────────────────────────────────
@app.get("/health", response_model=HealthResponse)
def health():
    return {
        "status": "ok",
        "model_loaded": inference_engine is not None,
        "version": "1.0.0",
    }


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    t0 = time.time()

    session_id, session = get_or_create_session(
        req.session_id, req.user_name or "Citizen", req.preferred_language or "english"
    )

    # Update session user info
    if req.user_name:
        session["user_name"] = req.user_name
    if req.preferred_language:
        session["language"] = req.preferred_language

    # Detect intent
    session["intent"] = detect_intent(req.message)

    # Extract description
    extract_description(session, req.message)

    # Push to history
    session["history"].append({"role": "user", "content": req.message})
    if len(session["history"]) > 20:
        session["history"] = session["history"][-20:]

    # ── Model inference ────────────────────────────────────────────────────────
    if inference_engine is not None:
        try:
            prediction = inference_engine.predict(req.message)
            # Override language with user preference if set
            if req.preferred_language and req.preferred_language != "english":
                prediction["language"] = req.preferred_language
        except Exception as e:
            prediction = {
                "category": None, "subcategory": None,
                "urgency": "low", "emotion": "neutral",
                "language": req.preferred_language or "english",
                "is_emergency": False, "confidence": 0.0,
                "alternatives": [],
            }
    else:
        # Fallback when model not loaded
        lang = req.preferred_language or "english"
        response_text = FALLBACK_RESPONSES.get(lang, FALLBACK_RESPONSES["english"])
        ms = int((time.time() - t0) * 1000)
        session["history"].append({"role": "assistant", "content": response_text})
        return ChatResponse(
            response=response_text,
            session_id=session_id,
            detected_category=None,
            detected_subcategory=None,
            urgency="low",
            emotion="neutral",
            language=lang,
            is_emergency=False,
            confidence=0.0,
            next_step="intake",
            missing_fields=["issue_category", "exact_location", "issue_description"],
            alternatives=[],
            processing_ms=ms,
        )

    # ── Build response ─────────────────────────────────────────────────────────
    result = response_engine.build(
        prediction=prediction,
        session=session,
        user_name=session.get("user_name", "Citizen"),
    )

    response_text = result["response"]
    session["history"].append({"role": "assistant", "content": response_text})

    ms = int((time.time() - t0) * 1000)

    return ChatResponse(
        response=response_text,
        session_id=session_id,
        detected_category=result.get("category"),
        detected_subcategory=result.get("subcategory"),
        urgency=result.get("urgency", "low"),
        emotion=result.get("emotion", "neutral"),
        language=result.get("language", "english"),
        is_emergency=result.get("is_emergency", False),
        confidence=result.get("confidence", 0.0),
        next_step=result.get("next_step", "intake"),
        missing_fields=result.get("missing_fields", []),
        alternatives=prediction.get("alternatives", []),
        processing_ms=ms,
    )


@app.post("/predict")
def predict(req: PredictRequest):
    """Raw model prediction — no session, no response building."""
    if inference_engine is None:
        raise HTTPException(503, "Model not loaded")
    return inference_engine.predict(req.text)


@app.delete("/session/{session_id}")
def reset_session(session_id: str):
    if session_id in sessions:
        del sessions[session_id]
    return {"status": "cleared", "session_id": session_id}


@app.get("/session/{session_id}")
def get_session(session_id: str):
    if session_id not in sessions:
        raise HTTPException(404, "Session not found")
    s = sessions[session_id]
    return {
        "session_id":  session_id,
        "category":    s.get("category"),
        "subcategory": s.get("subcategory"),
        "location":    s.get("location"),
        "description": s.get("description"),
        "urgency":     s.get("urgency"),
        "language":    s.get("language"),
        "history_len": len(s.get("history", [])),
    }


@app.get("/")
def root():
    return {
        "name":    "CityFix LLM",
        "version": "1.0.0",
        "status":  "running",
        "endpoints": ["/chat", "/predict", "/health", "/session/{id}"],
    }
