from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.conf import settings
from django.utils import timezone

def send_email_template(template_name, context, recipient_email, subject):
    """
    Send HTML email using template
    
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
        
        # Create email
        email = EmailMultiAlternatives(
            subject=subject,
            body=f"Please view this email in an HTML-compatible email client.",
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[recipient_email]
        )
        
        email.attach_alternative(html_content, "text/html")
        email.send()
        
        print(f"[Email] Successfully sent '{subject}' to {recipient_email}")
        return True
    except Exception as e:
        print(f"[Email] Error sending email to {recipient_email}: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def send_otp_email(user_email, otp_code, user_name='User'):
    """Send OTP verification email"""
    context = {
        'user_name': user_name,
        'otp_code': otp_code,
    }
    send_email_template(
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
    send_email_template(
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
    send_email_template(
        'welcome_email',
        context,
        user_email,
        'Welcome to JanHelp! 🎉'
    )


def send_complaint_status_email(user_email, user_name, complaint_data):
    """
    Send complaint status update email
    
    complaint_data should include:
    - complaint_number
    - complaint_title
    - status_text
    - status_class (submitted, assigned, in-progress, resolved, reopened, rejected)
    - status_icon
    - submitted_date
    - department_name
    - location
    - updated_date
    - status_message (optional)
    - timeline_events (optional list)
    """
    base_url = settings.BASE_URL if hasattr(settings, 'BASE_URL') else 'http://127.0.0.1:8000'
    
    context = {
        'user_name': user_name,
        **complaint_data,
        'complaint_url': f"{base_url}/complaint/{complaint_data['complaint_number']}/",
        'track_url': f"{base_url}/track/",
    }
    
    send_email_template(
        'complaint_status_email',
        context,
        user_email,
        f"Complaint #{complaint_data['complaint_number']} Status Update - JanHelp"
    )


def send_complaint_resolved_email(user_email, user_name, complaint_data):
    """
    Send complaint resolved email
    
    complaint_data should include:
    - complaint_number
    - complaint_title
    - department_name
    - submitted_date
    - resolved_date
    - resolution_time
    - resolution_notes (optional)
    - proof_images (optional list)
    """
    base_url = settings.BASE_URL if hasattr(settings, 'BASE_URL') else 'http://127.0.0.1:8000'
    
    context = {
        'user_name': user_name,
        **complaint_data,
        'complaint_url': f"{base_url}/complaint/{complaint_data['complaint_number']}/",
        'rating_url': f"{base_url}/complaint/{complaint_data['complaint_number']}/rate/",
        'dashboard_url': f"{base_url}/dashboard/",
    }
    
    send_email_template(
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
    
    send_email_template(
        'department_assignment_email',
        context,
        user_email,
        f'Department Access Granted: {department_name} - JanHelp'
    )


def send_department_credentials_email(email, department, login_password):
    """Send department login credentials"""
    context = {
        'email': email,
        'department': department,
        'login_password': login_password,
    }
    send_email_template(
        'department_credentials',
        context,
        email,
        'Your Smart City Department Account Details - JanHelp'
    )


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
    send_email_template(
        'city_admin_credentials',
        context,
        email,
        'Your Smart City City Admin Account Details - JanHelp'
    )


def send_password_reset_credentials_email(email, user_name, new_password, department=None, city_admin_info=None):
    """Send password reset email with new credentials and account details"""
    context = {
        'email': email,
        'user_name': user_name,
        'new_password': new_password,
        'department': department,
        'city_admin_info': city_admin_info,
    }
    send_email_template(
        'password_reset_credentials',
        context,
        email,
        'Password Reset Successful - JanHelp'
    )


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
