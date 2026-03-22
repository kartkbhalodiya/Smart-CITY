import os
import sys
import django
import requests

# Setup Django
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from django.conf import settings

print("="*60)
print("RESEND API DIRECT TEST")
print("="*60)

# Check if API key is loaded
api_key = getattr(settings, 'RESEND_API_KEY', '')
print(f"\n1. API Key Check:")
print(f"   Found: {'YES' if api_key else 'NO'}")
if api_key:
    print(f"   Value: {api_key[:10]}...{api_key[-5:]}")

# Test email
test_email = input("\n2. Enter your email to test: ").strip()

if not test_email:
    print("No email provided!")
    sys.exit(1)

print(f"\n3. Sending test email via Resend API...")
print(f"   To: {test_email}")
print(f"   From: {getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@janhelps.in')}")

# Direct API call
url = "https://api.resend.com/emails"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

payload = {
    "from": getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@janhelps.in'),
    "to": [test_email],
    "subject": "Resend API Test - Smart City",
    "html": "<h1>Test Email</h1><p>If you received this, Resend is working perfectly!</p>"
}

try:
    print("\n4. Making API request...")
    response = requests.post(url, headers=headers, json=payload, timeout=10)
    
    print(f"\n5. Response:")
    print(f"   Status Code: {response.status_code}")
    print(f"   Response: {response.text}")
    
    if response.status_code == 200:
        print("\nSUCCESS! Email sent via Resend API!")
        print(f"Check your inbox: {test_email}")
    else:
        print("\nFAILED! Resend API returned an error.")
        print("\nPossible issues:")
        print("- API key might be invalid")
        print("- Email domain not verified")
        print("- Rate limit exceeded")
        
except Exception as e:
    print(f"\nERROR: {str(e)}")
    import traceback
    traceback.print_exc()

print("\n" + "="*60)
