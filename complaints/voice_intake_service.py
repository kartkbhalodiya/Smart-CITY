import re
import json
from dataclasses import dataclass
from typing import Any, Dict, List, Optional
from django.conf import settings

from .models import ComplaintCategory

try:
    from google import genai as google_genai
except Exception:
    google_genai = None


@dataclass
class _CategoryEntry:
    key: str
    name: str
    subcategories: List[str]


class VoiceComplaintIntakeService:
    """Backend-first structured complaint understanding for live voice intake."""

    # Basic keyword hints for faster category detection (lightweight)
    CATEGORY_KEYWORDS = {
        'police': ['police', 'crime', 'theft', 'chori', 'robbery', 'attack', 'assault', 'harassment', 'threat', 'violence', 'missing', 'fraud', 'scam'],
        'traffic': ['traffic', 'signal', 'parking', 'accident', 'jam', 'vehicle', 'overspeeding', 'helmet', 'seatbelt', 'drunk', 'driving'],
        'construction': ['construction', 'building', 'illegal construction', 'collapse', 'debris', 'excavation', 'footpath', 'bridge', 'flyover'],
        'water': ['water', 'pani', 'paani', 'pipeline', 'leak', 'supply', 'dirty water', 'tap', 'tanker', 'pressure'],
        'electricity': ['electricity', 'bijli', 'light', 'power', 'wire', 'transformer', 'spark', 'outage', 'meter', 'pole'],
        'garbage': ['garbage', 'kachra', 'waste', 'dustbin', 'sanitation', 'cleaning', 'dumping', 'burning', 'dead animal'],
        'road': ['road', 'sadak', 'pothole', 'khadda', 'gadda', 'hole', 'broken road', 'waterlogging', 'manhole'],
        'drainage': ['drain', 'drainage', 'sewage', 'gutter', 'nali', 'overflow', 'waterlogging', 'manhole', 'sewer', 'blockage'],
        'illegal': ['illegal', 'encroachment', 'unauthorized', 'kabza', 'noise', 'loudspeaker', 'gambling', 'nuisance'],
        'transportation': ['transport', 'bus', 'auto', 'taxi', 'rickshaw', 'public transport', 'overcharge', 'route'],
        'cyber': ['cyber', 'fraud', 'scam', 'otp', 'phishing', 'hack', 'online fraud', 'upi', 'banking', 'social media'],
        'other': ['other', 'misc', 'general', 'park', 'animal', 'tree', 'community'],
    }

    GREETING_RE = re.compile(
        r'^\s*(hi|hello|hey|namaste|namaskar|hii|haan ji|hanji|good morning|good evening)\b[\s,.-]*',
        re.I,
    )

    LOCATION_RE = re.compile(
        r'\b(?:at|near|beside|opposite|behind|in front of|around)\s+([a-z0-9\s,/-]{4,80})',
        re.I,
    )

    def analyze_with_gemini(
        self,
        conversation_history: List[Dict[str, str]],
        preferred_language: str = 'english',
    ) -> Dict[str, Any]:
        """Analyze full conversation with Gemini 2.5 Flash to extract complaint details."""
        try:
            api_key = getattr(settings, 'GEMINI_API_KEY', None)
            if not api_key or not google_genai:
                return {'success': False, 'error': 'Gemini API not configured'}

            # Build conversation text
            conversation_text = "\n".join([
                f"{msg.get('role', 'user')}: {msg.get('text', msg.get('content', ''))}"
                for msg in conversation_history
            ])

            # Load catalog for reference
            catalog = self._load_catalog()
            catalog_text = self._build_catalog_text(catalog)

            prompt = f"""You are an expert complaint categorization AI. Analyze this full conversation between a citizen and voice assistant.

Available Categories and Subcategories:
{catalog_text}

Conversation:
{conversation_text}

Extract and return ONLY valid JSON with these fields:
{{
  "category_key": "exact key from catalog (e.g., 'road', 'water', 'police')",
  "category_name": "full category name",
  "subcategory": "exact subcategory name from catalog",
  "problem_summary": "clear 1-2 sentence summary in {preferred_language}",
  "description": "detailed description from conversation in {preferred_language}",
  "location_hint": "extracted location if mentioned",
  "urgency": "low|medium|high|critical",
  "confidence": 0.0-1.0,
  "reasoning": "why you chose this category/subcategory"
}}

Rules:
- Use EXACT category keys and subcategory names from the catalog
- If unclear, use best match with lower confidence
- Extract all location mentions
- Combine all user messages into coherent description
- Return ONLY valid JSON, no markdown"""

            client = google_genai.Client(api_key=api_key)
            response = client.models.generate_content(
                model='gemini-2.0-flash-exp',
                contents=prompt,
            )

            result_text = (getattr(response, 'text', '') or '').strip()
            result_text = result_text.replace('```json', '').replace('```', '').strip()

            analysis = json.loads(result_text)
            analysis['success'] = True
            analysis['source'] = 'gemini_conversation_analysis'
            return analysis

        except json.JSONDecodeError as e:
            return {
                'success': False,
                'error': f'Failed to parse Gemini response: {str(e)}',
                'raw_response': result_text if 'result_text' in locals() else ''
            }
        except Exception as e:
            return {'success': False, 'error': f'Gemini analysis failed: {str(e)}'}

    def analyze(
        self,
        text: str,
        preferred_language: str = 'english',
        existing_category: Optional[str] = None,
    ) -> Dict[str, Any]:
        cleaned_text = self._clean_text(text)
        normalized_text = self._normalize(cleaned_text)
        catalog = self._load_catalog()

        category_candidates = self._score_categories(normalized_text, catalog)
        best_category = category_candidates[0] if category_candidates else None
        category_key = best_category['key'] if best_category else (existing_category or '')

        subcategory_candidates = self._score_subcategories(
            normalized_text,
            category_key,
            catalog,
        ) if category_key else []
        best_subcategory = subcategory_candidates[0] if subcategory_candidates else None
        best_subcategory_name = best_subcategory['name'] if best_subcategory else ''

        summary = self._build_summary(cleaned_text, category_key, best_subcategory)
        confidence = self._compute_confidence(category_candidates, best_subcategory)
        needs_confirmation = (
            not category_key
            or not best_subcategory_name
            or confidence < 0.75
        )

        selected_category = next(
            (entry for entry in catalog if entry.key == category_key),
            None,
        )

        return {
            'success': True,
            'summary': summary,
            'category_key': category_key,
            'category': selected_category.name if selected_category else '',
            'subcategory': best_subcategory_name,
            'confidence': confidence,
            'category_confidence': best_category['confidence'] if best_category else 0.0,
            'subcategory_confidence': best_subcategory.get('confidence', 0.0)
            if isinstance(best_subcategory, dict)
            else (subcategory_candidates[0]['confidence'] if subcategory_candidates else 0.0),
            'needs_confirmation': needs_confirmation,
            'alternatives': [
                {
                    'category_key': item['key'],
                    'category': item['name'],
                    'confidence': item['confidence'],
                }
                for item in category_candidates[:3]
            ],
            'available_subcategories': [
                item['name'] for item in subcategory_candidates[:5]
            ],
            'location_hint': self._extract_location(cleaned_text),
            'preferred_language': preferred_language,
            'source': 'voice_intake_backend',
        }

    def _load_catalog(self) -> List[_CategoryEntry]:
        categories = list(
            ComplaintCategory.objects.filter(is_active=True)
            .prefetch_related('subcategories')
            .order_by('display_order', 'name')
        )
        if not categories:
            return []

        entries: List[_CategoryEntry] = []
        for category in categories:
            subcategories = [
                sub.name
                for sub in category.subcategories.filter(is_active=True).order_by('display_order', 'name')
            ]
            entries.append(
                _CategoryEntry(
                    key=category.key,
                    name=category.name,
                    subcategories=subcategories,
                )
            )
        return entries

    def _score_categories(self, normalized_text: str, catalog: List[_CategoryEntry]) -> List[Dict[str, Any]]:
        scored: List[Dict[str, Any]] = []
        tokens = self._tokenize(normalized_text)

        for category in catalog:
            score = 0.0
            key_phrase = self._normalize(category.key)
            name_phrase = self._normalize(category.name)

            # Exact key match
            if key_phrase and key_phrase in normalized_text:
                score += 5.0
            
            # Exact name match
            if name_phrase and name_phrase in normalized_text:
                score += 6.0

            # Token overlap with category name
            name_tokens = self._tokenize(name_phrase)
            score += 1.2 * len(tokens.intersection(name_tokens))

            # Keyword hints for faster detection
            for keyword in self.CATEGORY_KEYWORDS.get(category.key, []):
                keyword_phrase = self._normalize(keyword)
                if keyword_phrase and keyword_phrase in normalized_text:
                    score += 3.2

            # Check subcategory names for better category detection
            for subcategory in category.subcategories:
                sub_phrase = self._normalize(subcategory)
                if sub_phrase and sub_phrase in normalized_text:
                    score += 3.5
                
                # Token overlap with subcategory
                sub_tokens = self._tokenize(sub_phrase)
                score += 0.8 * len(tokens.intersection(sub_tokens))

            if score > 0:
                scored.append({
                    'key': category.key,
                    'name': category.name,
                    'score': score,
                })

        scored.sort(key=lambda item: item['score'], reverse=True)
        if not scored:
            return []

        best_score = scored[0]['score']
        for item in scored:
            item['confidence'] = self._normalize_score(item['score'], best_score)
        return scored

    def _score_subcategories(
        self,
        normalized_text: str,
        category_key: str,
        catalog: List[_CategoryEntry],
    ) -> List[Dict[str, Any]]:
        category = next((entry for entry in catalog if entry.key == category_key), None)
        if not category:
            return []

        tokens = self._tokenize(normalized_text)
        scored: List[Dict[str, Any]] = []

        for subcategory in category.subcategories:
            score = 0.0
            sub_phrase = self._normalize(subcategory)
            sub_tokens = self._tokenize(sub_phrase)

            # Exact subcategory name match
            if sub_phrase and sub_phrase in normalized_text:
                score += 6.0
            
            # Token overlap
            score += 1.5 * len(tokens.intersection(sub_tokens))

            if score > 0:
                scored.append({
                    'name': subcategory,
                    'score': score,
                })

        if not scored:
            # Fallback to 'Other' or 'General' subcategory
            fallback = next(
                (name for name in category.subcategories if name.lower() in {'other', 'general complaint', 'general'}),
                '',
            )
            if fallback:
                return [{'name': fallback, 'score': 0.5, 'confidence': 0.35}]
            return []

        scored.sort(key=lambda item: item['score'], reverse=True)
        best_score = scored[0]['score']
        for item in scored:
            item['confidence'] = self._normalize_score(item['score'], best_score)
        return scored

    def _build_summary(
        self,
        cleaned_text: str,
        category_key: str,
        best_subcategory: Optional[Dict[str, Any]],
    ) -> str:
        summary = cleaned_text.strip()
        if not summary:
            return ''

        summary = re.sub(r'\s+', ' ', summary)
        if len(summary) > 180:
            summary = summary[:177].rstrip(' ,.-') + '...'

        if category_key and isinstance(best_subcategory, dict) and best_subcategory.get('name'):
            sub_name = best_subcategory['name']
            if sub_name.lower() not in summary.lower():
                return f'{summary} ({sub_name})'
        return summary

    def _compute_confidence(
        self,
        category_candidates: List[Dict[str, Any]],
        best_subcategory: Optional[Dict[str, Any]],
    ) -> float:
        if not category_candidates:
            return 0.0

        category_confidence = category_candidates[0].get('confidence', 0.0)
        subcategory_confidence = (
            best_subcategory.get('confidence', 0.0)
            if isinstance(best_subcategory, dict)
            else 0.0
        )
        combined = (category_confidence * 0.65) + (subcategory_confidence * 0.35)
        return round(min(0.99, combined), 2)

    def _normalize_score(self, score: float, best_score: float) -> float:
        if best_score <= 0:
            return 0.0
        return round(min(0.99, 0.45 + (score / max(best_score, 1.0)) * 0.5), 2)

    def _clean_text(self, text: str) -> str:
        cleaned = self.GREETING_RE.sub('', (text or '').strip())
        return re.sub(r'\s+', ' ', cleaned).strip()

    def _extract_location(self, text: str) -> str:
        match = self.LOCATION_RE.search(text)
        if not match:
            return ''
        return match.group(1).strip(' ,.-')

    def _normalize(self, text: str) -> str:
        return re.sub(r'\s+', ' ', re.sub(r'[^a-z0-9\s]', ' ', (text or '').lower())).strip()

    def _tokenize(self, text: str) -> set[str]:
        return {token for token in (text or '').split() if len(token) >= 3}

    def _build_catalog_text(self, catalog: List[_CategoryEntry]) -> str:
        """Build human-readable catalog for Gemini prompt."""
        lines = []
        for entry in catalog:
            lines.append(f"\n{entry.name} (key: '{entry.key}'):")
            for sub in entry.subcategories:
                lines.append(f"  - {sub}")
        return ''.join(lines)
