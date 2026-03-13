"""
Test Email Configuration and Forgot Password Email

Run this script to test if your email configuration is working:
python test_email.py
"""

import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from django.core.mail import send_mail
from django.conf import settings
from complaints.email_utils import send_password_reset_credentials_email

def test_basic_email():
    """Test basic email sending"""
    print("\n" + "="*60)
    print("Testing Basic Email Configuration")
    print("="*60)
    
    print(f"\nEmail Backend: {settings.EMAIL_BACKEND}")
    print(f"Email Host: {settings.EMAIL_HOST}")
    print(f"Email Port: {settings.EMAIL_PORT}")
    print(f"Email Use TLS: {settings.EMAIL_USE_TLS}")
    print(f"Email Host User: {settings.EMAIL_HOST_USER}")
    print(f"Default From Email: {settings.DEFAULT_FROM_EMAIL}")
    
    if not settings.EMAIL_HOST_USER:
        print("\n❌ ERROR: EMAIL_HOST_USER is not configured!")
        print("Please set EMAIL_HOST_USER in your .env file")
        return False
    
    if not settings.EMAIL_HOST_PASSWORD:
        print("\n❌ ERROR: EMAIL_HOST_PASSWORD is not configured!")
        print("Please set EMAIL_HOST_PASSWORD in your .env file")
        return False
    
    print("\n✅ Email configuration looks good!")
    
    # Test sending a simple email
    test_email = input("\nEnter your email to test: ").strip()
    if not test_email:
        print("❌ No email provided, skipping test")
        return False
    
    try:
        print(f"\nSending test email to {test_email}...")
        send_mail(
            subject='JanHelp - Test Email',
            message='This is a test email from JanHelp. If you received this, your email configuration is working!',
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[test_email],
            fail_silently=False,
        )
        print("✅ Test email sent successfully!")
        print(f"Check your inbox at {test_email}")
        return True
    except Exception as e:
        print(f"❌ Error sending test email: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def test_forgot_password_email():
    """Test forgot password email template"""
    print("\n" + "="*60)
    print("Testing Forgot Password Email Template")
    print("="*60)
    
    test_email = input("\nEnter email to send password reset test: ").strip()
    if not test_email:
        print("❌ No email provided, skipping test")
        return False
    
    # Test data
    test_department = type('Department', (), {
        'name': 'Test Department',
        'unique_id': 'TEST123',
        'city': 'Test City',
        'state': 'Test State'
    })()
    
    try:
        print(f"\nSending password reset email to {test_email}...")
        send_password_reset_credentials_email(
            email=test_email,
            user_name='Test User',
            new_password='TestPass123!@#',
            department=test_department,
            city_admin_info=None
        )
        print("✅ Password reset email sent successfully!")
        print(f"Check your inbox at {test_email}")
        return True
    except Exception as e:
        print(f"❌ Error sending password reset email: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def check_department_users():
    """Check if there are any department users or city admins"""
    print("\n" + "="*60)
    print("Checking Department Users and City Admins")
    print("="*60)
    
    from django.contrib.auth.models import User
    from complaints.models import DepartmentUser, CityAdmin
    
    dept_users = DepartmentUser.objects.select_related('user', 'department').all()
    city_admins = CityAdmin.objects.select_related('user').all()
    
    print(f"\nDepartment Users: {dept_users.count()}")
    for du in dept_users:
        print(f"  - {du.user.email} ({du.department.name})")
    
    print(f"\nCity Admins: {city_admins.count()}")
    for ca in city_admins:
        print(f"  - {ca.user.email} ({ca.city_name}, {ca.state})")
    
    if dept_users.count() == 0 and city_admins.count() == 0:
        print("\n⚠️  WARNING: No department users or city admins found!")
        print("Forgot password only works for department users and city admins.")
        print("Please create a department or city admin first.")
        return False
    
    return True

def main():
    print("\n" + "="*60)
    print("JanHelp Email Configuration Test")
    print("="*60)
    
    # Check department users
    check_department_users()
    
    # Test basic email
    if test_basic_email():
        print("\n✅ Basic email test passed!")
    else:
        print("\n❌ Basic email test failed!")
        print("\nPlease check your email configuration in .env file:")
        print("  EMAIL_HOST_USER=your-email@gmail.com")
        print("  EMAIL_HOST_PASSWORD=your-app-password")
        print("\nFor Gmail, you need to:")
        print("  1. Enable 2-factor authentication")
        print("  2. Generate an App Password")
        print("  3. Use the App Password (not your regular password)")
        return
    
    # Test forgot password email
    print("\n")
    if input("Do you want to test forgot password email? (y/n): ").lower() == 'y':
        test_forgot_password_email()
    
    print("\n" + "="*60)
    print("Test Complete!")
    print("="*60)

if __name__ == '__main__':
    main()
