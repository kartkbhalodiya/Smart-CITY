"""
Test Department Password Reset Email
Run this to test if the email is being sent correctly
"""
import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from django.contrib.auth.models import User
from complaints.models import DepartmentUser
from complaints.email_utils import send_password_reset_credentials_email

# Find a department user
dept_user = DepartmentUser.objects.select_related('user', 'department').first()

if not dept_user:
    print("❌ No department user found in database!")
    exit(1)

user = dept_user.user
department = dept_user.department

print(f"\n{'='*60}")
print(f"Testing Password Reset Email for Department User")
print(f"{'='*60}")
print(f"User: {user.username}")
print(f"Email: {user.email}")
print(f"Department: {department.name}")
print(f"Department Email: {department.email}")
print(f"{'='*60}\n")

# Test sending email
print("Sending test password reset email...")
result = send_password_reset_credentials_email(
    email=user.email,
    user_name=user.get_full_name() or user.username,
    new_password="TestPassword123!",
    department=department,
    city_admin_info=None
)

print(f"\n{'='*60}")
if result:
    print("✅ Email sent successfully!")
    print(f"Check inbox: {user.email}")
else:
    print("❌ Email sending failed!")
    print("Check the console output above for errors")
print(f"{'='*60}\n")
