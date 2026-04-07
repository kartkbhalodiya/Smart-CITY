# Advanced ML Voice Assistant System

## Overview

The ML Voice Assistant is an intelligent, context-aware conversation system that powers the JanHelp voice complaint filing feature. It uses advanced NLP, emotion detection, and smart response generation to provide a human-like, empathetic experience.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER MOBILE APP                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Voice Call Screen                                   │   │
│  │  - Gemini Native Audio (Speech-to-Text/Text-to-Speech) │
│  │  - Real-time transcript display                      │   │
│  │  - UI state management                               │   │
│  └────────────────────┬─────────────────────────────────┘   │
└───────────────────────┼─────────────────────────────────────┘
                        │
                        ▼ HTTP REST API
┌─────────────────────────────────────────────────────────────┐
│              DJANGO ML BACKEND (Python)                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MLVoiceAssistant (Main Controller)                  │   │
│  │  - Session management                                │   │
│  │  - Context tracking                                  │   │
│  │  - Intelligent response generation                   │   │
│  └────┬──────────┬──────────┬──────────┬────────────────┘   │
│       │          │          │          │                    │
│  ┌────▼────┐ ┌──▼────┐ ┌───▼────┐ ┌───▼──────────┐         │
│  │ Emotion │ │Context│ │Response│ │ Date         │         │
│  │Detector │ │Manager│ │Generator│ │ Resolver     │         │
│  └─────────┘ └───────┘ └────────┘ └──────────────┘         │
│                                                              │
│  Features:                                                   │
│  ✓ Emotion detection (urgent/angry/worried/calm)            │
│  ✓ Urgency classification (critical/high/medium/low)        │
│  ✓ Emergency detection (life-threatening situations)        │
│  ✓ Context-aware responses with empathy                     │
│  ✓ Relative date resolution (2 din pehle → 2025-01-08)     │
│  ✓ Smart data extraction per conversation stage             │
│  ✓ Conversation history tracking                            │
│  ✓ Session persistence (Redis/Cache)                        │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. EmotionDetector

Analyzes user speech to detect emotional state and urgency level.

**Capabilities:**
- **Emotion Detection**: urgent, angry, worried, calm, neutral
- **Urgency Classification**: critical, high, medium, low
- **Emergency Detection**: Identifies life-threatening situations
- **Empathy Trigger**: Flags when empathetic response is needed

**Example:**
```python
emotion_data = EmotionDetector.detect("Mera ghar mein aag lag gayi hai!")
# Returns:
{
    'emotion': 'urgent',
    'urgency': 'critical',
    'is_emergency': True,
    'requires_empathy': True
}
```

### 2. ContextManager

Maintains conversation state and history across the session.

**Features:**
- Stores full conversation history with timestamps
- Tracks metadata (extracted data, user preferences)
- Provides context summaries for AI
- Manages conversation stage transitions

**Example:**
```python
context = ContextManager()
context.add_turn('user', 'Pothole hai road pe', {'emotion': 'worried'})
context.add_turn('assistant', 'Achha, road problem hai na?')
summary = context.get_context_summary()
```

### 3. ResponseGenerator

Generates natural, context-aware, empathetic responses.

**Capabilities:**
- Stage-specific prompts (greeting, problem, address, etc.)
- Emotion-based empathy responses
- Context-aware response modification
- Multilingual support (Hindi, English, Gujarati, Hinglish)

**Example:**
```python
response = ResponseGenerator.generate_empathy_response('urgent')
# Returns: "Arre! Yeh toh serious hai!"

prompt = ResponseGenerator.generate_stage_prompt('problem', {'emotion': 'urgent'})
# Returns: "Arre! Yeh toh serious hai! Batao ji, kya problem hai?"
```

### 4. DateResolver

Converts relative dates to absolute ISO format dates.

**Supported Patterns:**
- Today: "aaj", "today", "abhi"
- Yesterday: "kal", "yesterday"
- Days ago: "2 din pehle", "3 days ago"
- Weeks ago: "1 hafte pehle", "2 weeks ago"
- Months ago: "1 mahine pehle", "3 months ago"

**Example:**
```python
resolved = DateResolver.resolve("2 din pehle")
# Returns: "2025-01-08" (if today is 2025-01-10)
```

### 5. MLVoiceAssistant

Main orchestrator that combines all components.

**Workflow:**
1. Receives user input + current stage
2. Detects emotion and urgency
3. Extracts stage-specific data
4. Generates intelligent response
5. Determines next stage
6. Updates context history
7. Returns complete result

## API Endpoints

### POST /api/ml-voice/process/
Main processing endpoint for voice input.

**Request:**
```json
{
  "session_id": "optional-uuid",
  "text": "Mera ghar ke paas bada pothole hai",
  "stage": "problem",
  "context": {
    "category": "",
    "address": ""
  }
}
```

**Response:**
```json
{
  "success": true,
  "session_id": "uuid-here",
  "response": "Arre! Ghar ke paas bada pothole hai. Road problem hai na?",
  "emotion": {
    "emotion": "worried",
    "urgency": "medium",
    "is_emergency": false,
    "requires_empathy": true
  },
  "next_stage": "address",
  "extracted_data": {
    "category": "road",
    "subcategory": "pothole",
    "description": "Ghar ke paas bada pothole hai"
  },
  "requires_emergency": false,
  "context_summary": "..."
}
```

### POST /api/ml-voice/emotion/
Detect emotion from text.

