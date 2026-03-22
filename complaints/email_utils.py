from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.conf import settings
from django.utils import timezone
import requests
import json

def send_email_with_resend(recipient_email, subject, html_content):
    """
    Send email using Resend API (Fast & Free)
    """
    try:
        resend_api_key = getattr(settings, 'RESEND_API_KEY', '')
        
        print(f"[Email] DEBUG: Resend API Key present: {bool(resend_api_key)}")
        if resend_api_key:
            print(f"[Email] DEBUG: API Key starts with: {resend_api_key[:10]}...")
        
        if not resend_api_key:
            print("[Email] Resend API key not configured, falling back to SMTP")
            return False
        
        url = "https://api.resend.com/emails"
        headers = {
            "Authorization": f"Bearer {resend_api_key}",
            "Content-Type": "application/json"
        }
        
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'onboarding@resend.dev')
        
        payload = {
            "from": from_email,
            "to": [recipient_email],
            "subject": subject,
            "html": html_content
        }
        
        response = requests.post(url, headers=headers, json=payload, timeout=10)
        
        if response.status_code == 200:
            print(f"[Email] ✓ Resend API: Email sent successfully to {recipient_email}")
            return True
        else:
            print(f"[Email] ✗ Resend API Error: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"[Email] ✗ Resend API Exception: {str(e)}")
        return False

def send_email_template(template_name, context, recipient_email, subject):
    """
    Send HTML email using template
    Tries Resend first, falls back to SMTP if Resend fails
    
    Args:
        template_name: Name of the email template (without .html)
        context: Dictionary of context variables for the template
        recipient_email: Recipient's email address
        subject: Email subject line
    """
    try:
        # Add base URL to context
        context['base_url'] = settings.BASE_URL if hasattr(settings, 'BASE_URL') else 'http://127.0.0.1:8000'
        
        # Render HTML content
        html_content = render_to_string(f'emails/{template_name}.html', context)
        
        # Try Resend first (Fast & Free)
        resend_api_key = getattr(settings, 'RESEND_API_KEY', '')
        if resend_api_key:
            print(f"[Email] Attempting to send via Resend API to {recipient_email}")
            if send_email_with_resend(recipient_email, subject, html_content):
                return True
            print(f"[Email] Resend failed, falling back to SMTP...")
        
        # Fallback to SMTP
        print(f"[Email] Sending via SMTP to {recipient_email}")
        email = EmailMultiAlternatives(
            subject=subject,
            body=f"Please view this email in an HTML-compatible email client.",
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[recipient_email]
        )
        
        email.attach_alternative(html_content, "text/html")
        email.send()
        
        print(f"[Email] ✓ SMTP: Successfully sent '{subject}' to {recipient_email}")
        return True
    except Exception as e:
        print(f"[Email] ✗ Error sending email to {recipient_email}: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def send_otp_email(user_email, otp_code, user_name='User'):
    """Send OTP verification email"""
    context = {
        'user_name': user_name,
        'otp_code': otp_code,
    }
    return send_email_template(
        'otp_email',
        context,
        user_email,
        f'Your OTP Code: {otp_code} - JanHelp'
    )


def send_password_reset_email(user_email, user_name, reset_link, reset_code=None):
    """Send password reset email"""
    context = {
        'user_name': user_name,
        'reset_link': reset_link,
        'reset_code': reset_code,
    }
    return send_email_template(
        'password_reset_email',
        context,
        user_email,
        'Reset Your Password - JanHelp'
    )


def send_welcome_email(user_email, user_name, user_mobile, join_date, user_role=None):
    """Send welcome email to new users"""
    context = {
        'user_name': user_name,
        'user_email': user_email,
        'user_mobile': user_mobile,
        'join_date': join_date,
        'user_role': user_role,
        'dashboard_url': f"{settings.BASE_URL if hasattr(settings, 'BASE_URL') else 'http://127.0.0.1:8000'}/dashboard/",
    }
    return send_email_template(
        'welcome_email',
        context,
        user_email,
        'Welcome to JanHelp! 🎉'
    )


def send_complaint_status_email(user_email, user_name, complaint_data):
    """
    Send complaint status update email
    """
    base_url = settings.BASE_URL if hasattr(settings, 'BASE_URL') else 'http://127.0.0.1:8000'
    
    context = {
        'user_name': user_name,
        **complaint_data,
        'complaint_url': f"{base_url}/complaint/{complaint_data['complaint_number']}/",
        'track_url': f"{base_url}/track/",
    }
    
    return send_email_template(
        'complaint_status_email',
        context,
        user_email,
        f"Complaint #{complaint_data['complaint_number']} Status Update - JanHelp"
    )


def send_complaint_resolved_email(user_email, user_name, complaint_data):
    """
    Send complaint resolved email
    """
    base_url = settings.BASE_URL if hasattr(settings, 'BASE_URL') else 'http://127.0.0.1:8000'
    
    context = {
        'user_name': user_name,
        **complaint_data,
        'complaint_url': f"{base_url}/complaint/{complaint_data['complaint_number']}/",
        'rating_url': f"{base_url}/complaint/{complaint_data['complaint_number']}/rate/",
        'dashboard_url': f"{base_url}/dashboard/",
    }
    
    return send_email_template(
        'complaint_resolved_email',
        context,
        user_email,
        f"✅ Complaint #{complaint_data['complaint_number']} Resolved - JanHelp"
    )


def send_department_assignment_email(user_email, user_name, department_name, user_role, city_name):
    """Send department assignment notification email"""
    base_url = settings.BASE_URL if hasattr(settings, 'BASE_URL') else 'http://127.0.0.1:8000'
    
    context = {
        'user_name': user_name,
        'user_email': user_email,
        'department_name': department_name,
        'user_role': user_role,
        'city_name': city_name,
        'login_url': f"{base_url}/login/",
    }
    
    return send_email_template(
        'department_assignment_email',
        context,
        user_email,
        f'Department Access Granted: {department_name} - JanHelp'
    )


def send_department_credentials_email(email, department, login_password):
    """Send department login credentials"""
    print(f"\n[send_department_credentials_email] Called")
    print(f"  - email: {email}")
    print(f"  - department: {department.name if department else 'None'}")
    
    # Serialize department object
    dept_data = None
    if department:
        try:
            dept_data = {
                'name': department.name,
                'email': department.email,
                'phone': department.phone if hasattr(department, 'phone') else '',
                'address': department.address if hasattr(department, 'address') else '',
                'type': department.get_department_type_display() if hasattr(department, 'get_department_type_display') else '',
                'city': department.city if hasattr(department, 'city') else '',
                'state': department.state if hasattr(department, 'state') else '',
            }
            print(f"  - Department serialized")
        except Exception as e:
            print(f"  - ERROR: {str(e)}")
    
    context = {
        'email': email,
        'department': dept_data,
        'login_password': login_password,
    }
    
    result = send_email_template(
        'department_credentials',
        context,
        email,
        'Your Smart City Department Account Details - JanHelp'
    )
    print(f"  - Result: {result}")
    return result


def send_city_admin_credentials_email(email, full_name, state, city, login_password, pincode='', contact_address=''):
    """Send city admin login credentials"""
    context = {
        'email': email,
        'full_name': full_name,
        'state': state,
        'city': city,
        'login_password': login_password,
        'pincode': pincode,
        'contact_address': contact_address,
    }
    return send_email_template(
        'city_admin_credentials',
        context,
        email,
        'Your Smart City City Admin Account Details - JanHelp'
    )


def send_password_reset_credentials_email(email, user_name, new_password, department=None, city_admin_info=None):
    """Send password reset email with new credentials and account details"""
    print(f"\n[send_password_reset_credentials_email] Called with:")
    print(f"  - email: {email}")
    print(f"  - user_name: {user_name}")
    print(f"  - new_password length: {len(new_password)}")
    print(f"  - department: {department.name if department else 'None'}")
    print(f"  - city_admin_info: {bool(city_admin_info)}")
    
    context = {
        'email': email,
        'user_name': user_name,
        'new_password': new_password,
    }
    
    # Serialize department object to avoid template rendering issues
    if department:
        print(f"  - Serializing department object...")
        try:
            context['department'] = {
                'name': department.name,
                'email': department.email,
                'phone': department.phone if hasattr(department, 'phone') else '',
                'type': department.get_department_type_display() if hasattr(department, 'get_department_type_display') else '',
            }
            print(f"  - Department serialized: {context['department']['name']}")
        except Exception as e:
            print(f"  - ERROR serializing department: {str(e)}")
    
    if city_admin_info:
        context['city_admin_info'] = city_admin_info
        print(f"  - City admin info added")
    
    print(f"  - Calling send_email_template...")
    result = send_email_template(
        'password_reset_credentials',
        context,
        email,
        'Password Reset Successful - JanHelp'
    )
    print(f"  - send_email_template returned: {result}")
    return result


# Status icon mapping
STATUS_ICONS = {
    'submitted': '📝',
    'assigned': '👤',
    'in-progress': '⚙️',
    'process': '⚙️',
    'resolved': '✅',
    'solved': '✅',
    'reopened': '🔄',
    'rejected': '❌',
}

# Status class mapping
STATUS_CLASS_MAP = {
    'pending': 'submitted',
    'confirmed': 'assigned',
    'process': 'in-progress',
    'in-progress': 'in-progress',
    'solved': 'resolved',
    'resolved': 'resolved',
    'reopened': 'reopened',
    'rejected': 'rejected',
}
