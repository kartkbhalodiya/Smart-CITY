"""
CityFix LLM API Client
Handles communication with the deployed CityFix LLM service
"""
import requests
import logging
from django.conf import settings
from typing import Dict, Optional, Any

logger = logging.getLogger(__name__)

class CityFixLLMClient:
    def __init__(self):
        self.base_url = getattr(settings, 'CITYFIX_LLM_URL', 'https://kartik1911-cityfix-llm.hf.space')
        self.timeout = 30
        
    def chat(self, message: str, session_id: Optional[str] = None, 
             user_name: Optional[str] = None, preferred_language: str = "english") -> Dict[str, Any]:
        """
        Send a chat message to CityFix LLM
        
        Args:
            message: User's complaint message
            session_id: Optional session ID for conversation continuity
            user_name: Optional user name
            preferred_language: User's preferred language (english/hindi/gujarati)
            
        Returns:
            Dict containing LLM response and metadata
        """
        try:
            payload = {
                "message": message,
                "preferred_language": preferred_language
            }
            
            if session_id:
                payload["session_id"] = session_id
            if user_name:
                payload["user_name"] = user_name
                
            response = requests.post(
                f"{self.base_url}/chat",
                json=payload,
                timeout=self.timeout,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"CityFix LLM API error: {response.status_code} - {response.text}")
                return self._fallback_response(message)
                
        except requests.exceptions.RequestException as e:
            logger.error(f"CityFix LLM API request failed: {str(e)}")
            return self._fallback_response(message)
    
    def predict(self, text: str) -> Dict[str, Any]:
        """
        Get raw prediction from CityFix LLM without conversation context
        
        Args:
            text: Text to classify
            
        Returns:
            Dict containing prediction results
        """
        try:
            response = requests.post(
                f"{self.base_url}/predict",
                json={"text": text},
                timeout=self.timeout,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"CityFix LLM predict error: {response.status_code}")
                return self._fallback_prediction()
                
        except requests.exceptions.RequestException as e:
            logger.error(f"CityFix LLM predict failed: {str(e)}")
            return self._fallback_prediction()
    
    def health_check(self) -> bool:
        """
        Check if CityFix LLM API is healthy
        
        Returns:
            True if API is responding, False otherwise
        """
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def _fallback_response(self, message: str) -> Dict[str, Any]:
        """Fallback response when API is unavailable"""
        return {
            "response": "I understand your concern. Your complaint has been registered and will be processed by the appropriate department.",
            "session_id": "fallback",
            "detected_category": "Other Complaint",
            "detected_subcategory": "General Complaint",
            "urgency": "medium",
            "emotion": "neutral",
            "language": "english",
            "is_emergency": False,
            "confidence": 0.5,
            "next_step": "intake",
            "missing_fields": [],
            "alternatives": [],
            "processing_ms": 0
        }
    
    def _fallback_prediction(self) -> Dict[str, Any]:
        """Fallback prediction when API is unavailable"""
        return {
            "category": "Other Complaint",
            "subcategory": "General Complaint",
            "urgency": "medium",
            "emotion": "neutral",
            "language": "english",
            "is_emergency": False,
            "confidence": 0.5,
            "alternatives": []
        }

# Global instance
cityfix_llm = CityFixLLMClient()