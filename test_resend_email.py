import os
import sys
import django

# Setup Django
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from complaints.email_utils import send_email_template

print("="*60)
print("RESEND EMAIL TEST")
print("="*60)

# Test email
test_email = input("\nEnter your email to test: ").strip()

if not test_email:
    print("❌ No email provided!")
    sys.exit(1)

print(f"\n📧 Sending test email to: {test_email}")
print("⏳ Please wait...\n")

# Send test email
context = {
    'user_name': 'Test User',
    'new_password': 'TestPassword123!',
}

result = send_email_template(
    'password_reset_credentials',
    context,
    test_email,
    'Test Email - Resend Integration'
)

print("\n" + "="*60)
if result:
    print("✅ SUCCESS! Email sent successfully!")
    print(f"📬 Check your inbox: {test_email}")
    print("\nIf using Resend, email should arrive in 1-3 seconds!")
else:
    print("❌ FAILED! Email could not be sent.")
    print("\nCheck the error messages above.")
print("="*60)
