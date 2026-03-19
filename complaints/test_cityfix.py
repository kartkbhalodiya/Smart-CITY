"""
Test view for CityFix LLM integration
"""
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .cityfix_client import cityfix_llm

@csrf_exempt
@require_http_methods(["GET", "POST"])
def test_cityfix_llm(request):
    """Test endpoint to verify CityFix LLM connection"""
    
    if request.method == "GET":
        # Health check
        is_healthy = cityfix_llm.health_check()
        return JsonResponse({
            'cityfix_llm_status': 'online' if is_healthy else 'offline',
            'api_url': cityfix_llm.base_url,
            'health_check': is_healthy
        })
    
    elif request.method == "POST":
        # Test chat
        import json
        try:
            data = json.loads(request.body)
            message = data.get('message', 'bijli nahi hai 3 din se')
            
            response = cityfix_llm.chat(
                message=message,
                session_id='test_session',
                user_name='Test User',
                preferred_language='hindi'
            )
            
            return JsonResponse({
                'success': True,
                'test_message': message,
                'llm_response': response
            })
            
        except Exception as e:
            return JsonResponse({
                'success': False,
                'error': str(e)
            }, status=500)