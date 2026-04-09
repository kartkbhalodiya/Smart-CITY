"""
Conversation Analysis Service - Analyzes full conversation to extract complaint details
"""
import json
import re
from typing import Dict, List, Any, Optional
from django.conf import settings

try:
    from google import genai as google_genai
except Exception:
    google_genai = None

from .models import ComplaintCategory


class ConversationAnalyzer:
    """Analyzes full conversation history to extract structured complaint data"""
    
    def __init__(self):
        self.api_key = getattr(settings, 'GEMINI_API_KEY', None)
        self.client = None
        if self.api_key and google_genai:
            try:
                self.client = google_genai.Client(api_key=self.api_key)
            except Exception:
                pass
    
    def analyze_conversation(
        self,
        conversation_history: List[Dict[str, str]],
        preferred_language: str = 'english'
    ) -> Dict[str, Any]:
        """
        Analyze full conversation and extract complaint details using Gemini
        
        Args:
            conversation_history: List of conversation messages
            preferred_language: User's preferred language
            
        Returns:
            Dict with extracted complaint details
        """
        if not self.client:
            return self._fallback_analysis(conversation_history, preferred_language)
        
        try:
            # Build conversation text
            conversation_text = self._build_conversation_text(conversation_history)
            
            # Load categories from database
            catalog = self._load_catalog()
            catalog_text = self._build_catalog_text(catalog)
            
            # Build prompt
            prompt = self._build_analysis_prompt(
                conversation_text,
                catalog_text,
                preferred_language
            )
            
            # Call Gemini
            response = self.client.models.generate_content(
                model='gemini-2.0-flash-exp',
                contents=prompt,
            )
            
            result_text = (getattr(response, 'text', '') or '').strip()
            result_text = result_text.replace('```json', '').replace('```', '').strip()
            
            # Parse JSON response
            analysis = json.loads(result_text)
            
            # Validate and enrich
            return self._validate_and_enrich(analysis, catalog, preferred_language)
            
        except json.JSONDecodeError as e:
            return {
                'success': False,
                'error': f'Failed to parse AI response: {str(e)}',
                'fallback': self._fallback_analysis(conversation_history, preferred_language)
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'Analysis failed: {str(e)}',
                'fallback': self._fallback_analysis(conversation_history, preferred_language)
            }
    
    def _build_conversation_text(self, conversation_history: List[Dict[str, str]]) -> str:
        """Build readable conversation text"""
        lines = []
        for msg in conversation_history:
            role = msg.get('role', 'user')
            text = msg.get('text', msg.get('content', '')).strip()
            if text:
                lines.append(f"{role.upper()}: {text}")
        return '\n'.join(lines)
    
    def _load_catalog(self) -> List[Dict[str, Any]]:
        """Load categories and subcategories from database"""
        categories = ComplaintCategory.objects.filter(is_active=True).prefetch_related('subcategories')
        
        catalog = []
        for category in categories:
            subcategories = category.subcategories.filter(is_active=True).order_by('display_order', 'name')
            catalog.append({
                'key': category.key,
                'name': category.name,
                'subcategories': [sub.name for sub in subcategories]
            })
        return catalog
    
    def _build_catalog_text(self, catalog: List[Dict[str, Any]]) -> str:
        """Build human-readable catalog for prompt"""
        lines = []
        for entry in catalog:
            lines.append(f"\n{entry['name']} (key: '{entry['key']}'):")
            for sub in entry['subcategories']:
                lines.append(f"  - {sub}")
        return ''.join(lines)
    
    def _build_analysis_prompt(
        self,
        conversation_text: str,
        catalog_text: str,
        preferred_language: str
    ) -> str:
        """Build Gemini analysis prompt"""
        return f"""You are an expert complaint analyzer for a Smart City system.

Analyze this FULL conversation between a citizen and voice assistant to extract complaint details.

AVAILABLE CATEGORIES AND SUBCATEGORIES:
{catalog_text}

CONVERSATION:
{conversation_text}

TASK:
1. Read the ENTIRE conversation carefully
2. Identify what problem the citizen is reporting
3. Match it to the EXACT category key and subcategory name from the catalog above
4. Extract location if mentioned
5. Create a clear summary and description in {preferred_language}

IMPORTANT RULES:
- Use ONLY category keys and subcategory names from the catalog above
- If citizen says "chori" or "theft" or "stolen" → category_key: "police", subcategory: "Theft / Robbery"
- If citizen says "sadak" or "road" or "pothole" → category_key: "road"
- If citizen says "bijli" or "electricity" or "power" → category_key: "electricity"
- If citizen says "pani" or "water" → category_key: "water"
- If citizen says "kachra" or "garbage" → category_key: "garbage"
- Combine ALL user messages to understand the full problem
- Extract location from phrases like "near", "at", "in", address mentions

Return ONLY valid JSON (no markdown):
{{
  "success": true,
  "category_key": "exact key from catalog",
  "category_name": "full category name from catalog",
  "subcategory": "exact subcategory name from catalog",
  "problem_summary": "short 1-line summary in {preferred_language}",
  "description": "detailed description combining all user messages in {preferred_language}",
  "location_hint": "extracted location or empty string",
  "urgency": "low|medium|high|critical",
  "confidence": 0.0-1.0,
  "reasoning": "why you chose this category/subcategory"
}}"""
    
    def _validate_and_enrich(
        self,
        analysis: Dict[str, Any],
        catalog: List[Dict[str, Any]],
        preferred_language: str
    ) -> Dict[str, Any]:
        """Validate AI response and enrich with additional data"""
        
        # Ensure success flag
        analysis['success'] = True
        analysis['source'] = 'gemini_conversation_analysis'
        analysis['preferred_language'] = preferred_language
        
        # Validate category exists
        category_key = analysis.get('category_key', '')
        category_entry = next((c for c in catalog if c['key'] == category_key), None)
        
        if not category_entry:
            # Fallback to 'other'
            category_entry = next((c for c in catalog if c['key'] == 'other'), None)
            if category_entry:
                analysis['category_key'] = 'other'
                analysis['category_name'] = category_entry['name']
                analysis['subcategory'] = 'General'
        
        # Validate subcategory exists
        if category_entry:
            subcategory = analysis.get('subcategory', '')
            if subcategory not in category_entry['subcategories']:
                # Try to find 'Other' or 'General'
                fallback = next(
                    (s for s in category_entry['subcategories'] if s.lower() in ['other', 'general', 'general complaint']),
                    category_entry['subcategories'][0] if category_entry['subcategories'] else 'Other'
                )
                analysis['subcategory'] = fallback
        
        # Ensure required fields
        analysis.setdefault('problem_summary', analysis.get('description', '')[:100])
        analysis.setdefault('description', 'Complaint reported via voice assistant')
        analysis.setdefault('location_hint', '')
        analysis.setdefault('urgency', 'medium')
        analysis.setdefault('confidence', 0.7)
        analysis.setdefault('reasoning', 'Analyzed from conversation')
        
        return analysis
    
    def _fallback_analysis(
        self,
        conversation_history: List[Dict[str, str]],
        preferred_language: str
    ) -> Dict[str, Any]:
        """Simple keyword-based fallback when Gemini is not available"""
        
        # Combine all user messages
        user_messages = [
            msg.get('text', msg.get('content', '')).lower()
            for msg in conversation_history
            if msg.get('role') == 'user'
        ]
        combined_text = ' '.join(user_messages)
        
        # Simple keyword matching
        category_key = 'other'
        subcategory = 'General'
        
        if any(word in combined_text for word in ['chori', 'theft', 'stolen', 'robbery', 'purse']):
            category_key = 'police'
            subcategory = 'Theft / Robbery'
        elif any(word in combined_text for word in ['sadak', 'road', 'pothole', 'khadda']):
            category_key = 'road'
            subcategory = 'Pothole'
        elif any(word in combined_text for word in ['bijli', 'electricity', 'power', 'light']):
            category_key = 'electricity'
            subcategory = 'Power Outage'
        elif any(word in combined_text for word in ['pani', 'water', 'pipeline']):
            category_key = 'water'
            subcategory = 'No Water Supply'
        elif any(word in combined_text for word in ['kachra', 'garbage', 'waste']):
            category_key = 'garbage'
            subcategory = 'Garbage Not Collected'
        
        # Load category name from database
        try:
            category = ComplaintCategory.objects.filter(key=category_key).first()
            category_name = category.name if category else 'Other Complaint'
        except:
            category_name = 'Other Complaint'
        
        return {
            'success': True,
            'source': 'fallback_keyword_analysis',
            'category_key': category_key,
            'category_name': category_name,
            'subcategory': subcategory,
            'problem_summary': combined_text[:100] if combined_text else 'Voice complaint',
            'description': combined_text if combined_text else 'Reported via voice assistant',
            'location_hint': '',
            'urgency': 'medium',
            'confidence': 0.5,
            'reasoning': 'Keyword-based fallback analysis',
            'preferred_language': preferred_language
        }
