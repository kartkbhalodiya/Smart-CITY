"""
Direct Email Test - Bypasses Django to test Resend API directly
"""
import requests
import os

# Test 1: Check environment variable
print("\n" + "="*60)
print("TEST 1: Environment Variable Check")
print("="*60)

resend_key = os.getenv('RESEND_API_KEY')
print(f"RESEND_API_KEY found: {bool(resend_key)}")
if resend_key:
    print(f"Key starts with: {resend_key[:15]}...")
else:
    print("❌ RESEND_API_KEY not found in environment!")

# Test 2: Direct Resend API call
print("\n" + "="*60)
print("TEST 2: Direct Resend API Call")
print("="*60)

if resend_key:
    url = "https://api.resend.com/emails"
    headers = {
        "Authorization": f"Bearer {resend_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "from": "noreply@janhelps.in",
        "to": ["academix111@gmail.com"],
        "subject": "Test - Department Password Reset",
        "html": "<h1>Test Email</h1><p>This is a test password reset email.</p><p><strong>New Password:</strong> TestPass123!</p>"
    }
    
    print(f"Sending to: academix111@gmail.com")
    print(f"From: noreply@janhelps.in")
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=10)
        print(f"\nResponse Status: {response.status_code}")
        print(f"Response Body: {response.text}")
        
        if response.status_code == 200:
            print("\n✅ Email sent successfully via Resend API!")
        else:
            print(f"\n❌ Resend API Error: {response.status_code}")
            print(f"Error details: {response.text}")
    except Exception as e:
        print(f"\n❌ Exception: {str(e)}")
else:
    print("❌ Cannot test - API key not found")

print("\n" + "="*60)
print("Test Complete")
print("="*60 + "\n")
