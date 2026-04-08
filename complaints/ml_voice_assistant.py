"""
Advanced ML-powered Voice Assistant Backend
Handles intelligent conversation, emotion detection, and smart response generation
"""

import re
import json
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import google.generativeai as genai
from django.conf import settings


class EmotionDetector:
    """Detects user emotion and urgency from speech"""
    
    EMOTION_PATTERNS = {
        'urgent': ['jaldi', 'turant', 'abhi', 'emergency', 'serious', 'bahut bura', 'critical'],
        'angry': ['gussa', 'angry', 'frustrated', 'pareshan', 'tang', 'fed up'],
        'worried': ['tension', 'worried', 'dar', 'scared', 'chinta', 'problem'],
        'calm': ['theek', 'okay', 'fine', 'normal', 'sahi'],
    }
    
    URGENCY_KEYWORDS = {
        'critical': ['fire', 'aag', 'heart attack', 'unconscious', 'robbery', 'assault', 'trapped'],
        'high': ['accident', 'injury', 'bleeding', 'electric shock', 'wire hanging', 'collapse'],
        'medium': ['leak', 'overflow', 'broken', 'damaged', 'not working'],
        'low': ['dirty', 'ganda', 'smell', 'noise', 'complaint'],
    }
    
    @classmethod
    def detect(cls, text: str) -> Dict[str, any]:
        """Detect emotion and urgency level"""
        text_lower = text.lower()
        
        # Detect emotion
        emotion = 'neutral'
        for emo, keywords in cls.EMOTION_PATTERNS.items():
            if any(kw in text_lower for kw in keywords):
                emotion = emo
                break
        
        # Detect urgency
        urgency = 'low'
        for level, keywords in cls.URGENCY_KEYWORDS.items():
            if any(kw in text_lower for kw in keywords):
                urgency = level
                break
        
        # Check if life-threatening emergency
        is_emergency = urgency == 'critical'
        
        return {
            'emotion': emotion,
            'urgency': urgency,
            'is_emergency': is_emergency,
            'requires_empathy': emotion in ['angry', 'worried'] or urgency in ['critical', 'high']
        }


class ContextManager:
    """Manages conversation context and history"""
    
    def __init__(self):
        self.history: List[Dict] = []
        self.metadata: Dict = {}
        self.stage = 'greeting'
        
    def add_turn(self, role: str, text: str, metadata: Dict = None):
        """Add conversation turn"""
        self.history.append({
            'role': role,
            'text': text,
            'timestamp': datetime.now().isoformat(),
            'metadata': metadata or {}
        })
        
    def get_context_summary(self) -> str:
        """Get conversation summary for context"""
        if len(self.history) < 2:
            return ""
        
        recent = self.history[-4:]  # Last 4 turns
        summary = []
        for turn in recent:
            summary.append(f"{turn['role']}: {turn['text'][:100]}")
        return "\n".join(summary)
    
    def update_metadata(self, key: str, value: any):
        """Update conversation metadata"""
        self.metadata[key] = value

    def update_extracted_data(self, data: Dict):
        """Accumulates all extracted data from stages"""
        if 'accumulated_data' not in self.metadata:
            self.metadata['accumulated_data'] = {}
        for k, v in data.items():
            if v:  # Only update if value is present
                self.metadata['accumulated_data'][k] = v


class ResponseGenerator:
    """Generates natural, context-aware responses"""
    
    EMPATHY_RESPONSES = {
        'urgent': ['Arre! Yeh toh serious hai!', 'Ohh! Turant dekhna padega!', 'Haan ji, samajh gayi urgency!'],
        'angry': ['Haan ji, main samajh sakti hoon aapki pareshani.', 'Bilkul, yeh problem jaldi solve honi chahiye.'],
        'worried': ['Tension mat lo ji, main help karti hoon.', 'Haan, main poori tarah samajh rahi hoon.'],
        'calm': ['Achha, theek hai.', 'Haan ji, batao.'],
    }
    
    STAGE_PROMPTS = {
        'greeting': 'Namaste! Main Priya bol rahi hoon JANHELP se. Aap Hindi, English, Gujarati, ya Hinglish mein baat kar sakte ho.',
        'problem': 'Batao ji, kya problem hai? Main sun rahi hoon.',
        'address': 'Yeh problem kahan pe hai? Address batao.',
        'proof': 'Agar photo hai toh upload kar do - complaint jaldi process hogi.',
        'date': 'Yeh problem kab se hai?',
        'name': 'Aapka naam?',
        'phone': 'Mobile number?',
        'email': 'Email? Optional hai.',
        'confirm': 'Sab details sahi hain? Confirm karoon?',
    }
    
    @classmethod
    def generate_empathy_response(cls, emotion: str) -> str:
        """Generate empathetic response based on emotion"""
        responses = cls.EMPATHY_RESPONSES.get(emotion, cls.EMPATHY_RESPONSES['calm'])
        import random
        return random.choice(responses)
    
    @classmethod
    def generate_stage_prompt(cls, stage: str, context: Dict = None) -> str:
        """Generate stage-specific prompt"""
        base = cls.STAGE_PROMPTS.get(stage, '')
        
        # Add context if available
        if context and stage == 'problem':
            if context.get('emotion') in ['urgent', 'angry']:
                base = f"{cls.generate_empathy_response(context['emotion'])} {base}"
        
        return base


