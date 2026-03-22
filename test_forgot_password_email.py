"""
Test Forgot Password Email Flow
This simulates exactly what happens when a department user requests password reset
"""

# Test email content that should be sent
test_email_html = """
<!DOCTYPE html>
<html>
<head><title>Password Reset</title></head>
<body>
<h1>Password Reset Confirmation</h1>
<p>Dear Test User,</p>
<p>Your password has been reset.</p>
<div>
    <p><strong>Login Email:</strong> test@example.com</p>
    <p><strong>Temporary Password:</strong> TestPass123!</p>
    <p><strong>Department:</strong> Water Department</p>
</div>
<a href="http://localhost:8000/login/">Access My Dashboard</a>
</body>
</html>
"""

import requests

# Direct Resend API test
api_key = "re_dcPXW18d_9WjpDnmYLKCKn2xDzFAWNW2d"
url = "https://api.resend.com/emails"

headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

payload = {
    "from": "noreply@janhelps.in",
    "to": ["academix111@gmail.com"],
    "subject": "Password Reset Successful - JanHelp",
    "html": test_email_html
}

print("Testing forgot password email...")
print(f"From: noreply@janhelps.in")
print(f"To: academix111@gmail.com")
print(f"Subject: Password Reset Successful - JanHelp")

try:
    response = requests.post(url, headers=headers, json=payload, timeout=10)
    print(f"\nStatus: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code == 200:
        print("\n✅ SUCCESS - Email sent!")
        print("Check your inbox: academix111@gmail.com")
    else:
        print(f"\n❌ FAILED - Status {response.status_code}")
        print(f"Error: {response.text}")
except Exception as e:
    print(f"\n❌ EXCEPTION: {str(e)}")