**Request:**
```json
{
  "text": "Bahut urgent hai, jaldi karo"
}
```

**Response:**
```json
{
  "success": true,
  "emotion": "urgent",
  "urgency": "high",
  "is_emergency": false,
  "requires_empathy": true
}
```

### POST /api/ml-voice/resolve-date/
Resolve relative date to absolute date.

**Request:**
```json
{
  "text": "2 din pehle"
}
```

**Response:**
```json
{
  "success": true,
  "original": "2 din pehle",
  "resolved": "2025-01-08",
  "formatted": "8 January 2025"
}
```

### GET /api/ml-voice/session/{session_id}/
Get conversation summary.

**Response:**
```json
{
  "success": true,
  "session_id": "uuid",
  "history": [
    {
      "role": "user",
      "text": "Pothole hai",
      "timestamp": "2025-01-10T10:30:00",
      "metadata": {"emotion": "worried"}
    }
  ],
  "metadata": {},
  "stage": "problem",
  "turn_count": 5
}
```

### POST /api/ml-voice/session/{session_id}/reset/
Reset session state.

### POST /api/ml-voice/generate-response/
Generate intelligent response for a stage.

## Flutter Integration

### MLVoiceService

Flutter service that communicates with ML backend.

**Usage:**
```dart
// Process user input
final result = await MLVoiceService.processInput(
  text: userSpeech,
  stage: 'problem',
  context: {'category': 'road'},
);

if (result['success']) {
  final aiResponse = result['response'];
  final emotion = result['emotion'];
  final nextStage = result['next_stage'];
  final extractedData = result['extracted_data'];
}

// Detect emotion
final emotion = await MLVoiceService.detectEmotion(userSpeech);

// Resolve date
final dateResult = await MLVoiceService.resolveDate("2 din pehle");
final isoDate = dateResult['resolved']; // "2025-01-08"

// Get session summary
final summary = await MLVoiceService.getSessionSummary();

// Reset session
await MLVoiceService.resetSession();
```

## Emergency Handling

The system uses a **dual approach** for emergencies:

### Life-Threatening Emergencies
- Fire actively burning
- Medical emergency (heart attack, unconscious)
- Crime in progress (robbery, assault)
- Person trapped

**Response:**
```
"Arre! Yeh toh emergency hai! Pehle 112 pe call karo — 
ambulance/police turant aayegi. Main complaint bhi file kar 
deti hoon. Batao, exact location kya hai?"
```

Then **continues** filing complaint (doesn't stop process).

### Non-Emergency Serious Issues
- Accidents that already happened
- Injuries (not life-threatening)
- Dangerous conditions (hanging wires, potholes)
- Property damage

**Response:**
```
"Arre! Yeh toh serious hai! [Shows empathy] 
Chalo complaint file karte hain."
```

Files complaint normally without mentioning 112.

## Performance Metrics

- **Emotion Detection**: < 50ms
- **Date Resolution**: < 20ms
- **ML Processing**: < 200ms
- **Total Response Time**: < 300ms (excluding network)

## Conversation Flow

```
1. GREETING
   User: [Joins call]
   AI: "Namaste! Main Priya bol rahi hoon..."
   
2. PROBLEM (ML-powered)
   User: "Ghar ke paas bada pothole hai, bike ka accident hua"
   ML: Detects emotion=worried, urgency=medium, category=road
   AI: "Arre! Pothole ki wajah se accident hua. Road problem hai na?"
   
3. ADDRESS
   User: "123 MG Road, Ahmedabad"
   ML: Extracts address, detects pincode
   AI: "123 MG Road - noted! Map button dikhega."
   
4. DATE
   User: "2 din pehle"
   ML: Resolves to "2025-01-08"
   AI: "Ohh toh 8 January. Sahi hai na?"
   
5. CONFIRM & SUBMIT
   AI: "Perfect! Complaint submit karoon?"
   User: "Haan"
   [Submits complaint]
```

## Benefits

✅ **Human-like Conversation**: Natural, empathetic responses
✅ **Context Awareness**: Remembers conversation history
✅ **Emotion Intelligence**: Adapts tone based on user emotion
✅ **Smart Emergency Detection**: Dual approach for safety
✅ **Fast Processing**: < 300ms response time
✅ **Multilingual**: Hindi, English, Gujarati, Hinglish
✅ **Scalable**: Session-based architecture with Redis support
✅ **Fallback Logic**: Works even if ML backend is down

## Future Enhancements

- [ ] Real-time sentiment analysis
- [ ] Voice tone analysis (pitch, speed)
- [ ] Predictive category suggestion
- [ ] Multi-turn context understanding
- [ ] Personalized responses based on user history
- [ ] Integration with Google Gemini for advanced NLU
- [ ] Support for more Indian languages (Tamil, Telugu, Bengali)

## Deployment

### Requirements
```
Django >= 5.2
google-generativeai >= 0.3.0
redis >= 4.0 (optional, for production)
```

### Environment Variables
```env
GEMINI_API_KEY=your-gemini-api-key
REDIS_URL=redis://localhost:6379/0  # Optional
```

### Production Setup
1. Use Redis for session storage (not in-memory dict)
2. Enable caching for faster responses
3. Set up monitoring for ML processing times
4. Configure rate limiting on API endpoints
5. Use CDN for static assets

---

**Built with ❤️ for JanHelp — Making civic complaints accessible to everyone**