class DateResolver:
    """Resolves relative dates to absolute dates"""
    
    PATTERNS = {
        'today': r'\b(aaj|today|abhi)\b',
        'yesterday': r'\b(kal|yesterday)\b',
        'days_ago': r'\b(\d+)\s*(din|day|days)\s*(pehle|pahle|ago|back)\b',
        'weeks_ago': r'\b(\d+)\s*(week|hafte|hafta)\s*(pehle|pahle|ago)\b',
        'months_ago': r'\b(\d+)\s*(month|mahine|mahina)\s*(pehle|pahle|ago)\b',
    }
    
    @classmethod
    def resolve(cls, text: str) -> Optional[str]:
        """Resolve relative date to ISO format"""
        text_lower = text.lower()
        today = datetime.now()
        
        # Today
        if re.search(cls.PATTERNS['today'], text_lower):
            return today.strftime('%Y-%m-%d')
        
        # Yesterday
        if re.search(cls.PATTERNS['yesterday'], text_lower):
            return (today - timedelta(days=1)).strftime('%Y-%m-%d')
        
        # Days ago
        match = re.search(cls.PATTERNS['days_ago'], text_lower)
        if match:
            days = int(match.group(1))
            return (today - timedelta(days=days)).strftime('%Y-%m-%d')
        
        # Weeks ago
        match = re.search(cls.PATTERNS['weeks_ago'], text_lower)
        if match:
            weeks = int(match.group(1))
            return (today - timedelta(weeks=weeks)).strftime('%Y-%m-%d')
        
        # Months ago
        match = re.search(cls.PATTERNS['months_ago'], text_lower)
        if match:
            months = int(match.group(1))
            return (today - timedelta(days=months*30)).strftime('%Y-%m-%d')
        
        return None


