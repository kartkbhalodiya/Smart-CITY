#!/usr/bin/env python3
"""
Simple AI Chat Test - No Unicode issues
"""
import os
import sys
import django
import json

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

def test_ai_simple():
    """Simple test without Unicode issues"""
    from complaints.api_views import ai_chat
    from django.test import RequestFactory
    from rest_framework.response import Response
    
    factory = RequestFactory()
    
    test_messages = [
        "bijli nahi hai",
        "road problem", 
        "hello"
    ]
    
    print("Simple AI Chat Test")
    print("==================")
    
    for i, message in enumerate(test_messages, 1):
        print(f"\nTest {i}: {message}")
        print("-" * 20)
        
        request_data = json.dumps({
            'message': message,
            'session_id': f'test_{i}',
            'preferred_language': 'english'  # Use English to avoid Unicode
        })
        
        request = factory.post(
            '/api/ai/chat/', 
            data=request_data,
            content_type='application/json'
        )
        
        try:
            response = ai_chat(request)
            
            if isinstance(response, Response):
                data = response.data
                
                if data.get('success'):
                    # Clean response text of emojis for console
                    response_text = data.get('response', 'No response')
                    clean_text = ''.join(char for char in response_text if ord(char) < 128)
                    
                    print(f"SUCCESS: {clean_text[:100]}...")
                    print(f"Category: {data.get('detected_category', 'None')}")
                    print(f"Language: {data.get('language', 'None')}")
                    print(f"Urgency: {data.get('urgency', 'None')}")
                    print(f"Next Step: {data.get('next_step', 'None')}")
                else:
                    print(f"ERROR: {data.get('message', 'Unknown error')}")
            else:
                print(f"Unexpected response type: {type(response)}")
                
        except Exception as e:
            print(f"Exception: {str(e)}")

if __name__ == "__main__":
    test_ai_simple()