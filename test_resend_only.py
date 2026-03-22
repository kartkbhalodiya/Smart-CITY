import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from complaints.email_utils import send_password_reset_credentials_email

print("\n" + "="*60)
print("RESEND API EMAIL TEST")
print("="*60)

# Test 1: Send to verified email (should work)
print("\nTest 1: Sending to verified email (bhalodiyakartik1911@gmail.com)")
print("-" * 60)

result1 = send_password_reset_credentials_email(
    email="bhalodiyakartik1911@gmail.com",
    user_name="Test User",
    new_password="TestPassword123!",
    department=None,
    city_admin_info=None
)

if result1:
    print("SUCCESS: Email sent to verified address!")
else:
    print("FAILED: Could not send email")

# Test 2: Send to non-verified email (will fail in testing mode)
print("\n\nTest 2: Sending to non-verified email (thestayvora@gmail.com)")
print("-" * 60)
print("Expected: This will FAIL because domain is not verified")

result2 = send_password_reset_credentials_email(
    email="thestayvora@gmail.com",
    user_name="Department User",
    new_password="TestPassword123!",
    department=None,
    city_admin_info=None
)

if result2:
    print("SUCCESS: Email sent!")
else:
    print("FAILED: Domain verification required")

print("\n" + "="*60)
print("SUMMARY")
print("="*60)
print("\nCurrent Configuration:")
print("  - Email Provider: Resend API")
print("  - Testing Mode: YES")
print("  - Can send to: bhalodiyakartik1911@gmail.com ONLY")
print("\nTo send to all users:")
print("  1. Verify domain at: https://resend.com/domains")
print("  2. Add domain: janhelps.in")
print("  3. Update .env: DEFAULT_FROM_EMAIL=noreply@janhelps.in")
print("\nSee RESEND_EMAIL_GUIDE.md for detailed instructions")
print("="*60 + "\n")