class MLVoiceAssistant:
    """Main ML-powered voice assistant"""
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or getattr(settings, 'GEMINI_API_KEY', None)
        if self.api_key:
            genai.configure(api_key=self.api_key)
        
        self.context_manager = ContextManager()
        self.emotion_detector = EmotionDetector()
        self.response_generator = ResponseGenerator()
        self.date_resolver = DateResolver()
        
    def process_user_input(self, text: str, stage: str, context: Dict = None) -> Dict:
        """
        Process user input with ML intelligence
        Returns: {
            'response': str,
            'emotion': dict,
            'next_stage': str,
            'extracted_data': dict,
            'requires_emergency': bool
        }
        """
        # Detect emotion and urgency
        emotion_data = self.emotion_detector.detect(text)
        
        # Add to context
        self.context_manager.add_turn('user', text, emotion_data)
        self.context_manager.stage = stage
        
        # Extract data based on stage
        extracted_data = self._extract_stage_data(text, stage)
        
        # Generate intelligent response
        response = self._generate_intelligent_response(
            text, stage, emotion_data, extracted_data, context
        )
        
        # Update accumulated data in context
        self.context_manager.update_extracted_data(extracted_data)
        
        # Determine next stage
        next_stage = self._determine_next_stage(stage, extracted_data, emotion_data)
        
        # Add AI response to context
        self.context_manager.add_turn('assistant', response)
        
        result = {
            'response': response,
            'emotion': emotion_data,
            'next_stage': next_stage,
            'extracted_data': extracted_data,
            'requires_emergency': emotion_data['is_emergency'],
            'context_summary': self.context_manager.get_context_summary()
        }
        
        # If moving to submission, generate the finalized JSON payload
        if next_stage == 'submitting' or stage == 'confirm':
            result['final_payload'] = self.get_final_payload()
            
        return result
    
    def _extract_stage_data(self, text: str, stage: str) -> Dict:
        """Extract relevant data based on current stage"""
        data = {}
        
        if stage == 'problem':
            # Use smart complaint extractor (already exists)
            from complaints.smart_complaint_extractor import SmartComplaintExtractor
            extractor = SmartComplaintExtractor()
            data = extractor.extract(text)
        
        elif stage == 'address':
            data['address'] = text.strip()
            # Extract location hints
            location_match = re.search(r'\b(\d{6})\b', text)
            if location_match:
                data['pincode'] = location_match.group(1)
        
        elif stage == 'date':
            resolved_date = self.date_resolver.resolve(text)
            data['date_noticed'] = text.strip()
            data['resolved_date'] = resolved_date
        
        elif stage == 'name':
            # Clean name (remove phone numbers)
            cleaned = re.sub(r'\b[6-9]\d{9}\b', '', text).strip()
            data['contact_name'] = cleaned
        
        elif stage == 'phone':
            phone_match = re.search(r'\b[6-9]\d{9}\b', text)
            if phone_match:
                data['contact_phone'] = phone_match.group(0)
        
        elif stage == 'email':
            email_match = re.search(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', text)
            if email_match:
                data['contact_email'] = email_match.group(0)
        
        return data
    
    def _generate_intelligent_response(
        self, text: str, stage: str, emotion: Dict, extracted: Dict, context: Dict = None
    ) -> str:
        """Generate context-aware, empathetic response"""
        
        # Handle emergency first
        if emotion['is_emergency']:
            return (
                "Arre! Yeh toh emergency hai! Pehle 112 pe call karo - "
                "ambulance/police turant aayegi. Main complaint bhi file kar deti hoon. "
                "Batao, exact location kya hai?"
            )
        
        # Generate empathy prefix if needed
        empathy = ""
        if emotion['requires_empathy']:
            empathy = self.response_generator.generate_empathy_response(emotion['emotion']) + " "
        
        # Stage-specific responses
        if stage == 'problem' and extracted.get('category'):
            category = extracted.get('category', 'problem')
            summary = extracted.get('description', text)[:80]
            return f"{empathy}Achha, {summary}. {category} problem hai na? Sahi samjhi?"
        
        elif stage == 'address' and extracted.get('address'):
            address = extracted['address'][:50]
            return f"{address} - noted! Ab screen pe map button dikhega."
        
        elif stage == 'date' and extracted.get('resolved_date'):
            date_str = datetime.strptime(extracted['resolved_date'], '%Y-%m-%d').strftime('%d %B')
            return f"Ohh toh {date_str}. Sahi hai na?"
        
        elif stage == 'name' and extracted.get('contact_name'):
            return "Haan ji. Aur mobile number?"
        
        elif stage == 'phone' and extracted.get('contact_phone'):
            return "Theek hai. Email? Optional hai."
        
        elif stage == 'confirm':
            return "Perfect! Sab details sahi hain? Main complaint submit karoon?"
        
        # Default stage prompt
        return empathy + self.response_generator.generate_stage_prompt(stage, emotion)
    
    def _determine_next_stage(self, current_stage: str, extracted: Dict, emotion: Dict) -> str:
        """Determine next conversation stage"""
        
        stage_flow = {
            'greeting': 'problem',
            'problem': 'address' if extracted.get('category') else 'problem',
            'address': 'locationMap' if extracted.get('address') else 'address',
            'locationMap': 'proof',
            'proof': 'date',
            'date': 'dateConfirm' if extracted.get('resolved_date') else 'datePicker',
            'dateConfirm': 'name',
            'datePicker': 'name',
            'name': 'phone' if extracted.get('contact_name') else 'name',
            'phone': 'email' if extracted.get('contact_phone') else 'phone',
            'email': 'confirm',
            'confirm': 'submitting',
        }
        
        return stage_flow.get(current_stage, current_stage)
    
    def get_conversation_summary(self) -> Dict:
        """Get full conversation summary"""
        return {
            'history': self.context_manager.history,
            'metadata': self.context_manager.metadata,
            'stage': self.context_manager.stage,
            'turn_count': len(self.context_manager.history),
            'final_payload': self.get_final_payload()
        }
        
    def get_final_payload(self) -> Dict:
        """Returns the structured JSON format required for complaint submission mapping"""
        data = self.context_manager.metadata.get('accumulated_data', {})
        
        # Format the exact JSON structure required by the backend
        return {
            "category": data.get('category', 'Other'),
            "subcategory": data.get('subcategory', 'General'),
            "description": data.get('description', self.context_manager.get_context_summary()[:100]),
            "address": data.get('address', 'Not strictly provided'),
            "geo_coordinates": {
                "lat": float(data.get('latitude', 0.0)),
                "lng": float(data.get('longitude', 0.0))
            },
            "date": data.get('resolved_date', datetime.now().strftime('%Y-%m-%d')),
            "photo": data.get('photo_url', ''),
            "user_details": {
                "name": data.get('contact_name', ''),
                "phone": data.get('contact_phone', '')
            },
            "department": f"Assigned to {data.get('category', 'General')} Department"
        }
    
    def reset(self):
        """Reset conversation state"""
        self.context_manager = ContextManager()
