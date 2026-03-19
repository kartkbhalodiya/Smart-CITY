"""
Enhanced AI Chat API View with Step-by-Step Conversation Flow
"""
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
import json
import traceback
from .step_by_step_ai import step_by_step_ai

@api_view(['POST'])
@permission_classes([AllowAny])
def enhanced_ai_chat(request):
    """
    Enhanced AI chat with step-by-step conversation flow
    
    Expected payload:
    {
        "message": "user message",
        "session_id": "unique_session_id",
        "user_name": "optional_user_name",
        "preferred_language": "english|hindi|gujarati"
    }
    """
    try:
        # Parse request data
        if hasattr(request, 'data'):
            data = request.data
        else:
            data = json.loads(request.body.decode('utf-8'))
        
        message = data.get('message', '').strip()
        session_id = data.get('session_id', f'session_{hash(message)}')
        user_name = data.get('user_name', 'Friend')
        preferred_language = data.get('preferred_language', 'english')
        
        if not message:
            return Response({
                'success': False,
                'message': 'Message is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Process message through step-by-step AI
        ai_response = step_by_step_ai.process_message(
            session_id=session_id,
            message=message,
            user_name=user_name,
            preferred_language=preferred_language
        )
        
        # Format response for Flutter app
        response_data = {
            'success': True,
            'response': ai_response['response'],
            'session_id': session_id,
            'current_step': ai_response['step'],
            'next_action': ai_response['next_action'],
            'language': preferred_language,
            'urgency': ai_response.get('data', {}).get('urgency', 'medium'),
            'emotion': 'helpful',  # Always helpful tone
            'detected_category': ai_response.get('data', {}).get('category'),
            'detected_subcategory': ai_response.get('data', {}).get('subcategory'),
            'is_emergency': ai_response.get('data', {}).get('urgency') == 'critical',
            'confidence': ai_response.get('data', {}).get('confidence', 0.8),
            'next_step': ai_response['next_action'],
            'llm_powered': True
        }
        
        # Add step-specific data
        if 'show_examples' in ai_response:
            response_data['show_examples'] = True
            response_data['examples'] = ai_response.get('data', {}).get('examples', [])
        
        if 'show_categories' in ai_response:
            response_data['show_categories'] = True
            response_data['categories'] = ai_response.get('data', {}).get('categories', [])
        
        if 'show_subcategories' in ai_response:
            response_data['show_subcategories'] = True
            response_data['subcategories'] = ai_response.get('data', {}).get('subcategories', [])
        
        if 'show_confirmation' in ai_response:
            response_data['show_confirmation'] = True
            response_data['buttons'] = ai_response.get('data', {}).get('buttons', [])
        
        if 'show_map' in ai_response:
            response_data['show_map'] = True
            response_data['map_instruction'] = ai_response.get('data', {}).get('map_instruction', 'select_location')
        
        if 'show_camera' in ai_response:
            response_data['show_camera'] = True
        
        if 'complaint_submitted' in ai_response:
            response_data['complaint_submitted'] = True
            response_data['complaint_id'] = ai_response.get('data', {}).get('complaint_id')
            response_data['complaint_data'] = ai_response.get('data', {}).get('complaint_data', {})
        
        return Response(response_data, status=status.HTTP_200_OK)
        
    except json.JSONDecodeError:
        return Response({
            'success': False,
            'message': 'Invalid JSON format'
        }, status=status.HTTP_400_BAD_REQUEST)
        
    except Exception as e:
        # Log the error for debugging
        print(f"Enhanced AI Chat Error: {str(e)}")
        traceback.print_exc()
        
        return Response({
            'success': False,
            'message': f'AI Chat Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([AllowAny])
def ai_reset_session(request):
    """Reset AI conversation session"""
    try:
        data = request.data if hasattr(request, 'data') else json.loads(request.body.decode('utf-8'))
        session_id = data.get('session_id')
        
        if not session_id:
            return Response({
                'success': False,
                'message': 'Session ID is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Clear session from cache
        from django.core.cache import cache
        cache_key = f"conversation_state_{session_id}"
        cache.delete(cache_key)
        
        return Response({
            'success': True,
            'message': 'Session reset successfully',
            'session_id': session_id
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Reset Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([AllowAny])
def ai_session_status(request):
    """Get current session status and data"""
    try:
        session_id = request.GET.get('session_id')
        
        if not session_id:
            return Response({
                'success': False,
                'message': 'Session ID is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get session state
        state = step_by_step_ai.get_conversation_state(session_id)
        
        return Response({
            'success': True,
            'session_id': session_id,
            'current_step': state.current_step,
            'user_data': state.user_data,
            'conversation_length': len(state.conversation_history),
            'created_at': state.created_at.isoformat(),
            'updated_at': state.updated_at.isoformat()
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Status Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)