#!/usr/bin/env python3
"""
Test script for AI Chat API
"""
import os
import sys
import django
import requests
import json

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

def test_ai_chat_local():
    """Test AI chat using local Django server"""
    from complaints.api_views import ai_chat
    from django.test import RequestFactory
    from rest_framework.response import Response
    import json
    
    factory = RequestFactory()
    
    # Test data
    test_messages = [
        "bijli nahi hai 3 din se",
        "road me gadda hai",
        "garbage not collected",
        "hello",
        "water problem"
    ]
    
    print("Testing AI Chat API locally...")
    print("=" * 50)
    
    for i, message in enumerate(test_messages, 1):
        print(f"\nTest {i}: '{message}'")
        print("-" * 30)
        
        # Create request with proper JSON data
        request_data = json.dumps({
            'message': message,
            'session_id': f'test_session_{i}',
            'preferred_language': 'hindi'
        })
        
        request = factory.post(
            '/api/ai/chat/', 
            data=request_data,
            content_type='application/json'
        )
        
        try:
            # Call the view function directly
            response = ai_chat(request)
            
            if isinstance(response, Response):
                response_data = response.data
                
                if response_data.get('success'):
                    print(f"SUCCESS: {response_data.get('response', 'No response')}")
                    print(f"   Category: {response_data.get('detected_category', 'None')}")
                    print(f"   Language: {response_data.get('language', 'None')}")
                    print(f"   Urgency: {response_data.get('urgency', 'None')}")
                else:
                    print(f"ERROR: {response_data.get('message', 'Unknown error')}")
            else:
                print(f"ERROR: Unexpected response type: {type(response)}")
                
        except Exception as e:
            print(f"ERROR: Exception: {str(e)}")
            import traceback
            traceback.print_exc()

def test_ai_chat_http():
    """Test AI chat using HTTP requests"""
    base_url = "http://127.0.0.1:8000/api"  # Use HTTP, not HTTPS
    
    test_messages = [
        "bijli nahi hai 3 din se",
        "road me gadda hai", 
        "garbage not collected",
        "hello",
        "water problem"
    ]
    
    print("\nTesting AI Chat API via HTTP...")
    print("=" * 50)
    
    for i, message in enumerate(test_messages, 1):
        print(f"\nTest {i}: '{message}'")
        print("-" * 30)
        
        try:
            response = requests.post(
                f"{base_url}/ai/chat/",
                json={
                    'message': message,
                    'session_id': f'test_session_{i}',
                    'preferred_language': 'hindi'
                },
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            
            print(f"Status Code: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    print(f"SUCCESS: {data.get('response', 'No response')}")
                    print(f"   Category: {data.get('detected_category', 'None')}")
                    print(f"   Language: {data.get('language', 'None')}")
                    print(f"   Urgency: {data.get('urgency', 'None')}")
                else:
                    print(f"ERROR: {data.get('message', 'Unknown error')}")
            else:
                print(f"HTTP ERROR: {response.text}")
                
        except requests.exceptions.RequestException as e:
            print(f"REQUEST FAILED: {str(e)}")
        except Exception as e:
            print(f"EXCEPTION: {str(e)}")

if __name__ == "__main__":
    print("AI Chat API Test")
    print("================")
    
    # Test locally first
    test_ai_chat_local()
    
    # Then test via HTTP (requires server to be running)
    print("\n" + "="*60)
    print("Note: For HTTP tests, make sure Django server is running:")
    print("python manage.py runserver 127.0.0.1:8000")
    print("="*60)
    
    try:
        test_ai_chat_http()
    except Exception as e:
        print(f"HTTP tests skipped: {e}")