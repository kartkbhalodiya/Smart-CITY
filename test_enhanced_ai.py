#!/usr/bin/env python3
"""
Test Enhanced Step-by-Step AI
"""
import os
import sys
import django
import json

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

def test_enhanced_ai():
    """Test the enhanced step-by-step AI"""
    from complaints.enhanced_ai_views import enhanced_ai_chat
    from django.test import RequestFactory
    from rest_framework.response import Response
    
    factory = RequestFactory()
    session_id = "test_enhanced_123"
    
    # Test conversation flow
    test_messages = [
        "hello",  # Greeting
        "bijli nahi aa rahi hai",  # Problem identification
        "yes",  # Category confirmation
        "1",  # Subcategory selection (Power Outage)
        "3 din se bijli nahi hai, bahut problem ho rahi hai",  # Details
        "Sector 21, Gandhinagar, Gujarat",  # Location
        "yes",  # Location confirmation
        "skip",  # Skip photo
        "submit"  # Final submission
    ]
    
    print("Enhanced Step-by-Step AI Test")
    print("=" * 40)
    
    for i, message in enumerate(test_messages, 1):
        print(f"\nStep {i}: User says '{message}'")
        print("-" * 30)
        
        request_data = json.dumps({
            'message': message,
            'session_id': session_id,
            'user_name': 'Test User',
            'preferred_language': 'english'
        })
        
        request = factory.post(
            '/api/ai/chat/', 
            data=request_data,
            content_type='application/json'
        )
        
        try:
            response = enhanced_ai_chat(request)
            
            if isinstance(response, Response):
                data = response.data
                
                if data.get('success'):
                    # Clean response for console display
                    response_text = data.get('response', 'No response')
                    clean_text = ''.join(char for char in response_text if ord(char) < 128 or char in '🎯📝🤔👋⚡💧🗑️🛣️🚰🚦👮♂️📍🔍✅👍👎📷📱🗺️💡')
                    
                    print(f"AI: {clean_text[:200]}...")
                    print(f"Step: {data.get('current_step', 'unknown')}")
                    print(f"Next Action: {data.get('next_action', 'unknown')}")
                    
                    if data.get('detected_category'):
                        print(f"Category: {data.get('detected_category')}")
                    if data.get('detected_subcategory'):
                        print(f"Subcategory: {data.get('detected_subcategory')}")
                    if data.get('complaint_submitted'):
                        print(f"COMPLAINT SUBMITTED! ID: {data.get('complaint_id')}")
                        break
                else:
                    print(f"ERROR: {data.get('message', 'Unknown error')}")
            else:
                print(f"Unexpected response type: {type(response)}")
                
        except Exception as e:
            print(f"Exception: {str(e)}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    test_enhanced_ai()