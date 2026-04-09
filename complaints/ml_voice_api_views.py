"""
API Views for ML Voice Assistant
Provides endpoints for intelligent voice conversation processing
"""

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.core.cache import cache
from django.views.decorators.csrf import csrf_exempt
import json
import uuid

from .ml_voice_assistant import MLVoiceAssistant
from .voice_intake_service import VoiceComplaintIntakeService


# Session storage for voice assistants (in production, use Redis)
VOICE_SESSIONS = {}


def get_or_create_session(session_id: str = None) -> tuple:
    """Get existing session or create new one"""
    if not session_id:
        session_id = str(uuid.uuid4())
    
    # Try cache first (Redis in production)
    cache_key = f'voice_session_{session_id}'
    assistant = cache.get(cache_key)
    
    if not assistant:
        assistant = MLVoiceAssistant()
        VOICE_SESSIONS[session_id] = assistant
        cache.set(cache_key, assistant, timeout=3600)  # 1 hour
    
    return session_id, assistant


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def ml_voice_process(request):
    """
    Process user voice input with ML intelligence
    
    POST /api/ml-voice/process/
    Body: {
        "session_id": "optional-session-id",
        "text": "user speech text",
        "stage": "current_stage",
        "context": {optional context data}
    }
    
    Returns: {
        "success": true,
        "session_id": "session-id",
        "response": "AI response text",
        "emotion": {emotion data},
        "next_stage": "next_stage",
        "extracted_data": {extracted data},
        "requires_emergency": false,
        "context_summary": "conversation summary"
    }
    """
    try:
        data = request.data
        text = data.get('text', '').strip()
        stage = data.get('stage', 'greeting')
        context = data.get('context', {})
        session_id = data.get('session_id')
        
        if not text:
            return Response({
                'success': False,
                'error': 'Text is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get or create session
        session_id, assistant = get_or_create_session(session_id)
        
        # Process with ML
        result = assistant.process_user_input(text, stage, context)
        
        # Save session
        cache.set(f'voice_session_{session_id}', assistant, timeout=3600)
        
        return Response({
            'success': True,
            'session_id': session_id,
            **result
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def ml_voice_emotion_detect(request):
    """
    Detect emotion and urgency from text
    
    POST /api/ml-voice/emotion/
    Body: {
        "text": "user speech text"
    }
    
    Returns: {
        "success": true,
        "emotion": "urgent|angry|worried|calm",
        "urgency": "critical|high|medium|low",
        "is_emergency": false,
        "requires_empathy": true
    }
    """
    try:
        from .ml_voice_assistant import EmotionDetector
        
        text = request.data.get('text', '').strip()
        if not text:
            return Response({
                'success': False,
                'error': 'Text is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        emotion_data = EmotionDetector.detect(text)
        
        return Response({
            'success': True,
            **emotion_data
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def ml_voice_resolve_date(request):
    """
    Resolve relative date to absolute date
    
    POST /api/ml-voice/resolve-date/
    Body: {
        "text": "2 din pehle"
    }
    
    Returns: {
        "success": true,
        "original": "2 din pehle",
        "resolved": "2025-01-08",
        "formatted": "8 January 2025"
    }
    """
    try:
        from .ml_voice_assistant import DateResolver
        from datetime import datetime
        
        text = request.data.get('text', '').strip()
        if not text:
            return Response({
                'success': False,
                'error': 'Text is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        resolved = DateResolver.resolve(text)
        
        if not resolved:
            return Response({
                'success': False,
                'error': 'Could not resolve date',
                'original': text
            })
        
        formatted = datetime.strptime(resolved, '%Y-%m-%d').strftime('%d %B %Y')
        
        return Response({
            'success': True,
            'original': text,
            'resolved': resolved,
            'formatted': formatted
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@csrf_exempt
@api_view(['GET'])
@permission_classes([AllowAny])
def ml_voice_session_summary(request, session_id):
    """
    Get conversation summary for a session
    
    GET /api/ml-voice/session/{session_id}/
    
    Returns: {
        "success": true,
        "session_id": "session-id",
        "history": [...],
        "metadata": {...},
        "stage": "current_stage",
        "turn_count": 10
    }
    """
    try:
        cache_key = f'voice_session_{session_id}'
        assistant = cache.get(cache_key) or VOICE_SESSIONS.get(session_id)
        
        if not assistant:
            return Response({
                'success': False,
                'error': 'Session not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        summary = assistant.get_conversation_summary()
        
        return Response({
            'success': True,
            'session_id': session_id,
            **summary
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def ml_voice_reset_session(request, session_id):
    """
    Reset a voice session
    
    POST /api/ml-voice/session/{session_id}/reset/
    
    Returns: {
        "success": true,
        "message": "Session reset successfully"
    }
    """
    try:
        cache_key = f'voice_session_{session_id}'
        assistant = cache.get(cache_key) or VOICE_SESSIONS.get(session_id)
        
        if assistant:
            assistant.reset()
            cache.set(cache_key, assistant, timeout=3600)
        
        return Response({
            'success': True,
            'message': 'Session reset successfully'
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def ml_voice_generate_response(request):
    """
    Generate intelligent response for a given stage
    
    POST /api/ml-voice/generate-response/
    Body: {
        "stage": "problem",
        "emotion": "urgent",
        "context": {...}
    }
    
    Returns: {
        "success": true,
        "response": "AI generated response"
    }
    """
    try:
        from .ml_voice_assistant import ResponseGenerator
        
        stage = request.data.get('stage', 'greeting')
        emotion = request.data.get('emotion', {})
        context = request.data.get('context', {})
        
        response = ResponseGenerator.generate_stage_prompt(stage, context)
        
        # Add empathy if needed
        if emotion.get('requires_empathy'):
            empathy = ResponseGenerator.generate_empathy_response(emotion.get('emotion', 'calm'))
            response = f"{empathy} {response}"
        
        return Response({
            'success': True,
            'response': response
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def ml_voice_intake_analyze(request):
    """
    Analyze the citizen's first problem statement into structured complaint data.

    POST /api/ml-voice/intake-analyze/
    Body: {
        "text": "road is broken near sector 5",
        "preferred_language": "english",
        "existing_category": "optional-category-key"
    }
    """
    try:
        text = request.data.get('text', '').strip()
        preferred_language = request.data.get('preferred_language', 'english')
        existing_category = request.data.get('existing_category')

        if not text:
            return Response({
                'success': False,
                'error': 'Text is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        service = VoiceComplaintIntakeService()
        analysis = service.analyze(
            text=text,
            preferred_language=preferred_language,
            existing_category=existing_category,
        )
        return Response(analysis)
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def ml_voice_analyze_conversation(request):
    """
    Analyze full conversation history with Gemini 2.5 Flash to extract complaint details.

    POST /api/ml-voice/analyze-conversation/
    Body: {
        "conversation_history": [
            {"role": "assistant", "text": "Hello..."},
            {"role": "user", "text": "road broken"},
            ...
        ],
        "preferred_language": "english"
    }

    Returns: {
        "success": true,
        "category_key": "road",
        "category_name": "Road/Pothole",
        "subcategory": "Broken Road",
        "problem_summary": "Road is broken near sector 5",
        "description": "Full description...",
        "location_hint": "sector 5",
        "urgency": "medium",
        "confidence": 0.85,
        "reasoning": "User mentioned broken road..."
    }
    """
    try:
        conversation_history = request.data.get('conversation_history', [])
        preferred_language = request.data.get('preferred_language', 'english')

        if not conversation_history:
            return Response({
                'success': False,
                'error': 'Conversation history is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        service = VoiceComplaintIntakeService()
        analysis = service.analyze_with_gemini(
            conversation_history=conversation_history,
            preferred_language=preferred_language,
        )
        return Response(analysis)
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
