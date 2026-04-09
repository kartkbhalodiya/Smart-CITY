import re
from typing import Dict

from .voice_intake_service import VoiceComplaintIntakeService


class SmartComplaintExtractor:
    """Compatibility wrapper used by older voice APIs."""

    LOCATION_PATTERNS = [
        re.compile(r'\b(?:at|near|beside|opposite|behind|in front of)\s+([a-z0-9\s,/-]{4,80})', re.I),
        re.compile(r'\bsector\s+\d+\b', re.I),
        re.compile(r'\bward\s+\d+\b', re.I),
    ]

    def __init__(self):
        self._service = VoiceComplaintIntakeService()

    def extract(self, text: str) -> Dict[str, str]:
        analysis = self._service.analyze(text)
        return {
            'category': analysis.get('category_key') or 'other',
            'subcategory': analysis.get('subcategory') or 'general',
            'description': analysis.get('summary') or text.strip(),
            'location': analysis.get('location_hint') or self._extract_location(text),
            'category_display': analysis.get('category') or 'Other Complaint',
            'all_issues': [analysis.get('category_key')] if analysis.get('category_key') else [],
            'confidence': analysis.get('confidence', 0.0),
        }

    def getUnderstandingExplanation(self, extracted: Dict[str, str], language: str) -> str:
        category = extracted.get('category_display') or extracted.get('category') or 'complaint'
        subcategory = extracted.get('subcategory') or 'general issue'
        description = extracted.get('description') or ''
        if language.lower().startswith('hi'):
            return f"Main samajh gayi - yeh {category} ki problem hai, specifically {subcategory}. {description}".strip()
        return f"I understood this as a {category} issue, specifically {subcategory}. {description}".strip()

    def _extract_location(self, text: str) -> str:
        for pattern in self.LOCATION_PATTERNS:
            match = pattern.search(text or '')
            if not match:
                continue
            if match.lastindex:
                return match.group(1).strip(' ,.-')
            return match.group(0).strip(' ,.-')
        return ''
