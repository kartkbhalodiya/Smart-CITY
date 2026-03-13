from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import login, logout, authenticate
from django.contrib.auth.hashers import check_password
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.contrib import messages
from django.http import JsonResponse
from .models import (
    OTP, Complaint, Department, DepartmentUser, CityAdmin, CitizenProfile,
    ComplaintMedia, ComplaintResolutionProof, ManagedState, ManagedCity,
    ComplaintCategory, ComplaintSubcategory, ComplaintCategoryField, ComplaintFieldResponse,
    ComplaintReopenProof
)
import os
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile, File
from django.db import models, IntegrityError, transaction
from django.db.models import Q, Count, Avg
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from django.utils import timezone
import random
import urllib.request
import json
import re
import string
import uuid
from django.utils.text import slugify
from django.urls import reverse
from datetime import timedelta, datetime

def generate_otp():
    return str(random.randint(100000, 999999))

def send_otp_email(email, otp):
    from threading import Thread
    from django.template.loader import render_to_string
    from django.core.mail import EmailMultiAlternatives
    
    def send():
        try:
            subject = 'Your Smart City OTP Code'
            
            # HTML email content with glassmorphism design
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Smart City OTP</title>
                <style>
                    body {{
                        margin: 0;
                        padding: 0;
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        min-height: 100vh;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                    }}
                    .email-container {{
                        max-width: 600px;
                        margin: 20px;
                        background: rgba(255, 255, 255, 0.25);
                        backdrop-filter: blur(20px);
                        -webkit-backdrop-filter: blur(20px);
                        border-radius: 20px;
                        border: 1px solid rgba(255, 255, 255, 0.3);
                        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                        overflow: hidden;
                    }}
                    .header {{
                        background: rgba(255, 255, 255, 0.1);
                        padding: 30px;
                        text-align: center;
                        border-bottom: 1px solid rgba(255, 255, 255, 0.2);
                    }}
                    .logo {{
                        font-size: 48px;
                        color: #ffffff;
                        margin-bottom: 10px;
                    }}
                    .title {{
                        color: #ffffff;
                        font-size: 28px;
                        font-weight: 700;
                        margin: 0;
                        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                    }}
                    .subtitle {{
                        color: rgba(255, 255, 255, 0.9);
                        font-size: 16px;
                        margin: 5px 0 0 0;
                    }}
                    .content {{
                        padding: 40px 30px;
                        text-align: center;
                    }}
                    .otp-box {{
                        background: rgba(255, 255, 255, 0.9);
                        border-radius: 15px;
                        padding: 30px;
                        margin: 20px 0;
                        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
                    }}
                    .otp-label {{
                        color: #333;
                        font-size: 18px;
                        font-weight: 600;
                        margin-bottom: 15px;
                    }}
                    .otp-code {{
                        font-size: 36px;
                        font-weight: 800;
                        color: #667eea;
                        letter-spacing: 8px;
                        margin: 10px 0;
                        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                    }}
                    .message {{
                        color: #ffffff;
                        font-size: 16px;
                        line-height: 1.6;
                        margin: 20px 0;
                    }}
                    .footer {{
                        background: rgba(0, 0, 0, 0.1);
                        padding: 20px 30px;
                        text-align: center;
                        border-top: 1px solid rgba(255, 255, 255, 0.2);
                    }}
                    .footer-text {{
                        color: rgba(255, 255, 255, 0.8);
                        font-size: 14px;
                        margin: 0;
                    }}
                    .security-note {{
                        background: rgba(255, 193, 7, 0.2);
                        border: 1px solid rgba(255, 193, 7, 0.3);
                        border-radius: 10px;
                        padding: 15px;
                        margin: 20px 0;
                        color: #ffffff;
                        font-size: 14px;
                    }}
                </style>
            </head>
            <body>
                <div class="email-container">
                    <div class="header">
                        <div class="logo">🏛️</div>
                        <h1 class="title">SMART CITY</h1>
                        <p class="subtitle">Secure Access Code</p>
                    </div>
                    <div class="content">
                        <div class="otp-box">
                            <div class="otp-label">Your One-Time Password</div>
                            <div class="otp-code">{otp}</div>
                        </div>
                        <p class="message">
                            Use this OTP to complete your login to the Smart City portal. 
                            This code is valid for 10 minutes and can only be used once.
                        </p>
                        <div class="security-note">
                            🔒 <strong>Security Notice:</strong> Never share this OTP with anyone. 
                            Smart City staff will never ask for your OTP.
                        </div>
                    </div>
                    <div class="footer">
                        <p class="footer-text">
                            © 2024 Smart City Portal | Secure Citizen Services
                        </p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            # Plain text fallback
            text_content = f'Your Smart City OTP is: {otp}. This code is valid for 10 minutes.'
            
            msg = EmailMultiAlternatives(subject, text_content, 'noreply@smartcity.com', [email])
            msg.attach_alternative(html_content, "text/html")
            msg.send(fail_silently=True)
            
        except Exception:
            pass  # Silently fail
    Thread(target=send, daemon=True).start()


def generate_strong_password(length=14):
    """Generate a strong password with upper, lower, digit, and symbol chars."""
    length = max(10, int(length))
    pool_upper = string.ascii_uppercase
    pool_lower = string.ascii_lowercase
    pool_digits = string.digits
    pool_symbols = '!@#$%^&*()-_=+'
    password_chars = [
        random.choice(pool_upper),
        random.choice(pool_lower),
        random.choice(pool_digits),
        random.choice(pool_symbols),
    ]
    full_pool = pool_upper + pool_lower + pool_digits + pool_symbols
    password_chars.extend(random.choice(full_pool) for _ in range(length - 4))
    random.shuffle(password_chars)
    return ''.join(password_chars)


def _is_strong_password(password):
    if len(password) < 10:
        return False
    has_upper = any(ch.isupper() for ch in password)
    has_lower = any(ch.islower() for ch in password)
    has_digit = any(ch.isdigit() for ch in password)
    has_symbol = any(ch in '!@#$%^&*()-_=+' for ch in password)
    return has_upper and has_lower and has_digit and has_symbol


def send_department_credentials_email(email, department, login_password):
    """Send department login credentials and department details to department email."""
    from threading import Thread
    from django.core.mail import EmailMultiAlternatives
    
    def send():
        try:
            subject = 'Your Smart City Department Account Details'
            
            # HTML email content with glassmorphism design
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Department Account Details</title>
                <style>
                    body {{
                        margin: 0;
                        padding: 0;
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
                        min-height: 100vh;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                    }}
                    .email-container {{
                        max-width: 650px;
                        margin: 20px;
                        background: rgba(255, 255, 255, 0.25);
                        backdrop-filter: blur(20px);
                        -webkit-backdrop-filter: blur(20px);
                        border-radius: 20px;
                        border: 1px solid rgba(255, 255, 255, 0.3);
                        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                        overflow: hidden;
                    }}
                    .header {{
                        background: rgba(255, 255, 255, 0.1);
                        padding: 30px;
                        text-align: center;
                        border-bottom: 1px solid rgba(255, 255, 255, 0.2);
                    }}
                    .logo {{
                        font-size: 48px;
                        color: #ffffff;
                        margin-bottom: 10px;
                    }}
                    .title {{
                        color: #ffffff;
                        font-size: 28px;
                        font-weight: 700;
                        margin: 0;
                        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                    }}
                    .subtitle {{
                        color: rgba(255, 255, 255, 0.9);
                        font-size: 16px;
                        margin: 5px 0 0 0;
                    }}
                    .content {{
                        padding: 30px;
                    }}
                    .welcome-message {{
                        color: #ffffff;
                        font-size: 18px;
                        text-align: center;
                        margin-bottom: 30px;
                        line-height: 1.6;
                    }}
                    .info-section {{
                        background: rgba(255, 255, 255, 0.9);
                        border-radius: 15px;
                        padding: 25px;
                        margin: 20px 0;
                        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
                    }}
                    .section-title {{
                        color: #2563eb;
                        font-size: 20px;
                        font-weight: 700;
                        margin-bottom: 15px;
                        display: flex;
                        align-items: center;
                        gap: 10px;
                    }}
                    .info-grid {{
                        display: grid;
                        grid-template-columns: 1fr 1fr;
                        gap: 15px;
                        margin-bottom: 15px;
                    }}
                    .info-item {{
                        display: flex;
                        flex-direction: column;
                    }}
                    .info-label {{
                        color: #64748b;
                        font-size: 12px;
                        font-weight: 600;
                        text-transform: uppercase;
                        letter-spacing: 0.5px;
                        margin-bottom: 5px;
                    }}
                    .info-value {{
                        color: #1e293b;
                        font-size: 16px;
                        font-weight: 600;
                    }}
                    .credentials-box {{
                        background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
                        color: #ffffff;
                        border-radius: 15px;
                        padding: 25px;
                        margin: 20px 0;
                        text-align: center;
                        box-shadow: 0 4px 15px rgba(245, 158, 11, 0.3);
                    }}
                    .credentials-title {{
                        font-size: 20px;
                        font-weight: 700;
                        margin-bottom: 15px;
                    }}
                    .credential-item {{
                        background: rgba(255, 255, 255, 0.2);
                        border-radius: 10px;
                        padding: 15px;
                        margin: 10px 0;
                        text-align: left;
                    }}
                    .credential-label {{
                        font-size: 12px;
                        opacity: 0.9;
                        margin-bottom: 5px;
                    }}
                    .credential-value {{
                        font-size: 16px;
                        font-weight: 700;
                        word-break: break-all;
                    }}
                    .security-note {{
                        background: rgba(239, 68, 68, 0.2);
                        border: 1px solid rgba(239, 68, 68, 0.3);
                        border-radius: 10px;
                        padding: 15px;
                        margin: 20px 0;
                        color: #ffffff;
                        font-size: 14px;
                        text-align: center;
                    }}
                    .footer {{
                        background: rgba(0, 0, 0, 0.1);
                        padding: 20px 30px;
                        text-align: center;
                        border-top: 1px solid rgba(255, 255, 255, 0.2);
                    }}
                    .footer-text {{
                        color: rgba(255, 255, 255, 0.8);
                        font-size: 14px;
                        margin: 0;
                    }}
                    @media (max-width: 600px) {{
                        .info-grid {{ grid-template-columns: 1fr; }}
                        .email-container {{ margin: 10px; }}
                        .content {{ padding: 20px; }}
                    }}
                </style>
            </head>
            <body>
                <div class="email-container">
                    <div class="header">
                        <div class="logo">🏢</div>
                        <h1 class="title">SMART CITY</h1>
                        <p class="subtitle">Department Account Activated</p>
                    </div>
                    <div class="content">
                        <p class="welcome-message">
                            🎉 <strong>Congratulations!</strong> Your department account is now active and ready to serve citizens.
                        </p>
                        
                        <div class="info-section">
                            <div class="section-title">
                                🏢 Department Information
                            </div>
                            <div class="info-grid">
                                <div class="info-item">
                                    <div class="info-label">Department Name</div>
                                    <div class="info-value">{department.name}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">Department Code</div>
                                    <div class="info-value">#{department.unique_id}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">Category</div>
                                    <div class="info-value">{department.get_department_type_display()}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">SLA Hours</div>
                                    <div class="info-value">{department.sla_hours} hours</div>
                                </div>
                            </div>
                            <div class="info-grid">
                                <div class="info-item">
                                    <div class="info-label">State</div>
                                    <div class="info-value">{department.state}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">City</div>
                                    <div class="info-value">{department.city}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">Phone</div>
                                    <div class="info-value">{department.phone}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">Email</div>
                                    <div class="info-value">{department.email}</div>
                                </div>
                            </div>
                            <div class="info-item" style="grid-column: 1 / -1;">
                                <div class="info-label">Office Address</div>
                                <div class="info-value">{department.address}</div>
                            </div>
                        </div>
                        
                        <div class="credentials-box">
                            <div class="credentials-title">🔑 Login Credentials</div>
                            <div class="credential-item">
                                <div class="credential-label">Login Email</div>
                                <div class="credential-value">{email}</div>
                            </div>
                            <div class="credential-item">
                                <div class="credential-label">Password</div>
                                <div class="credential-value">{login_password}</div>
                            </div>
                        </div>
                        
                        <div class="security-note">
                            🔒 <strong>Important:</strong> Please log in and change your password immediately after first login. 
                            Keep your credentials secure and never share them with unauthorized personnel.
                        </div>
                    </div>
                    <div class="footer">
                        <p class="footer-text">
                            © 2024 Smart City Portal | Department Management System
                        </p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            # Plain text fallback
            text_content = f'''
Your department account is now active.

Department Name: {department.name}
Department Code: {department.unique_id}
Department Type: {department.get_department_type_display()}
State: {department.state}
City: {department.city}
Office Address: {department.address}
Contact Email: {department.email}
Contact Phone: {department.phone}

Login Email: {email}
Login Password: {login_password}

Please log in and change your password after first login.
'''
            
            msg = EmailMultiAlternatives(subject, text_content, 'noreply@smartcity.com', [email])
            msg.attach_alternative(html_content, "text/html")
            msg.send(fail_silently=True)
            
        except Exception:
            pass  # Silently fail
    Thread(target=send, daemon=True).start()


def send_city_admin_credentials_email(email, full_name, state, city, login_password, pincode='', contact_address=''):
    """Send city admin login credentials and assignment details."""
    from threading import Thread
    from django.core.mail import EmailMultiAlternatives
    
    def send():
        try:
            subject = 'Your Smart City City Admin Account Details'
            
            # HTML email content with glassmorphism design
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>City Admin Account</title>
                <style>
                    body {{
                        margin: 0;
                        padding: 0;
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                        min-height: 100vh;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                    }}
                    .email-container {{
                        max-width: 650px;
                        margin: 20px;
                        background: rgba(255, 255, 255, 0.25);
                        backdrop-filter: blur(20px);
                        -webkit-backdrop-filter: blur(20px);
                        border-radius: 20px;
                        border: 1px solid rgba(255, 255, 255, 0.3);
                        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                        overflow: hidden;
                    }}
                    .header {{
                        background: rgba(255, 255, 255, 0.1);
                        padding: 30px;
                        text-align: center;
                        border-bottom: 1px solid rgba(255, 255, 255, 0.2);
                    }}
                    .logo {{
                        font-size: 48px;
                        color: #ffffff;
                        margin-bottom: 10px;
                    }}
                    .title {{
                        color: #ffffff;
                        font-size: 28px;
                        font-weight: 700;
                        margin: 0;
                        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                    }}
                    .subtitle {{
                        color: rgba(255, 255, 255, 0.9);
                        font-size: 16px;
                        margin: 5px 0 0 0;
                    }}
                    .content {{
                        padding: 30px;
                    }}
                    .welcome-message {{
                        color: #ffffff;
                        font-size: 18px;
                        text-align: center;
                        margin-bottom: 30px;
                        line-height: 1.6;
                    }}
                    .info-section {{
                        background: rgba(255, 255, 255, 0.9);
                        border-radius: 15px;
                        padding: 25px;
                        margin: 20px 0;
                        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
                    }}
                    .section-title {{
                        color: #10b981;
                        font-size: 20px;
                        font-weight: 700;
                        margin-bottom: 15px;
                        display: flex;
                        align-items: center;
                        gap: 10px;
                    }}
                    .info-grid {{
                        display: grid;
                        grid-template-columns: 1fr 1fr;
                        gap: 15px;
                        margin-bottom: 15px;
                    }}
                    .info-item {{
                        display: flex;
                        flex-direction: column;
                    }}
                    .info-label {{
                        color: #64748b;
                        font-size: 12px;
                        font-weight: 600;
                        text-transform: uppercase;
                        letter-spacing: 0.5px;
                        margin-bottom: 5px;
                    }}
                    .info-value {{
                        color: #1e293b;
                        font-size: 16px;
                        font-weight: 600;
                    }}
                    .credentials-box {{
                        background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
                        color: #ffffff;
                        border-radius: 15px;
                        padding: 25px;
                        margin: 20px 0;
                        text-align: center;
                        box-shadow: 0 4px 15px rgba(139, 92, 246, 0.3);
                    }}
                    .credentials-title {{
                        font-size: 20px;
                        font-weight: 700;
                        margin-bottom: 15px;
                    }}
                    .credential-item {{
                        background: rgba(255, 255, 255, 0.2);
                        border-radius: 10px;
                        padding: 15px;
                        margin: 10px 0;
                        text-align: left;
                    }}
                    .credential-label {{
                        font-size: 12px;
                        opacity: 0.9;
                        margin-bottom: 5px;
                    }}
                    .credential-value {{
                        font-size: 16px;
                        font-weight: 700;
                        word-break: break-all;
                    }}
                    .security-note {{
                        background: rgba(59, 130, 246, 0.2);
                        border: 1px solid rgba(59, 130, 246, 0.3);
                        border-radius: 10px;
                        padding: 15px;
                        margin: 20px 0;
                        color: #ffffff;
                        font-size: 14px;
                        text-align: center;
                    }}
                    .footer {{
                        background: rgba(0, 0, 0, 0.1);
                        padding: 20px 30px;
                        text-align: center;
                        border-top: 1px solid rgba(255, 255, 255, 0.2);
                    }}
                    .footer-text {{
                        color: rgba(255, 255, 255, 0.8);
                        font-size: 14px;
                        margin: 0;
                    }}
                    @media (max-width: 600px) {{
                        .info-grid {{ grid-template-columns: 1fr; }}
                        .email-container {{ margin: 10px; }}
                        .content {{ padding: 20px; }}
                    }}
                </style>
            </head>
            <body>
                <div class="email-container">
                    <div class="header">
                        <div class="logo">🏢</div>
                        <h1 class="title">CITY ADMIN</h1>
                        <p class="subtitle">Account Activated</p>
                    </div>
                    <div class="content">
                        <p class="welcome-message">
                            🎉 <strong>Welcome {full_name}!</strong><br>
                            Your City Admin account is now active and ready to manage city services.
                        </p>
                        
                        <div class="info-section">
                            <div class="section-title">
                                🏛️ Assignment Details
                            </div>
                            <div class="info-grid">
                                <div class="info-item">
                                    <div class="info-label">Assigned State</div>
                                    <div class="info-value">{state}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">Assigned City</div>
                                    <div class="info-value">{city}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">Pincode</div>
                                    <div class="info-value">{pincode or 'Not specified'}</div>
                                </div>
                                <div class="info-item">
                                    <div class="info-label">Admin Name</div>
                                    <div class="info-value">{full_name}</div>
                                </div>
                            </div>
                            <div class="info-item" style="grid-column: 1 / -1;">
                                <div class="info-label">Contact Address</div>
                                <div class="info-value">{contact_address or 'Not specified'}</div>
                            </div>
                        </div>
                        
                        <div class="credentials-box">
                            <div class="credentials-title">🔑 Login Credentials</div>
                            <div class="credential-item">
                                <div class="credential-label">Login Email</div>
                                <div class="credential-value">{email}</div>
                            </div>
                            <div class="credential-item">
                                <div class="credential-label">Username</div>
                                <div class="credential-value">{email}</div>
                            </div>
                            <div class="credential-item">
                                <div class="credential-label">Password</div>
                                <div class="credential-value">{login_password}</div>
                            </div>
                        </div>
                        
                        <div class="security-note">
                            🔒 <strong>Important:</strong> Please log in and change your password immediately after first login. 
                            As a City Admin, you have access to sensitive city data - keep your credentials secure.
                        </div>
                    </div>
                    <div class="footer">
                        <p class="footer-text">
                            © 2024 Smart City Portal | City Administration System
                        </p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            # Plain text fallback
            text_content = f'''
Hello {full_name},

Your city admin account is now active.

Assigned State: {state}
Assigned City: {city}
Pincode: {pincode}
Contact Address: {contact_address}

Login Email: {email}
Login Username: {email}
Login Password: {login_password}

Please log in and change your password after first login.
'''
            
            msg = EmailMultiAlternatives(subject, text_content, 'noreply@smartcity.com', [email])
            msg.attach_alternative(html_content, "text/html")
            msg.send(fail_silently=True)
            
        except Exception:
            pass  # Silently fail
    Thread(target=send, daemon=True).start()


def _get_primary_complaint_email(complaint):
    if complaint.user and complaint.user.email:
        return complaint.user.email.strip()
    return (complaint.guest_email or '').strip()


def _send_complaint_notification_email(complaint, event, actor_name='System'):
    from threading import Thread
    def send():
        try:
            citizen_email = _get_primary_complaint_email(complaint)
            department_email = (complaint.assigned_department.email if complaint.assigned_department else '').strip()
            recipients = {email for email in [citizen_email, department_email] if email}
            if not recipients:
                return

            current_status = complaint.get_work_status_display()
            department_name = complaint.assigned_department.name if complaint.assigned_department else 'Not Assigned'
            complaint_no = complaint.complaint_number

            event_subjects = {
                'assigned': f'Complaint {complaint_no} assigned to {department_name}',
                'status_changed': f'Complaint {complaint_no} status changed to {current_status}',
                'closure': f'Complaint {complaint_no} marked as solved',
                'reopened': f'Complaint {complaint_no} reopened by citizen',
            }
            subject = event_subjects.get(event, f'Complaint {complaint_no} update')

            body = (
                f'Complaint Number: {complaint_no}\n'
                f'Title: {complaint.title}\n'
                f'Category: {complaint.get_complaint_type_display()}\n'
                f'Current Status: {current_status}\n'
                f'Department: {department_name}\n'
                f'City/State: {complaint.city}, {complaint.state}\n'
                f'Updated By: {actor_name}\n'
                f'Updated At: {timezone.now().strftime("%Y-%m-%d %H:%M:%S UTC")}\n'
            )

            if event == 'reopened' and complaint.reopen_reason:
                body += f'\nReopen Reason:\n{complaint.reopen_reason}\n'

            if complaint.resolution_notes:
                body += f'\nLatest Notes:\n{complaint.resolution_notes}\n'

            send_mail(
                subject,
                body,
                'noreply@smartcity.com',
                list(recipients),
                fail_silently=True,
            )
        except Exception:
            pass  # Silently fail
    Thread(target=send, daemon=True).start()


def save_temp_department_logo(uploaded_file):
    """Persist uploaded department logo temporarily between OTP steps."""
    safe_name = f"{uuid.uuid4().hex}_{uploaded_file.name}"
    temp_path = f"temp_media/department_logos/{safe_name}"
    return default_storage.save(temp_path, uploaded_file)


def build_state_options():
    """Only show states explicitly managed from super admin Add State page."""
    return list(
        ManagedState.objects
        .exclude(name__isnull=True)
        .exclude(name__exact='')
        .values_list('name', flat=True)
        .order_by('name')
    )


def build_city_options(state_name=''):
    """Only show cities explicitly managed from super admin Add City page."""
    managed_cities = ManagedCity.objects.select_related('state').exclude(name__isnull=True).exclude(name__exact='')
    if state_name:
        managed_cities = managed_cities.filter(state__name__iexact=state_name)

    options = [
        {'city_name': city.name.strip(), 'state': city.state.name.strip()}
        for city in managed_cities
        if city.name and city.state and city.state.name
    ]
    return sorted(options, key=lambda item: (item['city_name'].lower(), item['state'].lower()))


def _normalize_pincode(raw_pincode):
    return re.sub(r'\D', '', (raw_pincode or '').strip())


def lookup_indian_pincode(raw_pincode):
    normalized = _normalize_pincode(raw_pincode)
    if len(normalized) != 6:
        return None

    try:
        url = f"https://api.postalpincode.in/pincode/{normalized}"
        req = urllib.request.Request(url, headers={'User-Agent': 'SmartCityApp/1.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            payload = json.loads(response.read().decode())
    except Exception:
        return None

    if not isinstance(payload, list) or not payload:
        return None

    first_result = payload[0] or {}
    if first_result.get('Status') != 'Success':
        return None

    post_offices = first_result.get('PostOffice') or []
    if not post_offices:
        return None

    primary_office = post_offices[0] or {}
    state = (primary_office.get('State') or '').strip()
    city = (
        primary_office.get('District')
        or primary_office.get('Block')
        or primary_office.get('Name')
        or ''
    ).strip()

    if not state or not city:
        return None

    return {
        'pincode': normalized,
        'state': state,
        'city': city,
    }


MIN_SUBCATEGORIES_PER_CATEGORY = 10


def clean_unique_text_values(values):
    cleaned = []
    seen = set()
    for value in values:
        text = (value or '').strip()
        if not text:
            continue
        lowered = text.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        cleaned.append(text)
    return cleaned


def extract_unique_subcategory_rows(raw_ids, raw_names):
    rows = []
    seen = set()
    for idx, raw_name in enumerate(raw_names):
        clean_name = (raw_name or '').strip()
        if not clean_name:
            continue
        lowered = clean_name.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        raw_id = (raw_ids[idx] if idx < len(raw_ids) else '').strip()
        rows.append((raw_id, clean_name))
    return rows


def default_subcategory_blueprint():
    return {
        'police': [
            'Theft / Robbery', 'Cyber Crime', 'Domestic Violence', 'Missing Person', 'Physical Assault',
            'Fraud / Scam', 'Harassment / Threat', 'Property Damage', 'Drug Activity', 'Noise Disturbance'
        ],
        'traffic': [
            'Signal Jumping', 'Wrong Side Driving', 'Overspeeding', 'Illegal Parking', 'No Helmet / Triple Riding',
            'Drunk Driving', 'Rash Driving', 'Accident Spot Hazard', 'Broken Traffic Signal', 'Road Encroachment'
        ],
        'construction': [
            'Road Damage / Potholes', 'Footpath Damage', 'Illegal Construction', 'Construction Debris', 'Building Safety Risk',
            'Bridge Structural Issue', 'Sewer Construction Issue', 'Public Work Delay', 'Dust Pollution from Work', 'Unsafe Barricading'
        ],
        'water': [
            'No Water Supply', 'Low Water Pressure', 'Water Leakage', 'Dirty / Contaminated Water', 'Pipeline Burst',
            'Meter Issue', 'Illegal Connection', 'Water Tank Overflow', 'Irregular Supply Timing', 'Borewell Issue'
        ],
        'electricity': [
            'Power Outage', 'Frequent Power Cuts', 'Street Light Not Working', 'Voltage Fluctuation', 'Transformer Fault',
            'Exposed Wiring', 'Meter Billing Issue', 'Illegal Electricity Use', 'Pole Damage', 'Sparking Complaint'
        ],
        'garbage': [
            'Garbage Not Collected', 'Overflowing Garbage Bin', 'Illegal Garbage Dumping', 'Dead Animal Pickup', 'Door-to-Door Pickup Missed',
            'Medical Waste Dumping', 'Burning Waste', 'Public Toilet Unclean', 'Drainside Garbage', 'Recycle Collection Issue'
        ],
        'road': [
            'Deep Pothole', 'Road Crack / Damage', 'Missing Road Sign', 'Broken Footpath', 'Waterlogging on Road',
            'Open Manhole', 'Divider Damage', 'Speed Breaker Damage', 'Road Marking Faded', 'Tree Obstruction on Road'
        ],
        'drainage': [
            'Drain Blockage', 'Sewer Overflow', 'Open Manhole', 'Drainage Backflow', 'Storm Water Logging',
            'Broken Drain Cover', 'Foul Smell from Drain', 'Mosquito Breeding Spot', 'Drain Cleaning Delay', 'Illegal Drain Connection'
        ],
        'illegal': [
            'Encroachment', 'Illegal Business', 'Gambling Activity', 'Public Nuisance', 'Unauthorized Construction',
            'Illegal Parking Stand', 'Loudspeaker Violation', 'Street Vending Obstruction', 'Land Grab Attempt', 'Substance Abuse Spot'
        ],
        'transportation': [
            'Bus Delay', 'Overcrowded Vehicle', 'Route Violation', 'Unauthorized Bus Parking', 'Bus Stop Damage',
            'Auto Rickshaw Overcharge', 'No Transport in Area', 'Unsafe School Transport', 'Vehicle Emission Issue', 'Taxi Refusal'
        ],
        'cyber': [
            'UPI Scam', 'Identity Theft', 'Phishing Link', 'Social Media Harassment', 'OTP Fraud',
            'Fake Loan App', 'Online Shopping Scam', 'SIM Swap Fraud', 'Data Leak Complaint', 'Cyber Bullying'
        ],
        'other': [
            'Noise Complaint', 'Public Safety Concern', 'Government Service Delay', 'Park Maintenance Issue', 'Animal Menace',
            'Street Light Request', 'Community Hall Issue', 'Public Event Disturbance', 'Tree Cutting Complaint', 'Miscellaneous'
        ],
    }


def ensure_unique_fields_for_each_subcategory(category):
    subcategories = list(
        category.subcategories.filter(is_active=True).order_by('display_order', 'name')
    )
    existing_fields = list(
        category.dynamic_fields.filter(is_active=True).select_related('subcategory')
    )
    max_order = max([field.display_order for field in existing_fields], default=0)
    by_subcategory = {}
    for field in existing_fields:
        if field.subcategory_id:
            by_subcategory.setdefault(field.subcategory_id, []).append(field)

    for subcategory in subcategories:
        if by_subcategory.get(subcategory.id):
            continue

        max_order += 1
        ComplaintCategoryField.objects.create(
            category=category,
            subcategory=subcategory,
            label=f'{subcategory.name} Details',
            field_type='textarea',
            options='',
            is_required=True,
            display_order=max_order,
            is_active=True,
        )
        max_order += 1
        ComplaintCategoryField.objects.create(
            category=category,
            subcategory=subcategory,
            label=f'{subcategory.name} Date',
            field_type='date',
            options='',
            is_required=False,
            display_order=max_order,
            is_active=True,
        )


def ensure_category_baseline(category, preferred_sub_names=None):
    preferred_sub_names = clean_unique_text_values(preferred_sub_names or [])

    existing_subcategories = list(category.subcategories.order_by('display_order', 'id'))
    existing_name_map = {sub.name.lower(): sub for sub in existing_subcategories}
    max_order = max([sub.display_order for sub in existing_subcategories], default=0)

    for sub_name in preferred_sub_names:
        if sub_name.lower() in existing_name_map:
            continue
        max_order += 1
        subcategory = ComplaintSubcategory.objects.create(
            category=category,
            name=sub_name,
            is_active=True,
            display_order=max_order,
        )
        existing_subcategories.append(subcategory)
        existing_name_map[sub_name.lower()] = subcategory

    fallback_index = 1
    while len(existing_subcategories) < MIN_SUBCATEGORIES_PER_CATEGORY:
        fallback_name = f'{category.name} Issue {fallback_index}'
        fallback_index += 1
        if fallback_name.lower() in existing_name_map:
            continue
        max_order += 1
        subcategory = ComplaintSubcategory.objects.create(
            category=category,
            name=fallback_name,
            is_active=True,
            display_order=max_order,
        )
        existing_subcategories.append(subcategory)
        existing_name_map[fallback_name.lower()] = subcategory

    if not category.dynamic_fields.filter(subcategory__isnull=True, is_active=True).exists():
        next_field_order = (
            category.dynamic_fields.aggregate(max_order=models.Max('display_order')).get('max_order') or 0
        ) + 1
        ComplaintCategoryField.objects.create(
            category=category,
            subcategory=None,
            label='Area / Landmark',
            field_type='text',
            options='',
            is_required=False,
            display_order=next_field_order,
            is_active=True,
        )

    ensure_unique_fields_for_each_subcategory(category)


def ensure_default_categories():
    """Create default categories and keep minimum metadata for each category."""
    default_emoji_map = {
        'police': '\U0001F694',
        'traffic': '\U0001F6A6',
        'construction': '\U0001F3D7',
        'water': '\U0001F6B0',
        'electricity': '\U0001F4A1',
        'garbage': '\U0001F5D1',
        'road': '\U0001F6A7',
        'drainage': '\U0001F4A7',
        'illegal': '\U0001F3EA',
        'transportation': '\U0001F68C',
        'cyber': '\U0001F6E1',
        'other': '\U0001F4CB',
    }
    category_blueprint = default_subcategory_blueprint()
    defaults = list(Complaint.COMPLAINT_TYPES)
    for idx, (key, label) in enumerate(defaults, start=1):
        category, _created = ComplaintCategory.objects.get_or_create(
            key=key,
            defaults={
                'name': label,
                'emoji': default_emoji_map.get(key, ''),
                'display_order': idx,
                'is_active': True,
            }
        )
        if not category.emoji and key in default_emoji_map:
            category.emoji = default_emoji_map[key]
            category.save(update_fields=['emoji'])
        ensure_category_baseline(category, preferred_sub_names=category_blueprint.get(key, []))


def get_managed_category_payload():
    """Return active categories/subcategories/field configuration for complaint form."""
    categories = list(
        ComplaintCategory.objects.filter(is_active=True)
        .prefetch_related('subcategories', 'dynamic_fields__subcategory')
        .order_by('display_order', 'name')
    )

    if not categories:
        return [], {}, {}

    category_options = [{'key': c.key, 'name': c.name, 'logo_url': c.logo.url if c.logo else ''} for c in categories]

    sub_map = {}
    field_map = {}
    for category in categories:
        active_subcategories = [s for s in category.subcategories.all() if s.is_active]
        active_subcategories.sort(key=lambda x: (x.display_order, x.name.lower()))

        sub_names = [sub.name for sub in active_subcategories]
        if not sub_names:
            sub_names = ['General']
        sub_map[category.key] = sub_names

        active_fields = [f for f in category.dynamic_fields.all() if f.is_active]
        active_fields.sort(key=lambda x: (x.display_order, x.id))

        common_fields = [field for field in active_fields if not field.subcategory_id]
        fields_by_subcategory = {}
        for field in active_fields:
            if field.subcategory_id:
                fields_by_subcategory.setdefault(field.subcategory_id, []).append(field)

        def serialize_fields(fields):
            payload = []
            for field in fields:
                options = [x.strip() for x in field.options.split(',') if x.strip()] if field.options else []
                payload.append({
                    'id': field.id,
                    'name': field.label,
                    'type': field.field_type,
                    'required': field.is_required,
                    'options': options,
                })
            return payload

        if active_subcategories:
            for sub in active_subcategories:
                merged = common_fields + fields_by_subcategory.get(sub.id, [])
                field_map[f"{category.key}::{sub.name}"] = serialize_fields(merged)
        else:
            field_map[f"{category.key}::General"] = serialize_fields(common_fields)

    return category_options, sub_map, field_map


def generate_unique_category_key(name):
    base = slugify(name)[:20] or f"cat{random.randint(100, 999)}"
    key = base
    counter = 1
    while ComplaintCategory.objects.filter(key=key).exists():
        suffix = str(counter)
        key = f"{base[:max(1, 20-len(suffix))]}{suffix}"
        counter += 1
    return key


def get_active_category_choices():
    managed = list(
        ComplaintCategory.objects.filter(is_active=True)
        .order_by('display_order', 'name')
        .values_list('key', 'name')
    )
    return managed if managed else Complaint.COMPLAINT_TYPES


def get_active_citizen_category_cards(is_guest=False):
    ensure_default_categories()
    categories = ComplaintCategory.objects.filter(is_active=True).order_by('display_order', 'name')

    emoji_map = {
        'police': '🚔',
        'traffic': '🚦',
        'construction': '🏗️',
        'water': '🚰',
        'electricity': '💡',
        'garbage': '🗑️',
        'road': '🚧',
        'drainage': '💧',
        'illegal': '🏪',
        'transportation': '🚌',
        'cyber': '🛡️',
        'other': '📋',
    }
    color_map = {
        'police': '#4361ee',
        'traffic': '#ffbe0b',
        'construction': '#f72585',
        'water': '#06b6d4',
        'electricity': '#fbbf24',
        'garbage': '#10b981',
        'road': '#6366f1',
        'drainage': '#3b82f6',
        'illegal': '#ef4444',
        'transportation': '#8b5cf6',
        'cyber': '#dc2626',
        'other': '#06ffa5',
    }

    cards = []
    for category in categories:
        if category.key == 'cyber':
            href = 'tel:1930'
        else:
            href = reverse('submit_complaint') + f"?type={category.key}"
            if is_guest:
                href += '&guest=true'

        cards.append({
            'key': category.key,
            'name': category.name,
            'emoji': category.emoji or emoji_map.get(category.key, ''),
            'color': color_map.get(category.key, '#06ffa5'),
            'logo_url': category.logo.url if category.logo else '',
            'href': href,
        })
    return cards

def register_view(request):
    context = {}
    
    if request.method == 'POST':
        registration_data = {
            'first_name': request.POST.get('name'),
            'last_name': request.POST.get('surname'),
            'email': request.POST.get('email'),
            'state': request.POST.get('state'),
            'district': request.POST.get('district'),
            'taluka': request.POST.get('taluka'),
            'city': request.POST.get('city'),
            'address': request.POST.get('address'),
            'mobile_no': request.POST.get('mobile_no'),
        }
        
        email = registration_data['email']
        if User.objects.filter(email=email).exists():
            messages.error(request, 'Email already registered!')
            return redirect('register')
            
        otp = generate_otp()
        OTP.objects.filter(email=email, is_verified=False).delete()
        OTP.objects.create(email=email, otp=otp)
        
        send_otp_email(email, otp)
        
        request.session['registration_data'] = registration_data
        request.session['email'] = email
        request.session['otp_purpose'] = 'registration'
        
        messages.success(request, 'Verification OTP sent to your email!')
        return redirect('verify_otp')
        
    return render(request, 'register.html', context)

def login_view(request):
    if request.method == 'POST':
        identifier = request.POST.get('identifier')
        password = request.POST.get('password')
        
        # 1. Try password login first (for Departments/Admin)
        if password:
            from django.contrib.auth import authenticate
            user = authenticate(request, username=identifier, password=password)
            if not user:
                # Try email as username
                try:
                    user_obj = User.objects.get(email=identifier)
                    user = authenticate(request, username=user_obj.username, password=password)
                except User.DoesNotExist:
                    pass
            
            if user:
                # Check if user is superuser or city admin - require OTP
                if user.is_superuser or CityAdmin.objects.filter(user=user).exists():
                    otp = generate_otp()
                    OTP.objects.filter(email=user.email, is_verified=False).delete()
                    OTP.objects.create(email=user.email, otp=otp)
                    
                    send_otp_email(user.email, otp)
                    
                    request.session['admin_user_id'] = user.id
                    request.session['email'] = user.email
                    request.session['otp_purpose'] = 'admin_login'
                    
                    messages.success(request, 'Admin OTP sent to your email for security!')
                    return redirect('verify_otp')
                
                # Regular department user - direct login
                login(request, user)
                messages.success(request, f'Logged in as {user.username}!')
                
                try:
                    dept_user = DepartmentUser.objects.get(user=user)
                    return redirect('department_dashboard_new')
                except DepartmentUser.DoesNotExist:
                    return redirect('user_dashboard')
            else:
                messages.error(request, 'Invalid username/email or password.')
                return redirect('login')
                
        # 2. Standard OTP flow for Citizens (if no password provided)
        email = identifier
        if not User.objects.filter(email=email).exists():
            messages.error(request, 'No account found with this email. Please register.')
            return redirect('login')
            
        otp = generate_otp()
        OTP.objects.filter(email=email, is_verified=False).delete()
        OTP.objects.create(email=email, otp=otp)
        
        send_otp_email(email, otp)
        
        request.session['email'] = email
        request.session['otp_purpose'] = 'login'
        
        messages.success(request, 'Login OTP sent to your email!')
        return redirect('verify_otp')
    
    return render(request, 'login.html')

def verify_otp_view(request):
    if request.method == 'POST':
        email = request.session.get('email')
        purpose = request.session.get('otp_purpose')
        otp_input = request.POST.get('otp')
        
        try:
            otp_obj = OTP.objects.get(email=email, otp=otp_input, is_verified=False)
            otp_obj.is_verified = True
            otp_obj.save()
            
            if purpose == 'registration':
                data = request.session.get('registration_data')
                user = User.objects.create_user(
                    username=data['email'], 
                    email=data['email'], 
                    first_name=data['first_name'], 
                    last_name=data['last_name']
                )
                CitizenProfile.objects.create(
                    user=user,
                    surname=data['last_name'],
                    state=data['state'],
                    district=data['district'],
                    taluka=data['taluka'],
                    city=data['city'],
                    address=data['address'],
                    mobile_no=data['mobile_no']
                )
                login(request, user)
                messages.success(request, 'Registration verified successfully!')
                return redirect('user_dashboard')
            elif purpose == 'admin_login':
                # Admin OTP verification
                user_id = request.session.get('admin_user_id')
                user = User.objects.get(id=user_id)
                login(request, user)
                messages.success(request, 'Admin login successful!')
                
                # Cleanup session
                request.session.pop('admin_user_id', None)
                request.session.pop('otp_purpose', None)
                
                # Check user type and redirect accordingly
                if user.is_superuser:
                    return redirect('super_admin_dashboard')
                
                # Check if city admin
                try:
                    city_admin = CityAdmin.objects.get(user=user)
                    return redirect('city_admin_dashboard')
                except CityAdmin.DoesNotExist:
                    pass
                
                return redirect('user_dashboard')
            else:
                user = User.objects.get(email=email)
                login(request, user)
                messages.success(request, 'Login successful!')

            # Cleanup session
            request.session.pop('registration_data', None)
            request.session.pop('otp_purpose', None)
            
            # Check user type and redirect accordingly
            if user.is_superuser:
                return redirect('super_admin_dashboard')
            
            # Check if city admin
            try:
                city_admin = CityAdmin.objects.get(user=user)
                return redirect('city_admin_dashboard')
            except CityAdmin.DoesNotExist:
                pass
            
            # Check if department user
            try:
                dept_user = DepartmentUser.objects.get(user=user)
                return redirect('department_dashboard_new')
            except DepartmentUser.DoesNotExist:
                pass
            
            # Regular citizen
            return redirect('user_dashboard')
            
        except OTP.DoesNotExist:
            messages.error(request, 'Invalid OTP!')
    
    return render(request, 'verify_otp.html')

def logout_view(request):
    logout(request)
    return redirect('login')

def user_dashboard(request):
    # Check if guest mode
    is_guest = request.GET.get('guest') == 'true'
    category_cards = get_active_citizen_category_cards(is_guest=is_guest)
    
    if is_guest:
        return render(request, 'user_dashboard.html', {
            'complaints': [],
            'is_guest': True,
            'user': {'first_name': 'Guest', 'last_name': 'User'},
            'category_cards': category_cards,
            'total_complaints': 0,
            'pending_complaints': 0,
            'progress_complaints': 0,
            'solved_complaints': 0,
            'recent_complaints': [],
            'all_complaints': [],
        })
    
    # Regular user dashboard (requires login)
    if not request.user.is_authenticated:
        return redirect('/dashboard/?guest=true')
    
    # Get search query
    search_query = request.GET.get('search', '').strip()
    
    # Get all user complaints
    complaints = Complaint.objects.filter(user=request.user).select_related('assigned_department').order_by('-created_at')
    
    # Apply search filter
    if search_query:
        complaints = complaints.filter(
            Q(complaint_number__icontains=search_query) |
            Q(title__icontains=search_query) |
            Q(description__icontains=search_query) |
            Q(complaint_type__icontains=search_query) |
            Q(city__icontains=search_query) |
            Q(assigned_department__name__icontains=search_query)
        )
    
    # Calculate stats
    total_complaints = complaints.count()
    pending_complaints = complaints.filter(work_status='pending').count()
    progress_complaints = complaints.filter(work_status='process').count()
    solved_complaints = complaints.filter(work_status='solved').count()
    
    # Get recent complaints (last 5)
    recent_complaints = complaints[:5]
    
    return render(request, 'user_dashboard.html', {
        'complaints': complaints,
        'is_guest': False,
        'category_cards': category_cards,
        'total_complaints': total_complaints,
        'pending_complaints': pending_complaints,
        'progress_complaints': progress_complaints,
        'solved_complaints': solved_complaints,
        'recent_complaints': recent_complaints,
        'all_complaints': complaints,
        'search_query': search_query,
    })

def track_complaints(request):
    if not request.user.is_authenticated:
        return redirect('/dashboard/?guest=true')
    complaints = (
        Complaint.objects
        .filter(user=request.user)
        .select_related('assigned_department')
        .prefetch_related('resolution_proofs', 'reopen_proofs')
        .order_by('-created_at')
    )
    return render(request, 'track_complaints.html', {
        'complaints': complaints,
        'reopen_window_days': Complaint.REOPEN_WINDOW_DAYS,
    })

def preview_complaint(request):
    complaint_data = request.session.get('complaint_draft', {})
    
    if request.method == 'POST':
        if 'confirm' in request.POST:
            # Create complaint
            complaint = Complaint.objects.create(
                user=request.user if request.user.is_authenticated else None,
                complaint_type=complaint_data.get('complaint_type'),
                subcategory=complaint_data.get('subcategory', ''),
                priority=complaint_data.get('priority', 'normal'),
                preferred_contact_phone=complaint_data.get('contact_phone', False),
                preferred_contact_email=complaint_data.get('contact_email', False),
                preferred_contact_sms=complaint_data.get('contact_sms', False),
                title=complaint_data.get('title'),
                description=complaint_data.get('description'),
                latitude=float(complaint_data.get('latitude', 0)),
                longitude=float(complaint_data.get('longitude', 0)),
                state=complaint_data.get('state', ''),
                city=complaint_data.get('city', ''),
                pincode=complaint_data.get('pincode', ''),
                address=complaint_data.get('address', ''),
                guest_name=complaint_data.get('full_name', '') if not request.user.is_authenticated else '',
                guest_email=complaint_data.get('email', '') if not request.user.is_authenticated else '',
                guest_phone=complaint_data.get('phone', '') if not request.user.is_authenticated else ''
            )
            
            # Save media files from temp storage
            media_paths = complaint_data.get('media_paths', [])
            for path in media_paths:
                if default_storage.exists(path):
                    with default_storage.open(path) as f:
                        name = os.path.basename(path)
                        file_type = 'video' if name.lower().endswith(('.mp4', '.mov', '.avi')) else 'image'
                        ComplaintMedia.objects.create(
                            complaint=complaint,
                            file=ContentFile(f.read(), name=name),
                            file_type=file_type
                        )
                    # Delete temp file
                    default_storage.delete(path)
            
            # Save dynamic fields
            for key, value in complaint_data.items():
                if key.startswith('field_'):
                    field_id_part = key.replace('field_', '').strip()
                    if not field_id_part.isdigit():
                        continue
                    field_obj = ComplaintCategoryField.objects.filter(id=int(field_id_part), is_active=True).first()
                    if not field_obj:
                        continue
                    ComplaintFieldResponse.objects.update_or_create(
                        complaint=complaint,
                        field=field_obj,
                        defaults={'value': str(value).strip()},
                    )

            if complaint.assigned_department:
                _send_complaint_notification_email(
                    complaint,
                    event='assigned',
                    actor_name='System Auto Assignment'
                )
            
            # Generate PDF and send email in background
            from threading import Thread
            Thread(target=send_complaint_email, args=(complaint, complaint_data)).start()
            
            # Clear draft
            del request.session['complaint_draft']
            
            messages.success(request, 'Complaint submitted successfully! Confirmation email sent.')
            return redirect('user_dashboard')
        elif 'back' in request.POST:
            if complaint_data.get('is_guest'):
                return redirect('/submit-complaint/?guest=true')
            return redirect('submit_complaint')
    
    return render(request, 'preview_complaint.html', {'data': complaint_data})

def send_complaint_email(complaint, data):
    from django.core.mail import EmailMessage
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    import io
    
    # Generate PDF
    buffer = io.BytesIO()
    p = canvas.Canvas(buffer, pagesize=letter)
    p.setFont('Helvetica-Bold', 16)
    p.drawString(100, 750, 'Smart City Complaint Receipt')
    p.setFont('Helvetica', 12)
    p.drawString(100, 720, f"Complaint ID: #{complaint.id:05d}")
    p.drawString(100, 700, f"Type: {complaint.get_complaint_type_display()}")
    p.drawString(100, 680, f"Title: {complaint.title}")
    p.drawString(100, 660, f"Status: Pending")
    p.drawString(100, 640, f"Date: {complaint.created_at.strftime('%Y-%m-%d %H:%M')}")
    p.drawString(100, 600, 'Description:')
    
    # Wrap description text
    y = 580
    for line in complaint.description.split('\n'):
        p.drawString(100, y, line[:80])
        y -= 20
    
    p.showPage()
    p.save()
    buffer.seek(0)
    
    # Send email
    email = EmailMessage(
        f'Complaint Submitted - #{complaint.id:05d}',
        f'Your complaint has been submitted successfully. Please find the receipt attached.',
        'noreply@smartcity.com',
        [data.get('email')]
    )
    email.attach(f'complaint_{complaint.id}.pdf', buffer.getvalue(), 'application/pdf')
    email.send(fail_silently=True)

def submit_complaint(request):
    is_guest = request.GET.get('guest') == 'true'
    if not request.user.is_authenticated and not is_guest:
        return redirect('/dashboard/?guest=true')
    from django.conf import settings
    initial_type = request.GET.get('type', '')
    if request.method == 'POST':
        # Save complaint data to session for preview
        complaint_data = {
            'is_guest': is_guest,
            'complaint_type': request.POST.get('complaint_type'),
            'subcategory': request.POST.get('subcategory'),
            'title': request.POST.get('title'),
            'description': request.POST.get('description'),
            'state': request.POST.get('state'),
            'city': request.POST.get('city'),
            'pincode': request.POST.get('pincode'),
            'address': request.POST.get('address'),
            'latitude': request.POST.get('latitude'),
            'longitude': request.POST.get('longitude'),
            'full_name': request.POST.get('full_name'),
            'phone': request.POST.get('phone'),
            'email': request.POST.get('email'),
            'priority': request.POST.get('priority', 'normal'),
            'contact_phone': request.POST.get('contact_phone') == 'phone',
            'contact_email': request.POST.get('contact_email') == 'email',
            'contact_sms': request.POST.get('contact_sms') == 'sms',
            'anonymous': request.POST.get('anonymous') == 'on',
        }
        
        # Handle media files
        media_files = request.FILES.getlist('media')
        media_paths = []
        for f in media_files:
            # Save temporarily to session or a temp folder
            path = default_storage.save(f'temp_media/{f.name}', ContentFile(f.read()))
            media_paths.append(path)
        complaint_data['media_paths'] = media_paths
        
        # Save dynamic fields
        for key, value in request.POST.items():
            if key.startswith('field_'):
                complaint_data[key] = value
        
        request.session['complaint_draft'] = complaint_data
        return redirect('preview_complaint')
    
    # Load draft if exists
    draft = request.session.get('complaint_draft', {})

    ensure_default_categories()
    managed_category_options, managed_sub_map, managed_field_map = get_managed_category_payload()
    has_managed_categories = len(managed_category_options) > 0

    return render(request, 'submit_complaint.html', {
        'initial_type': initial_type,
        'draft': draft,
        'managed_categories': managed_category_options,
        'managed_subcategories_json': json.dumps(managed_sub_map),
        'managed_field_map_json': json.dumps(managed_field_map),
        'has_managed_categories': has_managed_categories,
        'fallback_complaint_types': Complaint.COMPLAINT_TYPES,
    })

@login_required
def department_dashboard(request):
    try:
        department = Department.objects.get(user=request.user)
        complaints = Complaint.objects.filter(
            complaint_type=department.department_type
        ).order_by('-created_at')
        return render(request, 'department_dashboard.html', {
            'complaints': complaints,
            'department': department
        })
    except Department.DoesNotExist:
        return redirect('user_dashboard')

@login_required
def approve_complaint(request, complaint_id):
    complaint = get_object_or_404(Complaint, id=complaint_id)
    
    try:
        department = Department.objects.get(user=request.user)
        if complaint.complaint_type == department.department_type:
            complaint.status = 'approved'
            complaint.save()
            messages.success(request, 'Complaint approved!')
    except Department.DoesNotExist:
        messages.error(request, 'Access denied!')
    
    return redirect('department_dashboard')

@login_required
def reject_complaint(request, complaint_id):
    complaint = get_object_or_404(Complaint, id=complaint_id)
    
    try:
        department = Department.objects.get(user=request.user)
        if complaint.complaint_type == department.department_type:
            complaint.status = 'rejected'
            complaint.save()
            messages.success(request, 'Complaint rejected!')
    except Department.DoesNotExist:
        messages.error(request, 'Access denied!')
    
    return redirect('department_dashboard')

@login_required
def view_complaint_location(request, complaint_id):
    complaint = get_object_or_404(Complaint, id=complaint_id)
    return render(request, 'view_complaint_map.html', {
        'complaint': complaint,
    })

def guest_complaint(request):
    if request.method == 'POST':
        complaint_data = {
            'complaint_type': request.POST.get('complaint_type'),
            'subcategory': request.POST.get('subcategory', ''),
            'priority': request.POST.get('priority', 'normal'),
            'preferred_contact_phone': request.POST.get('contact_phone') == 'phone',
            'preferred_contact_email': request.POST.get('contact_email') == 'email',
            'preferred_contact_sms': request.POST.get('contact_sms') == 'sms',
            'title': request.POST.get('title'),
            'description': request.POST.get('description'),
            'state': request.POST.get('state'),
            'city': request.POST.get('city'),
            'pincode': request.POST.get('pincode'),
            'address': request.POST.get('address'),
            'latitude': float(request.POST.get('latitude', 0)),
            'longitude': float(request.POST.get('longitude', 0)),
            'guest_name': request.POST.get('full_name'),
            'guest_phone': request.POST.get('phone'),
            'guest_email': request.POST.get('email'),
        }
        
        complaint = Complaint.objects.create(**complaint_data)

        if complaint.assigned_department:
            _send_complaint_notification_email(
                complaint,
                event='assigned',
                actor_name='System Auto Assignment'
            )
        
        return render(request, 'guest_success.html', {
            'complaint_number': complaint.complaint_number,
            'phone': complaint.guest_phone
        })
    
    # Check if coming from citizen portal
    if request.GET.get('from') == 'citizen':
        return redirect('/dashboard/?guest=true')
    
    return render(request, 'guest_complaint.html')

def track_guest_complaint(request):
    complaint = None
    if request.method == 'POST':
        complaint_number = request.POST.get('complaint_number', '').strip()
        phone = request.POST.get('phone', '').strip()
        
        if not complaint_number or not phone:
            messages.error(request, 'Please enter both complaint ID and mobile number!')
            return render(request, 'track_guest.html', {'complaint': None})
        
        # Try guest complaint first
        try:
            complaint = Complaint.objects.select_related('assigned_department').prefetch_related('resolution_proofs', 'reopen_proofs').get(
                complaint_number=complaint_number,
                guest_phone=phone
            )
        except Complaint.DoesNotExist:
            pass
        
        # If not found, try registered user complaint
        if not complaint:
            try:
                possible_complaints = Complaint.objects.filter(
                    complaint_number=complaint_number,
                    user__isnull=False
                ).select_related('assigned_department', 'user__citizenprofile').prefetch_related('resolution_proofs', 'reopen_proofs')
                
                for comp in possible_complaints:
                    if comp.user and hasattr(comp.user, 'citizenprofile'):
                        if comp.user.citizenprofile.mobile_no == phone:
                            complaint = comp
                            break
            except Exception:
                pass
        
        if not complaint:
            messages.error(request, 'Invalid complaint ID or mobile number. Please check and try again!')
    
    return render(request, 'track_guest.html', {'complaint': complaint})

@login_required
def add_city_admin(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
        
    if request.method == 'POST':
        full_name = request.POST.get('full_name', '').strip()
        email = request.POST.get('email', '').strip().lower()
        password = request.POST.get('password', '').strip()
        contact_address = request.POST.get('contact_address', '').strip()
        pincode = _normalize_pincode(request.POST.get('pincode', ''))

        if not all([full_name, email, contact_address, pincode]):
            messages.error(request, 'Please fill all city admin fields.')
            return redirect('super_admin_city_admins')

        if len(pincode) != 6:
            messages.error(request, 'Please enter a valid 6-digit pincode.')
            return redirect('super_admin_city_admins')

        location = lookup_indian_pincode(pincode)
        if not location:
            messages.error(request, 'Could not detect state/city from pincode. Check and try again.')
            return redirect('super_admin_city_admins')
        state = location['state']
        city = location['city']

        if not password:
            password = generate_strong_password()
        elif not _is_strong_password(password):
            messages.error(request, 'Use a strong password with uppercase, lowercase, number and symbol.')
            return redirect('super_admin_city_admins')
        
        existing_user_conflict = User.objects.filter(
            Q(email__iexact=email) | Q(username__iexact=email)
        ).exists()
        if existing_user_conflict:
            messages.error(request, 'A user with this email/username already exists!')
            return redirect('super_admin_city_admins')

        managed_state = ManagedState.objects.filter(name__iexact=state).first()
        if not managed_state:
            messages.error(request, f'Auto-detected state "{state}" is not added yet. Add state first.')
            return redirect('super_admin_city_admins')

        managed_city = ManagedCity.objects.filter(name__iexact=city, state_id=managed_state.id).first()
        if not managed_city:
            messages.error(request, f'Auto-detected city "{city}" is not added under state "{state}". Add city first.')
            return redirect('super_admin_city_admins')
            
        # Create User + CityAdmin atomically so uniqueness races fail gracefully.
        first_name = full_name.split(' ')[0]
        last_name = ' '.join(full_name.split(' ')[1:]) if ' ' in full_name else ''
        try:
            with transaction.atomic():
                user = User.objects.create_user(
                    username=email,
                    email=email,
                    password=password,
                    first_name=first_name,
                    last_name=last_name
                )

                CityAdmin.objects.create(
                    user=user,
                    city_name=city,
                    state=state,
                    pincode=pincode,
                    contact_address=contact_address
                )
        except IntegrityError:
            messages.error(request, 'A user with this email/username already exists!')
            return redirect('super_admin_city_admins')

        send_city_admin_credentials_email(
            email=email,
            full_name=full_name,
            state=state,
            city=city,
            login_password=password,
            pincode=pincode,
            contact_address=contact_address
        )
        
        messages.success(request, f'City Admin account created for {full_name} ({city}, {state}). Credentials sent to email.')
        
    return redirect('super_admin_city_admins')


@login_required
def super_admin_edit_city_admin(request, city_admin_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    city_admin = get_object_or_404(CityAdmin.objects.select_related('user'), id=city_admin_id)
    user_obj = city_admin.user
    state_options = build_state_options()
    managed_cities = ManagedCity.objects.select_related('state').order_by('name')

    if request.method == 'POST':
        full_name = request.POST.get('full_name', '').strip()
        email = request.POST.get('email', '').strip().lower()
        password = request.POST.get('password', '').strip()
        contact_address = request.POST.get('contact_address', '').strip()
        pincode = _normalize_pincode(request.POST.get('pincode', ''))
        is_active = request.POST.get('is_active') == 'on'

        if not all([full_name, email, contact_address, pincode]):
            messages.error(request, 'Please fill all required city admin fields.')
            return redirect('super_admin_edit_city_admin', city_admin_id=city_admin.id)

        if len(pincode) != 6:
            messages.error(request, 'Please enter a valid 6-digit pincode.')
            return redirect('super_admin_edit_city_admin', city_admin_id=city_admin.id)

        location = lookup_indian_pincode(pincode)
        if not location:
            messages.error(request, 'Could not detect state/city from pincode. Check and try again.')
            return redirect('super_admin_edit_city_admin', city_admin_id=city_admin.id)
        state = location['state']
        city = location['city']

        user_conflict = User.objects.exclude(id=user_obj.id).filter(
            Q(email__iexact=email) | Q(username__iexact=email)
        ).exists()
        if user_conflict:
            messages.error(request, 'A user with this email/username already exists.')
            return redirect('super_admin_edit_city_admin', city_admin_id=city_admin.id)

        managed_state = ManagedState.objects.filter(name__iexact=state).first()
        if not managed_state:
            messages.error(request, f'Auto-detected state "{state}" is not added yet. Add state first.')
            return redirect('super_admin_edit_city_admin', city_admin_id=city_admin.id)

        city_in_state_exists = ManagedCity.objects.filter(name__iexact=city, state_id=managed_state.id).exists()
        if not city_in_state_exists:
            messages.error(request, f'Auto-detected city "{city}" is not added under state "{state}". Add city first.')
            return redirect('super_admin_edit_city_admin', city_admin_id=city_admin.id)

        first_name = full_name.split(' ')[0]
        last_name = ' '.join(full_name.split(' ')[1:]) if ' ' in full_name else ''

        try:
            with transaction.atomic():
                user_obj.first_name = first_name
                user_obj.last_name = last_name
                user_obj.email = email
                user_obj.username = email
                if password:
                    user_obj.set_password(password)
                user_obj.save()

                city_admin.state = state
                city_admin.city_name = city
                city_admin.pincode = pincode
                city_admin.contact_address = contact_address
                city_admin.is_active = is_active
                city_admin.save(update_fields=['state', 'city_name', 'pincode', 'contact_address', 'is_active'])
        except IntegrityError:
            messages.error(request, 'A user with this email/username already exists.')
            return redirect('super_admin_edit_city_admin', city_admin_id=city_admin.id)

        messages.success(request, f'City Admin {full_name} updated successfully.')
        return redirect('super_admin_city_admins')

    context = {
        'page_title': 'Edit City Admin',
        'city_admin_obj': city_admin,
        'state_options': state_options,
        'managed_cities': managed_cities,
    }
    return render(request, 'super_admin_edit_city_admin.html', context)


@login_required
def super_admin_delete_city_admin(request, city_admin_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    city_admin = get_object_or_404(CityAdmin.objects.select_related('user'), id=city_admin_id)
    if request.method != 'POST':
        return redirect('super_admin_city_admins')

    if Department.objects.filter(city_admin=city_admin).exists():
        messages.error(
            request,
            f'Cannot delete {city_admin.user.get_full_name() or city_admin.user.username}. Reassign or delete linked departments first.'
        )
        return redirect('super_admin_city_admins')

    admin_name = city_admin.user.get_full_name() or city_admin.user.username
    city_admin.user.delete()
    messages.success(request, f'City Admin {admin_name} deleted successfully.')
    return redirect('super_admin_city_admins')


@login_required
def super_admin_add_state(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    if request.method == 'POST':
        state_name = request.POST.get('state_name', '').strip()
        state_code = request.POST.get('state_code', '').strip().upper()

        if not state_name or not state_code:
            messages.error(request, 'State code and state name are required.')
            return redirect('super_admin_add_state')

        if ManagedState.objects.filter(code__iexact=state_code).exists():
            messages.error(request, 'State code already exists.')
            return redirect('super_admin_add_state')

        if ManagedState.objects.filter(name__iexact=state_name).exists():
            messages.error(request, 'State name already exists.')
            return redirect('super_admin_add_state')

        ManagedState.objects.create(code=state_code, name=state_name)
        messages.success(request, f'State {state_name} ({state_code}) added successfully.')
        return redirect('super_admin_add_state')

    context = {
        'page_title': 'Add State',
        'states': ManagedState.objects.order_by('name'),
    }
    return render(request, 'super_admin_add_state.html', context)


@login_required
def super_admin_edit_state(request, state_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    state = get_object_or_404(ManagedState, id=state_id)

    if request.method == 'POST':
        state_name = request.POST.get('state_name', '').strip()
        state_code = request.POST.get('state_code', '').strip().upper()

        if not state_name or not state_code:
            messages.error(request, 'State code and state name are required.')
            return redirect('super_admin_edit_state', state_id=state.id)

        if ManagedState.objects.exclude(id=state.id).filter(code__iexact=state_code).exists():
            messages.error(request, 'State code already exists.')
            return redirect('super_admin_edit_state', state_id=state.id)

        if ManagedState.objects.exclude(id=state.id).filter(name__iexact=state_name).exists():
            messages.error(request, 'State name already exists.')
            return redirect('super_admin_edit_state', state_id=state.id)

        state.code = state_code
        state.name = state_name
        state.save(update_fields=['code', 'name'])
        messages.success(request, f'State {state.name} updated successfully.')
        return redirect('super_admin_add_state')

    context = {
        'page_title': 'Edit State',
        'state_obj': state,
    }
    return render(request, 'super_admin_edit_state.html', context)


@login_required
def super_admin_delete_state(request, state_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    state = get_object_or_404(ManagedState, id=state_id)
    if request.method != 'POST':
        return redirect('super_admin_add_state')

    if state.cities.exists():
        messages.error(request, f'Cannot delete {state.name}. Delete its cities first.')
        return redirect('super_admin_add_state')

    state_name = state.name
    state.delete()
    messages.success(request, f'State {state_name} deleted successfully.')
    return redirect('super_admin_add_state')


@login_required
def super_admin_add_city(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    states = ManagedState.objects.order_by('name')
    if request.method == 'POST':
        state_id = request.POST.get('state_id', '').strip()
        city_name = request.POST.get('city_name', '').strip()
        city_code = request.POST.get('city_code', '').strip().upper()

        if not state_id or not city_name or not city_code:
            messages.error(request, 'State, city code and city name are required.')
            return redirect('super_admin_add_city')

        try:
            state = ManagedState.objects.get(id=state_id)
        except ManagedState.DoesNotExist:
            messages.error(request, 'Please select a valid state.')
            return redirect('super_admin_add_city')

        if ManagedCity.objects.filter(code__iexact=city_code).exists():
            messages.error(request, 'City code already exists.')
            return redirect('super_admin_add_city')

        if ManagedCity.objects.filter(state=state, name__iexact=city_name).exists():
            messages.error(request, f'{city_name} already exists in {state.name}.')
            return redirect('super_admin_add_city')

        ManagedCity.objects.create(state=state, code=city_code, name=city_name)
        messages.success(request, f'City {city_name} ({city_code}) added under {state.name}.')
        return redirect('super_admin_add_city')

    context = {
        'page_title': 'Add City',
        'states': states,
        'cities': ManagedCity.objects.select_related('state').order_by('name'),
    }
    return render(request, 'super_admin_add_city.html', context)


@login_required
def super_admin_edit_city(request, city_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    city = get_object_or_404(ManagedCity.objects.select_related('state'), id=city_id)
    states = ManagedState.objects.order_by('name')

    if request.method == 'POST':
        state_id = request.POST.get('state_id', '').strip()
        city_name = request.POST.get('city_name', '').strip()
        city_code = request.POST.get('city_code', '').strip().upper()

        if not state_id or not city_name or not city_code:
            messages.error(request, 'State, city code and city name are required.')
            return redirect('super_admin_edit_city', city_id=city.id)

        try:
            state = ManagedState.objects.get(id=state_id)
        except ManagedState.DoesNotExist:
            messages.error(request, 'Please select a valid state.')
            return redirect('super_admin_edit_city', city_id=city.id)

        if ManagedCity.objects.exclude(id=city.id).filter(code__iexact=city_code).exists():
            messages.error(request, 'City code already exists.')
            return redirect('super_admin_edit_city', city_id=city.id)

        if ManagedCity.objects.exclude(id=city.id).filter(state=state, name__iexact=city_name).exists():
            messages.error(request, f'{city_name} already exists in {state.name}.')
            return redirect('super_admin_edit_city', city_id=city.id)

        city.state = state
        city.code = city_code
        city.name = city_name
        city.save(update_fields=['state', 'code', 'name'])
        messages.success(request, f'City {city.name} updated successfully.')
        return redirect('super_admin_add_city')

    context = {
        'page_title': 'Edit City',
        'city_obj': city,
        'states': states,
    }
    return render(request, 'super_admin_edit_city.html', context)


@login_required
def super_admin_delete_city(request, city_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    city = get_object_or_404(ManagedCity.objects.select_related('state'), id=city_id)
    if request.method != 'POST':
        return redirect('super_admin_add_city')

    city_name = city.name
    state_name = city.state.name
    city.delete()
    messages.success(request, f'City {city_name} deleted from {state_name}.')
    return redirect('super_admin_add_city')

def super_admin_dashboard(request):
    if not request.user.is_superuser:
        # Check if user is city admin
        try:
            city_admin = CityAdmin.objects.get(user=request.user)
            return city_admin_dashboard(request, city_admin)
        except CityAdmin.DoesNotExist:
            return redirect('user_dashboard')
    
    # Main super admin dashboard
    total_complaints = Complaint.objects.count()
    pending_complaints = Complaint.objects.filter(work_status='pending').count()
    resolved_complaints = Complaint.objects.filter(work_status='solved').count()
    total_departments = Department.objects.count()
    total_city_admins = CityAdmin.objects.count()
    
    recent_complaints = Complaint.objects.order_by('-created_at')[:10]
    city_admins = CityAdmin.objects.all()
    
    context = {
        'total_complaints': total_complaints,
        'pending_complaints': pending_complaints,
        'resolved_complaints': resolved_complaints,
        'total_departments': total_departments,
        'total_city_admins': total_city_admins,
        'recent_complaints': recent_complaints,
        'city_admins': city_admins,
        'is_main_admin': True,
    }
    
    return render(request, 'super_admin_dashboard.html', context)

@login_required
def super_admin_problems(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    base_complaints = Complaint.objects.exclude(work_status='solved')
    
    # Filter values
    category_filter = request.GET.get('category', '').strip()
    state_filter = request.GET.get('state', '').strip()
    city_filter = request.GET.get('city', '').strip()

    # Dropdown options
    state_options = (
        base_complaints
        .exclude(state__isnull=True)
        .exclude(state__exact='')
        .values_list('state', flat=True)
        .distinct()
        .order_by('state')
    )

    city_source = base_complaints
    if state_filter:
        city_source = city_source.filter(state=state_filter)

    city_options = (
        city_source
        .exclude(city__isnull=True)
        .exclude(city__exact='')
        .values_list('city', flat=True)
        .distinct()
        .order_by('city')
    )

    complaints = base_complaints
    if category_filter:
        complaints = complaints.filter(complaint_type=category_filter)
    if state_filter:
        complaints = complaints.filter(state=state_filter)
    if city_filter:
        complaints = complaints.filter(city=city_filter)
    complaints = complaints.order_by('-created_at')
        
    context = {
        'complaints': complaints,
        'category_filter': category_filter,
        'state_filter': state_filter,
        'city_filter': city_filter,
        'state_options': state_options,
        'city_options': city_options,
        'page_title': 'All Problems',
        'complaint_types': get_active_category_choices(),
    }
    return render(request, 'super_admin_problems.html', context)

@login_required
def super_admin_solved(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    base_complaints = Complaint.objects.filter(work_status='solved')
    
    # Filter values
    category_filter = request.GET.get('category', '').strip()
    state_filter = request.GET.get('state', '').strip()
    city_filter = request.GET.get('city', '').strip()

    # Dropdown options
    state_options = (
        base_complaints
        .exclude(state__isnull=True)
        .exclude(state__exact='')
        .values_list('state', flat=True)
        .distinct()
        .order_by('state')
    )

    city_source = base_complaints
    if state_filter:
        city_source = city_source.filter(state=state_filter)

    city_options = (
        city_source
        .exclude(city__isnull=True)
        .exclude(city__exact='')
        .values_list('city', flat=True)
        .distinct()
        .order_by('city')
    )

    complaints = base_complaints
    if category_filter:
        complaints = complaints.filter(complaint_type=category_filter)
    if state_filter:
        complaints = complaints.filter(state=state_filter)
    if city_filter:
        complaints = complaints.filter(city=city_filter)
    complaints = complaints.order_by('-resolved_at')
    
    context = {
        'complaints': complaints,
        'category_filter': category_filter,
        'state_filter': state_filter,
        'city_filter': city_filter,
        'state_options': state_options,
        'city_options': city_options,
        'page_title': 'Solved Problems',
        'complaint_types': get_active_category_choices(),
    }
    return render(request, 'super_admin_solved.html', context)


@login_required
def super_admin_review(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    base_complaints = Complaint.objects.all()

    category_filter = request.GET.get('category', '').strip()
    state_filter = request.GET.get('state', '').strip()
    city_filter = request.GET.get('city', '').strip()

    state_options = (
        base_complaints
        .exclude(state__isnull=True)
        .exclude(state__exact='')
        .values_list('state', flat=True)
        .distinct()
        .order_by('state')
    )

    city_source = base_complaints
    if state_filter:
        city_source = city_source.filter(state=state_filter)

    city_options = (
        city_source
        .exclude(city__isnull=True)
        .exclude(city__exact='')
        .values_list('city', flat=True)
        .distinct()
        .order_by('city')
    )

    filtered_complaints = base_complaints
    if category_filter:
        filtered_complaints = filtered_complaints.filter(complaint_type=category_filter)
    if state_filter:
        filtered_complaints = filtered_complaints.filter(state=state_filter)
    if city_filter:
        filtered_complaints = filtered_complaints.filter(city=city_filter)

    solved_complaints = (
        filtered_complaints
        .filter(work_status='solved')
        .select_related('assigned_department')
        .prefetch_related('resolution_proofs')
        .order_by('-resolved_at', '-updated_at')
    )

    total_count = filtered_complaints.count()
    solved_count = solved_complaints.count()
    solve_ratio = round((solved_count / total_count) * 100, 2) if total_count else 0

    rated_complaints = solved_complaints.exclude(citizen_rating__isnull=True)
    rated_count = rated_complaints.count()
    avg_rating = rated_complaints.aggregate(avg=Avg('citizen_rating')).get('avg') or 0
    avg_rating = round(float(avg_rating), 2) if avg_rating else 0
    positive_feedback_count = rated_complaints.filter(citizen_rating__gte=4).count()
    positive_ratio = round((positive_feedback_count / rated_count) * 100, 2) if rated_count else 0
    rating_coverage = round((rated_count / solved_count) * 100, 2) if solved_count else 0

    complaint_types = list(get_active_category_choices())
    category_rows = []
    for category_key, category_label in complaint_types:
        category_all = filtered_complaints.filter(complaint_type=category_key)
        category_total = category_all.count()
        category_solved_qs = category_all.filter(work_status='solved')
        category_solved_count = category_solved_qs.count()
        category_rated_qs = category_solved_qs.exclude(citizen_rating__isnull=True)
        category_rated_count = category_rated_qs.count()
        category_avg_rating = category_rated_qs.aggregate(avg=Avg('citizen_rating')).get('avg') or 0
        category_avg_rating = round(float(category_avg_rating), 2) if category_avg_rating else 0
        category_positive_count = category_rated_qs.filter(citizen_rating__gte=4).count()
        category_positive_ratio = round((category_positive_count / category_rated_count) * 100, 2) if category_rated_count else 0
        category_solve_ratio = round((category_solved_count / category_total) * 100, 2) if category_total else 0

        if category_total == 0 and category_key != category_filter:
            continue

        category_rows.append({
            'key': category_key,
            'label': category_label,
            'total': category_total,
            'solved': category_solved_count,
            'solve_ratio': category_solve_ratio,
            'rated': category_rated_count,
            'avg_rating': category_avg_rating,
            'positive_count': category_positive_count,
            'positive_ratio': category_positive_ratio,
        })

    category_rows.sort(key=lambda row: (-row['solved'], -row['avg_rating'], row['label'].lower()))

    context = {
        'page_title': 'Review Analytics',
        'complaints': solved_complaints,
        'category_rows': category_rows,
        'complaint_types': complaint_types,
        'category_filter': category_filter,
        'state_filter': state_filter,
        'city_filter': city_filter,
        'state_options': state_options,
        'city_options': city_options,
        'total_count': total_count,
        'solved_count': solved_count,
        'solve_ratio': solve_ratio,
        'rated_count': rated_count,
        'avg_rating': avg_rating,
        'positive_feedback_count': positive_feedback_count,
        'positive_ratio': positive_ratio,
        'rating_coverage': rating_coverage,
    }
    return render(request, 'super_admin_review.html', context)


def _generate_unique_department_code():
    """Generate a unique 4-8 digit department code."""
    while True:
        length = random.randint(4, 8)
        code = ''.join(random.choices('0123456789', k=length))
        if not Department.objects.filter(unique_id=code).exists():
            return code

@login_required
def super_admin_departments(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    # Hide legacy dummy departments created with default placeholder values
    base_departments = (
        Department.objects
        .exclude(name='Default Department')
        .select_related('city_admin', 'city_admin__user')
        .order_by('name')
    )

    state_filter = request.GET.get('state', '').strip()
    city_filter = request.GET.get('city', '').strip()
    department_filter = request.GET.get('department', '').strip()

    state_options = build_state_options()
    city_options = [item['city_name'] for item in build_city_options(state_filter)]

    departments = base_departments
    if state_filter:
        departments = departments.filter(models.Q(city_admin__state=state_filter) | models.Q(state=state_filter))
    if city_filter:
        departments = departments.filter(models.Q(city_admin__city_name=city_filter) | models.Q(city=city_filter))
    if department_filter:
        departments = departments.filter(department_type=department_filter)

    department_list = list(departments)
    total_departments = len(department_list)
    active_departments = sum(1 for department in department_list if department.is_active)
    inactive_departments = total_departments - active_departments

    overall_pending_cases = 0
    overall_resolution_hours = []
    overall_rating_values = []
    overall_sla_breaches = 0
    overall_sla_solved_cases = 0

    department_ids = [department.id for department in department_list]
    complaints_by_department = {}
    if department_ids:
        related_complaints = Complaint.objects.filter(assigned_department_id__in=department_ids).only(
            'id',
            'assigned_department_id',
            'work_status',
            'created_at',
            'resolved_at',
            'citizen_rating',
        )
        for complaint in related_complaints:
            complaints_by_department.setdefault(complaint.assigned_department_id, []).append(complaint)

    for department in department_list:
        department_complaints = complaints_by_department.get(department.id, [])
        pending_count = sum(
            1 for complaint in department_complaints
            if complaint.work_status in {'pending', 'confirmed', 'process', 'reopened'}
        )
        solved_cases = [
            complaint for complaint in department_complaints
            if complaint.work_status == 'solved' and complaint.resolved_at
        ]
        rating_values = [
            float(complaint.citizen_rating) for complaint in solved_cases
            if complaint.citizen_rating is not None
        ]

        resolution_hours = []
        for complaint in solved_cases:
            if not complaint.created_at:
                continue
            elapsed_hours = (complaint.resolved_at - complaint.created_at).total_seconds() / 3600
            resolution_hours.append(max(elapsed_hours, 0.0))

        sla_hours = max(int(department.sla_hours or 72), 1)
        sla_breaches = sum(1 for value in resolution_hours if value > sla_hours)
        sla_breach_pct = round((sla_breaches / len(resolution_hours)) * 100, 2) if resolution_hours else 0

        department.pending_count = pending_count
        department.avg_resolution_hours = round(sum(resolution_hours) / len(resolution_hours), 2) if resolution_hours else 0
        department.avg_citizen_rating = round(sum(rating_values) / len(rating_values), 2) if rating_values else 0
        department.sla_breach_pct = sla_breach_pct
        department.total_assigned_cases = len(department_complaints)

        overall_pending_cases += pending_count
        overall_resolution_hours.extend(resolution_hours)
        overall_rating_values.extend(rating_values)
        overall_sla_breaches += sla_breaches
        overall_sla_solved_cases += len(resolution_hours)

    overall_avg_resolution_hours = (
        round(sum(overall_resolution_hours) / len(overall_resolution_hours), 2)
        if overall_resolution_hours else 0
    )
    overall_avg_rating = (
        round(sum(overall_rating_values) / len(overall_rating_values), 2)
        if overall_rating_values else 0
    )
    overall_sla_breach_pct = (
        round((overall_sla_breaches / overall_sla_solved_cases) * 100, 2)
        if overall_sla_solved_cases else 0
    )
    
    context = {
        'departments': department_list,
        'total_departments': total_departments,
        'active_departments': active_departments,
        'inactive_departments': inactive_departments,
        'overall_pending_cases': overall_pending_cases,
        'overall_avg_resolution_hours': overall_avg_resolution_hours,
        'overall_avg_rating': overall_avg_rating,
        'overall_sla_breach_pct': overall_sla_breach_pct,
        'state_options': state_options,
        'city_options': city_options,
        'department_types': Department.DEPARTMENT_TYPES,
        'state_filter': state_filter,
        'city_filter': city_filter,
        'department_filter': department_filter,
        'page_title': 'All Departments',
    }
    return render(request, 'super_admin_departments.html', context)


@login_required
def super_admin_add_department(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    city_admins = CityAdmin.objects.filter(is_active=True).select_related('user').order_by('city_name', 'user__first_name')
    state_options = build_state_options()
    city_options = build_city_options()
    valid_department_types = {value for value, _label in Department.DEPARTMENT_TYPES}

    def _normalize_form_data(raw_data):
        return {
            'name': str(raw_data.get('name', '')).strip(),
            'department_type': str(raw_data.get('department_type', '')).strip(),
            'state_name': str(raw_data.get('state_name', '')).strip(),
            'city_name': str(raw_data.get('city_name', '')).strip(),
            'city_admin': str(raw_data.get('city_admin', '')).strip(),
            'unique_id': str(raw_data.get('unique_id', '')).strip(),
            'location_name': str(raw_data.get('location_name', '')).strip(),
            'email': str(raw_data.get('email', '')).strip(),
            'phone': str(raw_data.get('phone', '')).strip(),
            'address': str(raw_data.get('address', '')).strip(),
            'sla_hours': str(raw_data.get('sla_hours', '72')).strip() or '72',
            'latitude': str(raw_data.get('latitude', '')).strip() or '20.5937',
            'longitude': str(raw_data.get('longitude', '')).strip() or '78.9629',
            'department_password': str(raw_data.get('department_password', '')).strip(),
            'department_logo_temp_path': str(raw_data.get('department_logo_temp_path', '')).strip(),
            'is_active': bool(raw_data.get('is_active', True)),
        }

    def _validate_department_form(form_data):
        if not form_data['name']:
            return None, None, 'Department name is required.'
        if not form_data['department_type']:
            return None, None, 'Department category is required.'
        if form_data['department_type'] not in valid_department_types:
            return None, None, 'Please select a valid department category.'
        if not form_data['city_name']:
            return None, None, 'Please select a city.'
        if not form_data['city_admin']:
            return None, None, 'Please select a city admin.'
        if not form_data['email']:
            return None, None, 'Department email is required.'
        if not form_data['phone']:
            return None, None, 'Department phone number is required.'
        if not form_data['address']:
            return None, None, 'Department address is required.'
        if not form_data['department_password']:
            return None, None, 'Department password is required.'

        if not form_data['unique_id'].isdigit() or not (4 <= len(form_data['unique_id']) <= 8):
            form_data['unique_id'] = _generate_unique_department_code()
        if Department.objects.filter(unique_id=form_data['unique_id']).exists():
            form_data['unique_id'] = _generate_unique_department_code()

        try:
            city_admin = CityAdmin.objects.get(id=form_data['city_admin'], is_active=True)
        except CityAdmin.DoesNotExist:
            return None, None, 'Please select a valid city admin.'

        if city_admin.city_name.lower() != form_data['city_name'].lower():
            return None, None, 'Selected city admin does not belong to the selected city.'

        if form_data['state_name'] and city_admin.state.lower() != form_data['state_name'].lower():
            return None, None, 'Selected city admin does not belong to the selected state.'

        try:
            validate_email(form_data['email'])
        except ValidationError:
            return None, None, 'Please enter a valid department email address.'

        if not re.fullmatch(r'^\+?\d{10,15}$', form_data['phone']):
            return None, None, 'Please enter a valid phone number (10 to 15 digits).'

        if not _is_strong_password(form_data['department_password']):
            return None, None, 'Use a strong password with at least 10 characters including uppercase, lowercase, number, and symbol.'

        try:
            latitude_val = float(form_data['latitude'])
            longitude_val = float(form_data['longitude'])
        except ValueError:
            return None, None, 'Invalid map coordinates.'

        try:
            sla_hours_val = int(form_data['sla_hours'])
        except (TypeError, ValueError):
            return None, None, 'SLA hours must be a valid number.'
        if sla_hours_val < 1 or sla_hours_val > 720:
            return None, None, 'SLA hours must be between 1 and 720.'

        cleaned_data = {
            **form_data,
            'state_name': form_data['state_name'] or city_admin.state,
            'city_name': form_data['city_name'] or city_admin.city_name,
            'sla_hours': sla_hours_val,
            'latitude': latitude_val,
            'longitude': longitude_val,
            'location_name': form_data['location_name'] or form_data['city_name'] or city_admin.city_name,
        }
        return cleaned_data, city_admin, None

    pending_form_data = request.session.get('pending_department_data', {})
    otp_pending = bool(pending_form_data)
    form_data = _normalize_form_data(pending_form_data)
    if not form_data['unique_id']:
        form_data['unique_id'] = _generate_unique_department_code()
    if not form_data['department_password']:
        form_data['department_password'] = generate_strong_password()

    if request.method == 'POST':
        action = request.POST.get('action', 'send_otp').strip()

        if action == 'verify_create':
            otp_input = request.POST.get('otp_code', '').strip()
            pending = request.session.get('pending_department_data')
            if not pending:
                messages.error(request, 'No pending department data found. Please submit the form again.')
                return redirect('super_admin_add_department')
            if not otp_input:
                messages.error(request, 'OTP is required for verification.')
                return redirect('super_admin_add_department')

            uploaded_logo = request.FILES.get('department_logo')
            pending_logo_path = str(pending.get('department_logo_temp_path', '')).strip()
            if uploaded_logo:
                if pending_logo_path and default_storage.exists(pending_logo_path):
                    default_storage.delete(pending_logo_path)
                pending_logo_path = save_temp_department_logo(uploaded_logo)

            submitted_form_data = _normalize_form_data({
                'name': request.POST.get('name', pending.get('name', '')),
                'department_type': request.POST.get('department_type', pending.get('department_type', '')),
                'state_name': request.POST.get('state_name', pending.get('state_name', '')),
                'city_name': request.POST.get('city_name', pending.get('city_name', '')),
                'city_admin': request.POST.get('city_admin', pending.get('city_admin', '')),
                'unique_id': request.POST.get('unique_id', pending.get('unique_id', '')),
                'location_name': request.POST.get('location_name', pending.get('location_name', '')),
                'email': request.POST.get('email', pending.get('email', '')),
                'phone': request.POST.get('phone', pending.get('phone', '')),
                'address': request.POST.get('address', pending.get('address', '')),
                'sla_hours': request.POST.get('sla_hours', pending.get('sla_hours', '72')),
                'latitude': request.POST.get('latitude', pending.get('latitude', '')),
                'longitude': request.POST.get('longitude', pending.get('longitude', '')),
                'department_password': request.POST.get('department_password', pending.get('department_password', '')),
                'department_logo_temp_path': pending_logo_path,
                'is_active': request.POST.get('is_active') == 'on',
            })
            if submitted_form_data['email'].lower() != str(pending.get('email', '')).strip().lower():
                messages.error(request, 'Department email changed after OTP send. Please click resend OTP.')
                form_data = submitted_form_data
                return render(request, 'super_admin_add_department.html', {
                    'page_title': 'Add Department',
                    'city_admins': city_admins,
                    'state_options': state_options,
                    'city_options': city_options,
                    'department_types': Department.DEPARTMENT_TYPES,
                    'generated_code': submitted_form_data['unique_id'] or _generate_unique_department_code(),
                    'generated_password': submitted_form_data['department_password'] or generate_strong_password(),
                    'form_data': submitted_form_data,
                    'otp_pending': True,
                })

            form_data = submitted_form_data
            cleaned_data, city_admin, validation_error = _validate_department_form(form_data)
            if validation_error:
                messages.error(request, validation_error)
                return render(request, 'super_admin_add_department.html', {
                    'page_title': 'Add Department',
                    'city_admins': city_admins,
                    'state_options': state_options,
                    'city_options': city_options,
                    'department_types': Department.DEPARTMENT_TYPES,
                    'generated_code': form_data['unique_id'] or _generate_unique_department_code(),
                    'generated_password': form_data['department_password'] or generate_strong_password(),
                    'form_data': form_data,
                    'otp_pending': True,
                })

            request.session['pending_department_data'] = {
                'name': cleaned_data['name'],
                'department_type': cleaned_data['department_type'],
                'state_name': cleaned_data['state_name'],
                'city_name': cleaned_data['city_name'],
                'city_admin': cleaned_data['city_admin'],
                'unique_id': cleaned_data['unique_id'],
                'location_name': cleaned_data['location_name'],
                'email': cleaned_data['email'],
                'phone': cleaned_data['phone'],
                'address': cleaned_data['address'],
                'sla_hours': cleaned_data['sla_hours'],
                'latitude': str(cleaned_data['latitude']),
                'longitude': str(cleaned_data['longitude']),
                'department_password': cleaned_data['department_password'],
                'department_logo_temp_path': cleaned_data.get('department_logo_temp_path', ''),
                'is_active': cleaned_data['is_active'],
            }

            otp_obj = OTP.objects.filter(
                email=cleaned_data['email'],
                is_verified=False
            ).order_by('-created_at').first()

            if not otp_obj or otp_obj.otp != otp_input:
                messages.error(request, 'Invalid OTP. Please enter the correct OTP.')
                return redirect('super_admin_add_department')

            if timezone.now() - otp_obj.created_at > timedelta(minutes=10):
                otp_obj.delete()
                messages.error(request, 'OTP expired. Please resend OTP and try again.')
                return redirect('super_admin_add_department')

            if User.objects.filter(email__iexact=cleaned_data['email']).exists():
                messages.error(request, 'This department email is already used by another account.')
                return redirect('super_admin_add_department')

            username = f"dept_{cleaned_data['unique_id']}_{random.randint(100, 999)}"
            while User.objects.filter(username=username).exists():
                username = f"dept_{cleaned_data['unique_id']}_{random.randint(100, 999)}"

            department = Department.objects.create(
                name=cleaned_data['name'],
                department_type=cleaned_data['department_type'],
                unique_id=cleaned_data['unique_id'],
                state=cleaned_data['state_name'],
                city=cleaned_data['city_name'],
                city_admin=city_admin,
                location_name=cleaned_data['location_name'],
                email=cleaned_data['email'],
                phone=cleaned_data['phone'],
                address=cleaned_data['address'],
                sla_hours=cleaned_data['sla_hours'],
                latitude=cleaned_data['latitude'],
                longitude=cleaned_data['longitude'],
                is_active=cleaned_data['is_active'],
            )

            logo_temp_path = cleaned_data.get('department_logo_temp_path', '')
            if logo_temp_path and default_storage.exists(logo_temp_path):
                with default_storage.open(logo_temp_path, 'rb') as logo_file:
                    department.department_logo.save(
                        os.path.basename(logo_temp_path),
                        File(logo_file),
                        save=True
                    )
                default_storage.delete(logo_temp_path)

            department_user = User.objects.create_user(
                username=username,
                email=cleaned_data['email'],
                password=cleaned_data['department_password'],
                first_name=cleaned_data['name'][:150],
                last_name='Department'
            )
            DepartmentUser.objects.create(
                user=department_user,
                department=department,
                role='Officer'
            )

            otp_obj.is_verified = True
            otp_obj.save(update_fields=['is_verified'])
            send_department_credentials_email(
                cleaned_data['email'],
                department,
                cleaned_data['department_password']
            )

            request.session.pop('pending_department_data', None)
            messages.success(request, f'Department created successfully with code {department.unique_id}. Credentials sent to email.')
            return redirect('super_admin_departments')

        uploaded_logo = request.FILES.get('department_logo')
        existing_pending = request.session.get('pending_department_data', {}) if action == 'send_otp' else {}
        previous_temp_logo = str(existing_pending.get('department_logo_temp_path', '')).strip()
        temp_logo_path = previous_temp_logo
        if uploaded_logo:
            if previous_temp_logo and default_storage.exists(previous_temp_logo):
                default_storage.delete(previous_temp_logo)
            temp_logo_path = save_temp_department_logo(uploaded_logo)

        form_data = _normalize_form_data({
            'name': request.POST.get('name', ''),
            'department_type': request.POST.get('department_type', ''),
            'state_name': request.POST.get('state_name', ''),
            'city_name': request.POST.get('city_name', ''),
            'city_admin': request.POST.get('city_admin', ''),
            'unique_id': request.POST.get('unique_id', ''),
            'location_name': request.POST.get('location_name', ''),
            'email': request.POST.get('email', ''),
            'phone': request.POST.get('phone', ''),
            'address': request.POST.get('address', ''),
            'sla_hours': request.POST.get('sla_hours', '72'),
            'latitude': request.POST.get('latitude', ''),
            'longitude': request.POST.get('longitude', ''),
            'department_password': request.POST.get('department_password', ''),
            'department_logo_temp_path': temp_logo_path,
            'is_active': request.POST.get('is_active') == 'on',
        })
        cleaned_data, _city_admin, validation_error = _validate_department_form(form_data)
        if validation_error:
            messages.error(request, validation_error)
        elif User.objects.filter(email__iexact=cleaned_data['email']).exists():
            messages.error(request, 'This department email is already used by another account.')
        else:
            otp = generate_otp()
            OTP.objects.filter(email=cleaned_data['email'], is_verified=False).delete()
            OTP.objects.create(email=cleaned_data['email'], otp=otp)
            send_otp_email(cleaned_data['email'], otp)

            request.session['pending_department_data'] = {
                'name': cleaned_data['name'],
                'department_type': cleaned_data['department_type'],
                'state_name': cleaned_data['state_name'],
                'city_name': cleaned_data['city_name'],
                'city_admin': cleaned_data['city_admin'],
                'unique_id': cleaned_data['unique_id'],
                'location_name': cleaned_data['location_name'],
                'email': cleaned_data['email'],
                'phone': cleaned_data['phone'],
                'address': cleaned_data['address'],
                'sla_hours': cleaned_data['sla_hours'],
                'latitude': str(cleaned_data['latitude']),
                'longitude': str(cleaned_data['longitude']),
                'department_password': cleaned_data['department_password'],
                'department_logo_temp_path': cleaned_data.get('department_logo_temp_path', ''),
                'is_active': cleaned_data['is_active'],
            }
            messages.success(request, f'OTP sent to {cleaned_data["email"]}. Enter OTP to verify and create department.')
            return redirect('super_admin_add_department')

    otp_pending = bool(request.session.get('pending_department_data'))
    if otp_pending:
        form_data = _normalize_form_data(request.session.get('pending_department_data', {}))
    if not form_data['unique_id']:
        form_data['unique_id'] = _generate_unique_department_code()
    if not form_data['department_password']:
        form_data['department_password'] = generate_strong_password()

    context = {
        'page_title': 'Add Department',
        'city_admins': city_admins,
        'state_options': state_options,
        'city_options': city_options,
        'department_types': Department.DEPARTMENT_TYPES,
        'generated_code': form_data['unique_id'],
        'generated_password': form_data['department_password'],
        'form_data': form_data,
        'otp_pending': otp_pending,
    }
    return render(request, 'super_admin_add_department.html', context)


@login_required
def super_admin_edit_department(request, department_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    department = get_object_or_404(Department, id=department_id)
    city_admins = CityAdmin.objects.filter(is_active=True).select_related('user').order_by('city_name', 'user__first_name')
    state_options = build_state_options()
    city_options = build_city_options()
    valid_department_types = {value for value, _label in Department.DEPARTMENT_TYPES}

    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        department_type = request.POST.get('department_type', '').strip()
        state_name = request.POST.get('state_name', '').strip()
        city_name = request.POST.get('city_name', '').strip()
        city_admin_id = request.POST.get('city_admin', '').strip()
        unique_id = request.POST.get('unique_id', '').strip()
        location_name = request.POST.get('location_name', '').strip()
        email = request.POST.get('email', '').strip()
        phone = request.POST.get('phone', '').strip()
        address = request.POST.get('address', '').strip()
        sla_hours_raw = request.POST.get('sla_hours', '').strip()
        latitude = request.POST.get('latitude', '').strip()
        longitude = request.POST.get('longitude', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        if not name:
            messages.error(request, 'Department name is required.')
            return redirect('super_admin_edit_department', department_id=department.id)

        if department_type not in valid_department_types:
            messages.error(request, 'Please select a valid department category.')
            return redirect('super_admin_edit_department', department_id=department.id)

        try:
            city_admin = CityAdmin.objects.get(id=city_admin_id, is_active=True)
        except CityAdmin.DoesNotExist:
            messages.error(request, 'Please select a valid city admin.')
            return redirect('super_admin_edit_department', department_id=department.id)

        if city_name and city_admin.city_name.lower() != city_name.lower():
            messages.error(request, 'Selected city admin does not belong to the selected city.')
            return redirect('super_admin_edit_department', department_id=department.id)
        if state_name and city_admin.state.lower() != state_name.lower():
            messages.error(request, 'Selected city admin does not belong to the selected state.')
            return redirect('super_admin_edit_department', department_id=department.id)

        if not unique_id.isdigit() or not (4 <= len(unique_id) <= 8):
            messages.error(request, 'Department code must be 4 to 8 digits.')
            return redirect('super_admin_edit_department', department_id=department.id)

        if Department.objects.exclude(id=department.id).filter(unique_id=unique_id).exists():
            messages.error(request, 'Department code already exists. Please choose another.')
            return redirect('super_admin_edit_department', department_id=department.id)

        try:
            validate_email(email)
        except ValidationError:
            messages.error(request, 'Please enter a valid department email address.')
            return redirect('super_admin_edit_department', department_id=department.id)

        if not re.fullmatch(r'^\+?\d{10,15}$', phone):
            messages.error(request, 'Please enter a valid phone number (10 to 15 digits).')
            return redirect('super_admin_edit_department', department_id=department.id)

        try:
            sla_hours = int(sla_hours_raw)
        except (TypeError, ValueError):
            messages.error(request, 'SLA hours must be a valid number.')
            return redirect('super_admin_edit_department', department_id=department.id)
        if sla_hours < 1 or sla_hours > 720:
            messages.error(request, 'SLA hours must be between 1 and 720.')
            return redirect('super_admin_edit_department', department_id=department.id)

        try:
            latitude_val = float(latitude) if latitude else department.latitude
            longitude_val = float(longitude) if longitude else department.longitude
        except ValueError:
            messages.error(request, 'Invalid map coordinates.')
            return redirect('super_admin_edit_department', department_id=department.id)

        if request.POST.get('remove_logo') == '1' and department.department_logo:
            department.department_logo.delete(save=False)
            department.department_logo = None

        uploaded_logo = request.FILES.get('department_logo')
        if uploaded_logo:
            if department.department_logo:
                department.department_logo.delete(save=False)
            department.department_logo = uploaded_logo

        department.name = name
        department.department_type = department_type
        department.unique_id = unique_id
        department.state = state_name or city_admin.state
        department.city = city_name or city_admin.city_name
        department.city_admin = city_admin
        department.location_name = location_name or city_name or city_admin.city_name
        department.email = email
        department.phone = phone
        department.address = address
        department.sla_hours = sla_hours
        department.latitude = latitude_val
        department.longitude = longitude_val
        department.is_active = is_active if request.POST.get('is_active') is not None else department.is_active
        department.save()

        messages.success(request, f'Department {department.name} updated successfully.')
        return redirect('super_admin_departments')

    form_data = {
        'name': department.name,
        'department_type': department.department_type,
        'state_name': department.state or (department.city_admin.state if department.city_admin else ''),
        'city_name': department.city or (department.city_admin.city_name if department.city_admin else ''),
        'city_admin': str(department.city_admin_id or ''),
        'unique_id': department.unique_id,
        'location_name': department.location_name,
        'email': department.email,
        'phone': department.phone,
        'address': department.address,
        'sla_hours': str(department.sla_hours),
        'latitude': str(department.latitude),
        'longitude': str(department.longitude),
        'is_active': department.is_active,
    }

    context = {
        'page_title': 'Edit Department',
        'department': department,
        'city_admins': city_admins,
        'city_options': city_options,
        'state_options': state_options,
        'department_types': Department.DEPARTMENT_TYPES,
        'form_data': form_data,
    }
    return render(request, 'super_admin_edit_department.html', context)


@login_required
def super_admin_delete_department(request, department_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    department = get_object_or_404(Department, id=department_id)
    if request.method != 'POST':
        return redirect('super_admin_departments')

    department_name = department.name
    department.delete()
    messages.success(request, f'Department {department_name} deleted successfully.')
    return redirect('super_admin_departments')

@login_required
def super_admin_city_admins(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    city_admins = CityAdmin.objects.all().order_by('-created_at')
    state_options = build_state_options()
    city_options = [item['city_name'] for item in build_city_options()]
    
    context = {
        'city_admins': city_admins,
        'state_options': state_options,
        'city_options': city_options,
        'managed_states': ManagedState.objects.order_by('name'),
        'managed_cities': ManagedCity.objects.select_related('state').order_by('name'),
        'generated_password': generate_strong_password(),
        'page_title': 'Manage City Admins',
    }
    return render(request, 'super_admin_city_admins.html', context)


@login_required
def super_admin_categories(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    ensure_default_categories()

    if request.method == 'POST':
        action = request.POST.get('action', 'create').strip()

        if action == 'toggle':
            category_id = request.POST.get('category_id', '').strip()
            category = ComplaintCategory.objects.filter(id=category_id).first()
            if not category:
                messages.error(request, 'Category not found.')
                return redirect('super_admin_categories')
            category.is_active = not category.is_active
            category.save(update_fields=['is_active'])
            messages.success(request, f'Category {category.name} updated.')
            return redirect('super_admin_categories')

        name = request.POST.get('category_name', '').strip()
        key_input = request.POST.get('category_key', '').strip()
        emoji = request.POST.get('category_emoji', '').strip()
        key = slugify(key_input)[:20] if key_input else ''
        logo = request.FILES.get('category_logo')

        if not name:
            messages.error(request, 'Category name is required.')
            return redirect('super_admin_categories')

        if not key:
            key = generate_unique_category_key(name)
        if len(key) > 20:
            key = key[:20]
        if ComplaintCategory.objects.filter(key=key).exists():
            messages.error(request, 'Category key already exists. Use another key.')
            return redirect('super_admin_categories')

        submitted_sub_rows = extract_unique_subcategory_rows([], request.POST.getlist('subcategory_names[]'))
        submitted_sub_names = [name for _sub_id, name in submitted_sub_rows]
        if len(submitted_sub_names) < MIN_SUBCATEGORIES_PER_CATEGORY:
            messages.error(
                request,
                f'Please add minimum {MIN_SUBCATEGORIES_PER_CATEGORY} subcategories for each category.'
            )
            return redirect('super_admin_categories')

        order = ComplaintCategory.objects.aggregate(max_order=models.Max('display_order')).get('max_order') or 0
        category = ComplaintCategory.objects.create(
            key=key,
            name=name,
            emoji=emoji,
            logo=logo,
            display_order=order + 1,
            is_active=True,
        )

        sub_lookup = {}
        for idx, clean_name in enumerate(submitted_sub_names):
            subcategory, _created = ComplaintSubcategory.objects.get_or_create(
                category=category,
                name=clean_name,
                defaults={'display_order': idx + 1, 'is_active': True},
            )
            sub_lookup[clean_name.lower()] = subcategory

        field_labels = request.POST.getlist('field_labels[]')
        field_types = request.POST.getlist('field_types[]')
        field_required = request.POST.getlist('field_required[]')
        field_options = request.POST.getlist('field_options[]')
        field_subcategories = request.POST.getlist('field_subcategories[]')
        valid_types = {x[0] for x in ComplaintCategoryField.FIELD_TYPES}
        for idx, label in enumerate(field_labels):
            clean_label = (label or '').strip()
            if not clean_label:
                continue
            selected_type = field_types[idx] if idx < len(field_types) else 'text'
            if selected_type not in valid_types:
                selected_type = 'text'
            is_required = (field_required[idx] if idx < len(field_required) else '0') == '1'
            options = (field_options[idx] if idx < len(field_options) else '').strip()
            if selected_type != 'select':
                options = ''
            selected_sub = (field_subcategories[idx] if idx < len(field_subcategories) else '').strip().lower()
            subcategory = sub_lookup.get(selected_sub) if selected_sub and selected_sub != '__all__' else None
            ComplaintCategoryField.objects.create(
                category=category,
                subcategory=subcategory,
                label=clean_label,
                field_type=selected_type,
                options=options,
                is_required=is_required,
                display_order=idx + 1,
                is_active=True,
            )

        ensure_category_baseline(category, preferred_sub_names=submitted_sub_names)

        messages.success(request, f'Category "{category.name}" created successfully.')
        return redirect('super_admin_categories')

    categories = (
        ComplaintCategory.objects
        .prefetch_related('subcategories', 'dynamic_fields__subcategory')
        .order_by('display_order', 'name')
    )
    context = {
        'page_title': 'Manage Categories',
        'categories': categories,
        'field_types': ComplaintCategoryField.FIELD_TYPES,
    }
    return render(request, 'super_admin_categories.html', context)


@login_required
def super_admin_edit_category(request, category_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    ensure_default_categories()
    category = get_object_or_404(ComplaintCategory, id=category_id)

    if request.method == 'POST':
        name = request.POST.get('category_name', '').strip()
        key_input = request.POST.get('category_key', '').strip()
        emoji = request.POST.get('category_emoji', '').strip()
        key = slugify(key_input)[:20] if key_input else category.key
        is_active = request.POST.get('is_active') == 'on'

        if not name:
            messages.error(request, 'Category name is required.')
            return redirect('super_admin_edit_category', category_id=category.id)

        if not key:
            key = generate_unique_category_key(name)

        if ComplaintCategory.objects.exclude(id=category.id).filter(key=key).exists():
            messages.error(request, 'Category key already exists. Use another key.')
            return redirect('super_admin_edit_category', category_id=category.id)

        sub_ids = request.POST.getlist('subcategory_ids[]')
        sub_names = request.POST.getlist('subcategory_names[]')
        submitted_sub_rows = extract_unique_subcategory_rows(sub_ids, sub_names)
        if len(submitted_sub_rows) < MIN_SUBCATEGORIES_PER_CATEGORY:
            messages.error(
                request,
                f'Please keep minimum {MIN_SUBCATEGORIES_PER_CATEGORY} subcategories for each category.'
            )
            return redirect('super_admin_edit_category', category_id=category.id)

        if request.POST.get('remove_logo') == '1' and category.logo:
            category.logo.delete(save=False)
            category.logo = None

        uploaded_logo = request.FILES.get('category_logo')
        if uploaded_logo:
            if category.logo:
                category.logo.delete(save=False)
            category.logo = uploaded_logo

        category.name = name
        category.key = key
        category.emoji = emoji
        category.is_active = is_active
        category.save()

        existing_subcategories = {str(sub.id): sub for sub in category.subcategories.all()}
        kept_subcategory_ids = []
        sub_lookup = {}
        sub_lookup_by_id = {}
        for idx, (sub_id, clean_name) in enumerate(submitted_sub_rows):
            if sub_id and sub_id in existing_subcategories:
                sub_obj = existing_subcategories[sub_id]
                sub_obj.name = clean_name
                sub_obj.display_order = idx + 1
                sub_obj.is_active = True
                sub_obj.save(update_fields=['name', 'display_order', 'is_active'])
            else:
                sub_obj, _created = ComplaintSubcategory.objects.get_or_create(
                    category=category,
                    name=clean_name,
                    defaults={'display_order': idx + 1, 'is_active': True},
                )
                if not _created:
                    sub_obj.display_order = idx + 1
                    sub_obj.is_active = True
                    sub_obj.save(update_fields=['display_order', 'is_active'])

            kept_subcategory_ids.append(sub_obj.id)
            sub_lookup[clean_name.lower()] = sub_obj
            sub_lookup_by_id[str(sub_obj.id)] = sub_obj

        category.subcategories.exclude(id__in=kept_subcategory_ids).delete()

        field_ids = request.POST.getlist('field_ids[]')
        field_labels = request.POST.getlist('field_labels[]')
        field_types = request.POST.getlist('field_types[]')
        field_required = request.POST.getlist('field_required[]')
        field_options = request.POST.getlist('field_options[]')
        field_subcategories = request.POST.getlist('field_subcategories[]')

        valid_types = {value for value, _label in ComplaintCategoryField.FIELD_TYPES}
        existing_fields = {str(field.id): field for field in category.dynamic_fields.all()}
        kept_field_ids = []

        for idx, label in enumerate(field_labels):
            clean_label = (label or '').strip()
            if not clean_label:
                continue

            selected_type = (field_types[idx] if idx < len(field_types) else 'text').strip()
            if selected_type not in valid_types:
                selected_type = 'text'

            is_required = (field_required[idx] if idx < len(field_required) else '0') == '1'
            options = (field_options[idx] if idx < len(field_options) else '').strip()
            if selected_type != 'select':
                options = ''

            selected_sub_key = (field_subcategories[idx] if idx < len(field_subcategories) else '').strip()
            field_subcategory = None
            if selected_sub_key and selected_sub_key != '__all__':
                if selected_sub_key.startswith('id:'):
                    field_subcategory = sub_lookup_by_id.get(selected_sub_key.replace('id:', '', 1).strip())
                elif selected_sub_key.startswith('name:'):
                    field_subcategory = sub_lookup.get(selected_sub_key.replace('name:', '', 1).strip().lower())
                else:
                    field_subcategory = sub_lookup.get(selected_sub_key.strip().lower())

            field_id = (field_ids[idx] if idx < len(field_ids) else '').strip()
            if field_id and field_id in existing_fields:
                field_obj = existing_fields[field_id]
                field_obj.label = clean_label
                field_obj.field_type = selected_type
                field_obj.options = options
                field_obj.is_required = is_required
                field_obj.display_order = idx + 1
                field_obj.is_active = True
                field_obj.subcategory = field_subcategory
                field_obj.save(update_fields=[
                    'label', 'field_type', 'options', 'is_required',
                    'display_order', 'is_active', 'subcategory'
                ])
            else:
                field_obj = ComplaintCategoryField.objects.create(
                    category=category,
                    subcategory=field_subcategory,
                    label=clean_label,
                    field_type=selected_type,
                    options=options,
                    is_required=is_required,
                    display_order=idx + 1,
                    is_active=True,
                )

            kept_field_ids.append(field_obj.id)

        category.dynamic_fields.exclude(id__in=kept_field_ids).delete()
        ensure_category_baseline(
            category,
            preferred_sub_names=[name for _sub_id, name in submitted_sub_rows]
        )

        messages.success(request, f'Category "{category.name}" updated successfully.')
        return redirect('super_admin_edit_category', category_id=category.id)

    subcategories = category.subcategories.all().order_by('display_order', 'name')
    fields = category.dynamic_fields.select_related('subcategory').order_by('display_order', 'id')

    context = {
        'page_title': f'Edit Category - {category.name}',
        'category': category,
        'subcategories': subcategories,
        'fields': fields,
        'field_types': ComplaintCategoryField.FIELD_TYPES,
    }
    return render(request, 'super_admin_edit_category.html', context)


@login_required
def super_admin_total(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    base_complaints = Complaint.objects.all()

    # Filter values
    category_filter = request.GET.get('category', '').strip()
    state_filter = request.GET.get('state', '').strip()
    city_filter = request.GET.get('city', '').strip()
    status_filter = request.GET.get('status', '').strip()

    # Dropdown options
    state_options = (
        base_complaints
        .exclude(state__isnull=True)
        .exclude(state__exact='')
        .values_list('state', flat=True)
        .distinct()
        .order_by('state')
    )

    city_source = base_complaints
    if state_filter:
        city_source = city_source.filter(state=state_filter)

    city_options = (
        city_source
        .exclude(city__isnull=True)
        .exclude(city__exact='')
        .values_list('city', flat=True)
        .distinct()
        .order_by('city')
    )

    complaints = base_complaints
    if category_filter:
        complaints = complaints.filter(complaint_type=category_filter)
    if state_filter:
        complaints = complaints.filter(state=state_filter)
    if city_filter:
        complaints = complaints.filter(city=city_filter)
    if status_filter:
        complaints = complaints.filter(work_status=status_filter)
    complaints = complaints.order_by('-created_at')
    
    context = {
        'complaints': complaints,
        'category_filter': category_filter,
        'state_filter': state_filter,
        'city_filter': city_filter,
        'status_filter': status_filter,
        'state_options': state_options,
        'city_options': city_options,
        'complaint_types': get_active_category_choices(),
        'page_title': 'Total Problems',
    }
    return render(request, 'super_admin_total.html', context)


@login_required
def super_admin_heatmap(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    # Get departments and complaints
    departments = Department.objects.filter(
        is_active=True
    ).exclude(latitude__isnull=True).exclude(longitude__isnull=True)
    
    complaints = Complaint.objects.exclude(latitude__isnull=True).exclude(longitude__isnull=True)

    # Filters
    map_type = request.GET.get('map_type', 'complaints').strip()
    category_filter = request.GET.get('category', '').strip()
    state_filter = request.GET.get('state', '').strip()
    city_filter = request.GET.get('city', '').strip()
    status_filter = request.GET.get('status', '').strip()
    department_filter = request.GET.get('department', '').strip()
    date_from = request.GET.get('date_from', '').strip()
    date_to = request.GET.get('date_to', '').strip()
    
    # Apply filters to departments
    filtered_departments = departments
    if state_filter:
        filtered_departments = filtered_departments.filter(state__icontains=state_filter)
    if city_filter:
        filtered_departments = filtered_departments.filter(city__icontains=city_filter)
    if department_filter:
        try:
            dept_id = int(department_filter)
            filtered_departments = filtered_departments.filter(id=dept_id)
        except (ValueError, TypeError):
            filtered_departments = filtered_departments.none()
    
    # For department type filtering, we need to check the category_filter
    if category_filter:
        # Map complaint types to department types
        category_to_dept_type = {
            'police': 'police',
            'traffic': 'traffic', 
            'construction': 'construction',
            'water': 'water',
            'electricity': 'electricity',
            'garbage': 'garbage',
            'road': 'road',
            'drainage': 'drainage',
            'illegal': 'illegal',
            'transportation': 'transportation',
            'cyber': 'cyber',
            'other': 'other'
        }
        dept_type = category_to_dept_type.get(category_filter)
        if dept_type:
            filtered_departments = filtered_departments.filter(department_type=dept_type)

    # Apply filters to complaints
    filtered_complaints = complaints
    if category_filter:
        filtered_complaints = filtered_complaints.filter(complaint_type=category_filter)
    if state_filter:
        filtered_complaints = filtered_complaints.filter(state__icontains=state_filter)
    if city_filter:
        filtered_complaints = filtered_complaints.filter(city__icontains=city_filter)
    if status_filter:
        filtered_complaints = filtered_complaints.filter(work_status=status_filter)
    if department_filter:
        try:
            dept_id = int(department_filter)
            filtered_complaints = filtered_complaints.filter(assigned_department__id=dept_id)
        except (ValueError, TypeError):
            filtered_complaints = filtered_complaints.none()

    # Date filters
    try:
        if date_from:
            parsed_date_from = datetime.strptime(date_from, '%Y-%m-%d').date()
            filtered_complaints = filtered_complaints.filter(created_at__date__gte=parsed_date_from)
    except ValueError:
        messages.error(request, 'Invalid "From date" format. Use YYYY-MM-DD.')
        date_from = ''
    try:
        if date_to:
            parsed_date_to = datetime.strptime(date_to, '%Y-%m-%d').date()
            filtered_complaints = filtered_complaints.filter(created_at__date__lte=parsed_date_to)
    except ValueError:
        messages.error(request, 'Invalid "To date" format. Use YYYY-MM-DD.')
        date_to = ''

    filtered_complaints = filtered_complaints.select_related('assigned_department').order_by('-created_at')

    # Prepare data based on map type
    heat_points = []
    marker_points = []
    department_points = []
    
    intensity_by_status = {
        'pending': 1.0,
        'reopened': 0.95,
        'confirmed': 0.8,
        'process': 0.7,
        'solved': 0.45,
        'rejected': 0.35,
    }

    if map_type == 'complaints':
        # Complaints only
        for complaint in filtered_complaints:
            try:
                lat = float(complaint.latitude)
                lng = float(complaint.longitude)
            except (TypeError, ValueError):
                continue
            if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                continue

            heat_points.append([lat, lng, intensity_by_status.get(complaint.work_status, 0.6)])
            marker_points.append({
                'lat': lat,
                'lng': lng,
                'complaint_id': complaint.id,
                'complaint_number': complaint.complaint_number,
                'title': complaint.title,
                'status': complaint.get_work_status_display(),
                'category': complaint.get_complaint_type_display(),
                'city': complaint.city,
                'state': complaint.state,
                'created_at': complaint.created_at.strftime('%Y-%m-%d %H:%M'),
                'detail_url': reverse('super_admin_complaint_detail', args=[complaint.id]),
                'marker_type': 'complaint'
            })
    
    elif map_type == 'departments':
        # Departments only
        for dept in filtered_departments:
            try:
                lat = float(dept.latitude)
                lng = float(dept.longitude)
            except (TypeError, ValueError):
                continue
            if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                continue
                
            # Count complaints for this department
            dept_complaints = complaints.filter(assigned_department=dept)
            total_complaints = dept_complaints.count()
            pending_complaints = dept_complaints.filter(work_status__in=['pending', 'confirmed', 'process', 'reopened']).count()
            solved_complaints = dept_complaints.filter(work_status='solved').count()
            
            department_points.append({
                'lat': lat,
                'lng': lng,
                'department_id': dept.id,
                'name': dept.name,
                'type': dept.get_department_type_display(),
                'email': dept.email,
                'phone': dept.phone,
                'address': dept.address,
                'city': dept.city,
                'state': dept.state,
                'total_complaints': total_complaints,
                'pending_complaints': pending_complaints,
                'solved_complaints': solved_complaints,
                'sla_hours': dept.sla_hours,
                'marker_type': 'department'
            })
    
    elif map_type == 'combined':
        # Both complaints and departments
        for complaint in filtered_complaints:
            try:
                lat = float(complaint.latitude)
                lng = float(complaint.longitude)
            except (TypeError, ValueError):
                continue
            if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                continue

            heat_points.append([lat, lng, intensity_by_status.get(complaint.work_status, 0.6)])
            marker_points.append({
                'lat': lat,
                'lng': lng,
                'complaint_id': complaint.id,
                'complaint_number': complaint.complaint_number,
                'title': complaint.title,
                'status': complaint.get_work_status_display(),
                'category': complaint.get_complaint_type_display(),
                'city': complaint.city,
                'state': complaint.state,
                'created_at': complaint.created_at.strftime('%Y-%m-%d %H:%M'),
                'detail_url': reverse('super_admin_complaint_detail', args=[complaint.id]),
                'marker_type': 'complaint'
            })
        
        for dept in filtered_departments:
            try:
                lat = float(dept.latitude)
                lng = float(dept.longitude)
            except (TypeError, ValueError):
                continue
            if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                continue
                
            dept_complaints = complaints.filter(assigned_department=dept)
            total_complaints = dept_complaints.count()
            pending_complaints = dept_complaints.filter(work_status__in=['pending', 'confirmed', 'process', 'reopened']).count()
            solved_complaints = dept_complaints.filter(work_status='solved').count()
            
            department_points.append({
                'lat': lat,
                'lng': lng,
                'department_id': dept.id,
                'name': dept.name,
                'type': dept.get_department_type_display(),
                'email': dept.email,
                'phone': dept.phone,
                'address': dept.address,
                'city': dept.city,
                'state': dept.state,
                'total_complaints': total_complaints,
                'pending_complaints': pending_complaints,
                'solved_complaints': solved_complaints,
                'sla_hours': dept.sla_hours,
                'marker_type': 'department'
            })

    status_counts = {
        row['work_status']: row['total']
        for row in filtered_complaints.values('work_status').annotate(total=Count('id'))
    }

    state_options = (
        Complaint.objects
        .exclude(state__isnull=True)
        .exclude(state__exact='')
        .values_list('state', flat=True)
        .distinct()
        .order_by('state')
    )

    city_source = Complaint.objects.all()
    if state_filter:
        city_source = city_source.filter(state=state_filter)
    city_options = (
        city_source
        .exclude(city__isnull=True)
        .exclude(city__exact='')
        .values_list('city', flat=True)
        .distinct()
        .order_by('city')
    )

    context = {
        'page_title': 'Complaint Heatmap',
        'heat_points_json': json.dumps(heat_points),
        'marker_points_json': json.dumps(marker_points),
        'department_points_json': json.dumps(department_points),
        'total_points': len(marker_points) + len(department_points),
        'status_counts': status_counts,
        'map_type': map_type,
        'category_filter': category_filter,
        'state_filter': state_filter,
        'city_filter': city_filter,
        'status_filter': status_filter,
        'department_filter': department_filter,
        'date_from': date_from,
        'date_to': date_to,
        'state_options': state_options,
        'city_options': city_options,
        'complaint_types': get_active_category_choices(),
        'departments': Department.objects.filter(is_active=True).order_by('name'),
    }
    return render(request, 'super_admin_heatmap.html', context)


@login_required
def super_admin_complaint_detail(request, complaint_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    complaint = get_object_or_404(Complaint, id=complaint_id)
    from_page = request.GET.get('from', '').strip().lower()
    if from_page == 'review':
        back_url = reverse('super_admin_review')
        back_label = 'Back to Review'
    elif from_page == 'solved':
        back_url = reverse('super_admin_solved')
        back_label = 'Back to Solved'
    elif from_page == 'total':
        back_url = reverse('super_admin_total')
        back_label = 'Back to Total Problems'
    elif from_page == 'heatmap':
        back_url = reverse('super_admin_heatmap')
        back_label = 'Back to Heatmap'
    else:
        back_url = reverse('super_admin_problems')
        back_label = 'Back to Problems'
    
    context = {
        'complaint': complaint,
        'page_title': f'Complaint #{complaint.complaint_number}',
        'back_url': back_url,
        'back_label': back_label,
    }
    return render(request, 'super_admin_complaint_detail.html', context)

@login_required
def super_admin_department_detail(request, department_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')

    # Get department
    department = get_object_or_404(Department, id=department_id)
    
    # Get department statistics
    dept_complaints = Complaint.objects.filter(assigned_department=department)
    total_complaints = dept_complaints.count()
    pending_complaints = dept_complaints.filter(work_status__in=['pending', 'confirmed', 'process', 'reopened']).count()
    solved_complaints = dept_complaints.filter(work_status='solved').count()
    
    # Calculate average rating
    rated_complaints = dept_complaints.filter(citizen_rating__isnull=False)
    avg_rating = rated_complaints.aggregate(models.Avg('citizen_rating'))['citizen_rating__avg'] or 0
    
    # Get recent complaints (last 10)
    recent_complaints = dept_complaints.order_by('-created_at')[:10]
    
    context = {
        'department': department,
        'total_complaints': total_complaints,
        'pending_complaints': pending_complaints,
        'solved_complaints': solved_complaints,
        'avg_rating': avg_rating,
        'recent_complaints': recent_complaints,
        'page_title': f'{department.name} - Department Details',
    }
    
    return render(request, 'super_admin_department_detail.html', context)

@login_required
def city_admin_complaint_detail(request, complaint_number):
    try:
        city_admin = CityAdmin.objects.get(user=request.user)
    except CityAdmin.DoesNotExist:
        if request.user.is_superuser:
            # Fallback for superuser testing
            complaint = get_object_or_404(Complaint, complaint_number=complaint_number)
        else:
            return redirect('user_dashboard')
    else:
        # Get complaint and verify it belongs to this city admin's city
        complaint = get_object_or_404(
            Complaint, 
            complaint_number=complaint_number,
            city__iexact=city_admin.city_name,
            state__iexact=city_admin.state
        )
    
    from_page = request.GET.get('from', '').strip().lower()
    if from_page == 'dashboard':
        back_url = reverse('city_admin_dashboard')
        back_label = 'Back to Dashboard'
    else:
        back_url = reverse('city_admin_problems')
        back_label = 'Back to City Problems'
    
    context = {
        'complaint': complaint,
        'page_title': f'Complaint Detail: {complaint.complaint_number}',
        'back_url': back_url,
        'back_label': back_label,
        'city_admin': city_admin if 'city_admin' in locals() else None,
    }
    return render(request, 'city_admin_complaint_detail.html', context)

def city_admin_dashboard(request, city_admin):
    # City admin specific dashboard
    departments = Department.objects.filter(city_admin=city_admin)
    # Filter complaints by city and state of the city admin
    complaints = Complaint.objects.filter(
        city__iexact=city_admin.city_name,
        state__iexact=city_admin.state
    )
    
    total_complaints = complaints.count()
    pending_complaints = complaints.filter(work_status='pending').count()
    in_progress_complaints = complaints.filter(work_status='process').count()
    resolved_complaints = complaints.filter(work_status='solved').count()
    total_departments = departments.count()
    
    recent_complaints = complaints.order_by('-created_at')[:10]
    
    # Get complaint statistics by type
    complaint_types = complaints.values('complaint_type').annotate(
        count=models.Count('id')
    ).order_by('-count')[:5]
    
    # Get department performance
    dept_performance = departments.annotate(
        total_complaints=models.Count('complaint'),
        resolved_complaints=models.Count('complaint', filter=models.Q(complaint__work_status='solved'))
    )
    
    context = {
        'total_complaints': total_complaints,
        'pending_complaints': pending_complaints,
        'in_progress_complaints': in_progress_complaints,
        'resolved_complaints': resolved_complaints,
        'total_departments': total_departments,
        'recent_complaints': recent_complaints,
        'departments': departments,
        'city_admin': city_admin,
        'complaint_types': complaint_types,
        'dept_performance': dept_performance,
        'is_main_admin': False,
    }
    
    return render(request, 'city_admin_dashboard.html', context)

@login_required
def department_dashboard_new(request):
    try:
        dept_user = DepartmentUser.objects.get(user=request.user)
        department = dept_user.department
        
        # Get complaints for this department
        complaints = Complaint.objects.filter(
            assigned_department=department
        ).order_by('-created_at')
        
        # Get statistics
        total_complaints = complaints.count()
        pending_complaints = complaints.filter(work_status='pending').count()
        in_progress_complaints = complaints.filter(work_status='process').count()
        resolved_complaints = complaints.filter(work_status='solved').count()
        
        context = {
            'department': department,
            'complaints': complaints,
            'total_complaints': total_complaints,
            'pending_complaints': pending_complaints,
            'in_progress_complaints': in_progress_complaints,
            'resolved_complaints': resolved_complaints,
        }
        
        return render(request, 'department_dashboard_new.html', context)
        
    except DepartmentUser.DoesNotExist:
        return redirect('user_dashboard')

@login_required
def update_complaint_status(request, complaint_id):
    complaint = get_object_or_404(Complaint, id=complaint_id)
    
    if request.method == 'POST':
        new_status = request.POST.get('status')
        notes = request.POST.get('notes', '')
        from_page = request.POST.get('from_page', '')
        proof_files = request.FILES.getlist('resolution_proofs')

        def redirect_back():
            if from_page == 'super_admin':
                return redirect('super_admin_problems')
            if from_page == 'city_admin':
                return redirect('city_admin_problems')
            return redirect('department_dashboard_new')

        normalize_status = {
            'in_progress': 'process',
            'resolved': 'solved',
        }

        previous_status = complaint.work_status
        normalized_new_status = normalize_status.get(new_status, new_status)
        normalized_current_status = normalize_status.get(complaint.work_status, complaint.work_status)

        allowed_transitions = {
            'pending': {'pending', 'confirmed', 'rejected'},
            'reopened': {'reopened', 'confirmed', 'rejected'},
            'confirmed': {'confirmed', 'process'},
            'process': {'process', 'solved'},
            'solved': {'solved'},
            'rejected': {'rejected'},
        }

        current_status = normalized_current_status
        valid_next = allowed_transitions.get(current_status, {current_status})

        if normalized_new_status not in valid_next:
            messages.error(
                request,
                f'Invalid status change from {current_status} to {normalized_new_status}.'
            )
            return redirect_back()

        # Require completion proof when moving to solved first time
        if normalized_new_status == 'solved' and current_status != 'solved':
            if not proof_files and not complaint.resolution_proofs.exists():
                messages.error(request, 'Please upload completion proof before marking as solved.')
                return redirect_back()
        
        complaint.work_status = normalized_new_status
        if notes:
            complaint.resolution_notes = notes
        
        if normalized_new_status == 'solved':
            complaint.resolved_at = timezone.now()
        
        complaint.save()

        # Save uploaded resolution proofs
        for proof in proof_files:
            proof_name = proof.name.lower()
            file_type = 'video' if proof_name.endswith(('.mp4', '.mov', '.avi', '.mkv', '.webm')) else 'image'
            ComplaintResolutionProof.objects.create(
                complaint=complaint,
                file=proof,
                file_type=file_type,
                uploaded_by=request.user if request.user.is_authenticated else None
            )

        actor = request.user.get_full_name() or request.user.username or 'System'
        if normalized_new_status != previous_status:
            if normalized_new_status == 'solved':
                _send_complaint_notification_email(complaint, event='closure', actor_name=actor)
            else:
                _send_complaint_notification_email(complaint, event='status_changed', actor_name=actor)

        messages.success(request, f'Complaint status updated to {normalized_new_status}!')
        return redirect_back()
    
    return redirect('department_dashboard_new')


@login_required
def submit_complaint_feedback(request, complaint_id):
    complaint = get_object_or_404(Complaint, id=complaint_id, user=request.user)

    if request.method != 'POST':
        return redirect('track_complaints')

    if complaint.work_status != 'solved':
        messages.error(request, 'Feedback can be submitted only after complaint is solved.')
        return redirect('track_complaints')

    rating_raw = request.POST.get('rating', '').strip()
    feedback = request.POST.get('feedback', '').strip()

    try:
        rating = int(rating_raw)
    except (TypeError, ValueError):
        messages.error(request, 'Please select a valid rating between 1 and 5.')
        return redirect('track_complaints')

    if rating < 1 or rating > 5:
        messages.error(request, 'Rating must be between 1 and 5.')
        return redirect('track_complaints')

    from django.utils import timezone
    complaint.citizen_rating = rating
    complaint.citizen_feedback = feedback
    complaint.citizen_rated_at = timezone.now()
    complaint.save(update_fields=['citizen_rating', 'citizen_feedback', 'citizen_rated_at'])

    messages.success(request, 'Thank you! Your rating and feedback have been submitted.')
    return redirect('track_complaints')


@login_required
def reopen_complaint(request, complaint_id):
    complaint = get_object_or_404(Complaint, id=complaint_id, user=request.user)

    if request.method != 'POST':
        return redirect('track_complaints')

    if complaint.work_status != 'solved':
        messages.error(request, 'Only solved complaints can be reopened.')
        return redirect('track_complaints')

    if not complaint.can_reopen:
        messages.error(
            request,
            f'Reopen window expired. You can reopen only within {Complaint.REOPEN_WINDOW_DAYS} days after solved.'
        )
        return redirect('track_complaints')

    reopen_reason = request.POST.get('reopen_reason', '').strip()
    reopen_proof = request.FILES.get('reopen_proof')

    if not reopen_reason:
        messages.error(request, 'Please provide a reason for reopening.')
        return redirect('track_complaints')
    if not reopen_proof:
        messages.error(request, 'Please upload photo proof to reopen the complaint.')
        return redirect('track_complaints')

    proof_name = (reopen_proof.name or '').lower()
    if not proof_name.endswith(('.jpg', '.jpeg', '.png', '.webp', '.bmp')):
        messages.error(request, 'Only image files are allowed for reopen proof.')
        return redirect('track_complaints')

    ComplaintReopenProof.objects.create(
        complaint=complaint,
        reason=reopen_reason,
        proof=reopen_proof,
        requested_by=request.user,
    )

    complaint.work_status = 'reopened'
    complaint.reopen_reason = reopen_reason
    complaint.reopened_at = timezone.now()
    complaint.reopen_requested_by = request.user
    complaint.reopen_count = int(complaint.reopen_count or 0) + 1
    complaint.save(update_fields=['work_status', 'reopen_reason', 'reopened_at', 'reopen_requested_by', 'reopen_count'])

    actor = request.user.get_full_name() or request.user.username or 'Citizen'
    _send_complaint_notification_email(complaint, event='reopened', actor_name=actor)

    messages.success(request, 'Complaint reopened successfully with proof.')
    return redirect('track_complaints')


def delete_complaint(request, complaint_id):
    complaint = get_object_or_404(Complaint, id=complaint_id)
    
    # Check permissions: Superuser or City Admin for the complaint's city
    is_allowed = request.user.is_superuser
    if not is_allowed:
        try:
            city_admin = CityAdmin.objects.get(user=request.user)
            if city_admin.city_name.lower() == complaint.city.lower() and city_admin.state.lower() == complaint.state.lower():
                is_allowed = True
        except CityAdmin.DoesNotExist:
            pass
            
    if not is_allowed:
        messages.error(request, 'Access denied!')
        return redirect('user_dashboard')
    
    complaint.delete()
    messages.success(request, 'Complaint deleted successfully!')
    
    # Redirect based on user role
    if request.user.is_superuser:
        return redirect('super_admin_problems')
    return redirect('city_admin_dashboard')

@login_required
def super_admin_users(request):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    # Filter for regular users (citizens)
    # We identify them as those having a CitizenProfile
    # and not being superusers or city admins or department users
    users = User.objects.filter(is_superuser=False).exclude(cityadmin__isnull=False).exclude(departmentuser__isnull=False)
    
    # Search functionality
    search_query = request.GET.get('search', '').strip()
    if search_query:
        users = users.filter(
            Q(first_name__icontains=search_query) |
            Q(last_name__icontains=search_query) |
            Q(email__icontains=search_query) |
            Q(citizenprofile__mobile_no__icontains=search_query)
        )
    
    users = users.order_by('-date_joined')
    
    context = {
        'users': users,
        'search_query': search_query,
        'page_title': 'Citizen Users',
    }
    return render(request, 'super_admin_users.html', context)

@login_required
def super_admin_user_detail(request, user_id):
    if not request.user.is_superuser:
        return redirect('user_dashboard')
    
    user_obj = get_object_or_404(User, id=user_id)
    profile = getattr(user_obj, 'citizenprofile', None)
    complaints = Complaint.objects.filter(user=user_obj).order_by('-created_at')
    
    context = {
        'user_obj': user_obj,
        'profile': profile,
        'complaints': complaints,
        'page_title': f'User Profile: {user_obj.get_full_name() or user_obj.username}',
    }
    return render(request, 'super_admin_user_detail.html', context)

def view_all_departments(request):
    """View all departments with map showing all locations"""
    # Get all active departments
    departments = Department.objects.filter(
        is_active=True
    ).select_related('city_admin').order_by('department_type', 'name')
    
    # Group departments by type
    departments_by_type = {}
    for dept in departments:
        dept_type = dept.get_department_type_display()
        if dept_type not in departments_by_type:
            departments_by_type[dept_type] = []
        departments_by_type[dept_type].append(dept)
    
    # Prepare department data for map
    department_data = []
    for dept in departments:
        department_data.append({
            'id': dept.id,
            'name': dept.name,
            'type': dept.get_department_type_display(),
            'type_key': dept.department_type,
            'latitude': float(dept.latitude) if dept.latitude else 20.5937,
            'longitude': float(dept.longitude) if dept.longitude else 78.9629,
            'address': dept.address,
            'phone': dept.phone,
            'email': dept.email,
            'city': dept.city,
            'state': dept.state,
            'location_name': dept.location_name,
            'sla_hours': dept.sla_hours,
        })
    
    context = {
        'departments': departments,
        'departments_by_type': departments_by_type,
        'department_data': department_data,
        'total_departments': departments.count(),
    }
    
    return render(request, 'view_all_departments.html', context)

def user_view_department(request, department_type):
    """View all departments of a specific type with map and personal details"""
    # Get all active departments of the specified type
    departments = Department.objects.filter(
        department_type=department_type,
        is_active=True
    ).select_related('city_admin').order_by('name')
    
    # Get department type display name
    dept_display_name = dict(Department.DEPARTMENT_TYPES).get(department_type, department_type.title())
    
    # Prepare department data for map
    department_data = []
    for dept in departments:
        department_data.append({
            'id': dept.id,
            'name': dept.name,
            'latitude': float(dept.latitude) if dept.latitude else 20.5937,
            'longitude': float(dept.longitude) if dept.longitude else 78.9629,
            'address': dept.address,
            'phone': dept.phone,
            'email': dept.email,
            'city': dept.city,
            'state': dept.state,
            'location_name': dept.location_name,
            'sla_hours': dept.sla_hours,
        })
    
    context = {
        'departments': departments,
        'department_data': department_data,
        'department_type': department_type,
        'dept_display_name': dept_display_name,
        'total_departments': departments.count(),
    }
    
    return render(request, 'user_view_department.html', context)

def profile_view(request):
    if not request.user.is_authenticated:
        return redirect('/dashboard/?guest=true')
    
    # Check if user is city admin or staff - they should manage profile through admin or separate view
    is_city_admin = CityAdmin.objects.filter(user=request.user).exists()
    is_dept_user = DepartmentUser.objects.filter(user=request.user).exists()
    
    if request.method == 'POST':
        user = request.user
        
        # Update basic user fields for everyone
        full_name = request.POST.get('full_name', '').split(' ', 1)
        user.first_name = full_name[0] if full_name else ''
        user.last_name = full_name[1] if len(full_name) > 1 else ''
        user.email = request.POST.get('email', user.email)
        user.save()
        
        # Only update CitizenProfile for regular citizens
        if not is_city_admin and not is_dept_user and not user.is_superuser:
            profile, created = CitizenProfile.objects.get_or_create(user=user)
            profile.mobile_no = request.POST.get('mobile', profile.mobile_no or '')
            profile.state = request.POST.get('state', profile.state or '')
            profile.district = request.POST.get('district', profile.district or '')
            profile.city = request.POST.get('city', profile.city or '')
            profile.address = request.POST.get('address', profile.address or '')
            profile.aadhaar_number = request.POST.get('aadhaar', profile.aadhaar_number or '')
            profile.save()
        
        messages.success(request, 'Profile updated successfully!')
        return redirect('profile')
    
    context = {
        'is_city_admin': is_city_admin,
        'is_dept_user': is_dept_user,
    }
    return render(request, 'profile.html', context)

def reverse_geocode(request):
    """Backend endpoint to handle reverse geocoding API calls"""
    if request.method == 'GET':
        lat = request.GET.get('lat')
        lng = request.GET.get('lng')
        
        if not lat or not lng:
            return JsonResponse({'error': 'Missing coordinates'}, status=400)
        
        try:
            # Use OpenStreetMap Nominatim for free reverse geocoding
            url = f"https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lng}&zoom=18&addressdetails=1"
            req = urllib.request.Request(url, headers={'User-Agent': 'SmartCityApp/1.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                osm_data = json.loads(response.read().decode())
                address = osm_data.get('address', {})
                
                # Extract pincode using regex as fallback if not in address dict
                pincode = address.get('postcode', address.get('postal_code', ''))
                if not pincode and osm_data.get('display_name'):
                    import re
                    pin_match = re.search(r'\b\d{6}\b', osm_data['display_name'])
                    if pin_match:
                        pincode = pin_match.group(0)

                return JsonResponse({
                    'results': [{
                        'formatted_address': osm_data.get('display_name', ''),
                        'state': address.get('state', ''),
                        'district': address.get('district', address.get('city_district', address.get('county', ''))),
                        'city': address.get('city', address.get('town', address.get('village', address.get('suburb', address.get('city_district', ''))))),
                        'locality': address.get('suburb', address.get('neighbourhood', address.get('road', address.get('hamlet', '')))),
                        'pincode': pincode
                    }]
                })
                
        except Exception as e:
            # Return empty data on any error
            return JsonResponse({
                'results': [{
                    'formatted_address': f'Location at {lat}, {lng}',
                    'state': '',
                    'district': '',
                    'city': '',
                    'locality': '', 
                    'pincode': ''
                }]
            })
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)


def pincode_lookup(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    pincode = _normalize_pincode(request.GET.get('pincode', ''))
    if len(pincode) != 6:
        return JsonResponse({'error': 'Please provide a valid 6-digit pincode.'}, status=400)

    location = lookup_indian_pincode(pincode)
    if not location:
        return JsonResponse({'error': 'Could not fetch city/state for this pincode.'}, status=404)

    return JsonResponse(location)

@login_required
def city_admin_dashboard_view(request):
    """City Admin Dashboard View"""
    if not request.user.is_superuser:
        try:
            city_admin = CityAdmin.objects.get(user=request.user)
            return city_admin_dashboard(request, city_admin)
        except CityAdmin.DoesNotExist:
            return redirect('user_dashboard')
    
    # For superuser, show all city admins
    city_admins = CityAdmin.objects.all()
    if city_admins.exists():
        return city_admin_dashboard(request, city_admins.first())
    
    return redirect('super_admin_dashboard')

@login_required
def city_admin_problems(request):
    """City Admin Problems/Complaints View"""
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
        
        # Get all complaints for this city admin's city and state
        complaints = Complaint.objects.filter(
            city__iexact=city_admin.city_name,
            state__iexact=city_admin.state
        ).order_by('-created_at')
        
        # Filter by status if requested
        status_filter = request.GET.get('status')
        if status_filter:
            complaints = complaints.filter(work_status=status_filter)
        
        # Filter by category if requested
        category_filter = request.GET.get('category')
        if category_filter:
            complaints = complaints.filter(complaint_type=category_filter)
        
        # Filter by department if requested
        dept_filter = request.GET.get('department')
        if dept_filter:
            complaints = complaints.filter(assigned_department__id=dept_filter)
        
        departments = Department.objects.filter(city_admin=city_admin)
        
        # Get unique complaint types for filters
        complaint_types = Complaint.COMPLAINT_TYPES
        
        context = {
            'complaints': complaints,
            'departments': departments,
            'city_admin': city_admin,
            'status_filter': status_filter,
            'category_filter': category_filter,
            'dept_filter': dept_filter,
            'complaint_types': complaint_types,
        }
        
        return render(request, 'city_admin_problems.html', context)
        
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')

@login_required
def city_admin_review(request):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')

    admin_city = city_admin.city_name
    admin_state = city_admin.state
    
    base_complaints = Complaint.objects.filter(city__iexact=admin_city, state__iexact=admin_state)

    category_filter = request.GET.get('category', '').strip()

    filtered_complaints = base_complaints
    if category_filter:
        filtered_complaints = filtered_complaints.filter(complaint_type=category_filter)

    solved_complaints = (
        filtered_complaints
        .filter(work_status='solved')
        .select_related('assigned_department')
        .prefetch_related('resolution_proofs')
        .order_by('-resolved_at', '-updated_at')
    )

    total_count = filtered_complaints.count()
    solved_count = solved_complaints.count()

    solve_ratio = 0
    if total_count > 0:
        solve_ratio = round((solved_count / total_count) * 100, 1)

    rated_complaints = solved_complaints.filter(citizen_rating__isnull=False)
    rated_count = rated_complaints.count()
    
    avg_rating = 0
    if rated_count > 0:
        avg_rating = round(rated_complaints.aggregate(models.Avg('citizen_rating'))['citizen_rating__avg'], 1)

    positive_feedback_count = rated_complaints.filter(citizen_rating__gte=4).count()
    positive_ratio = 0
    if rated_count > 0:
        positive_ratio = round((positive_feedback_count / rated_count) * 100, 1)

    complaint_types = get_active_category_choices()
    category_rows = []
    for cat_key, cat_label in complaint_types:
        cat_total = base_complaints.filter(complaint_type=cat_key).count()
        if cat_total == 0: continue
        
        cat_solved = base_complaints.filter(complaint_type=cat_key, work_status='solved').count()
        cat_solve_ratio = round((cat_solved / cat_total) * 100, 1) if cat_total > 0 else 0
        
        cat_rated = base_complaints.filter(complaint_type=cat_key, citizen_rating__isnull=False).count()
        cat_avg = base_complaints.filter(complaint_type=cat_key, citizen_rating__isnull=False).aggregate(models.Avg('citizen_rating'))['citizen_rating__avg']
        cat_avg = round(cat_avg, 1) if cat_avg else 0
        
        cat_pos = base_complaints.filter(complaint_type=cat_key, citizen_rating__gte=4).count()
        cat_pos_ratio = round((cat_pos / cat_rated) * 100, 1) if cat_rated > 0 else 0
        
        category_rows.append({
            'key': cat_key,
            'label': cat_label,
            'total': cat_total,
            'solved': cat_solved,
            'solve_ratio': cat_solve_ratio,
            'rated': cat_rated,
            'avg_rating': cat_avg,
            'positive_ratio': cat_pos_ratio
        })

    context = {
        'page_title': 'City Review Analytics',
        'solved_complaints': solved_complaints,
        'total_count': total_count,
        'solved_count': solved_count,
        'solve_ratio': solve_ratio,
        'avg_rating': avg_rating,
        'positive_ratio': positive_ratio,
        'category_rows': category_rows,
        'complaint_types': complaint_types,
        'category_filter': category_filter,
        'admin_city': admin_city,
        'admin_state': admin_state,
        'city_admin': city_admin,
    }

    return render(request, 'city_admin_review.html', context)

@login_required
def city_admin_solved(request):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')
    
    base_complaints = Complaint.objects.filter(
        city__iexact=city_admin.city_name,
        state__iexact=city_admin.state,
        work_status='solved'
    )
    
    category_filter = request.GET.get('category', '').strip()
    complaints = base_complaints
    if category_filter:
        complaints = complaints.filter(complaint_type=category_filter)
    
    complaints = complaints.order_by('-resolved_at')
    
    context = {
        'complaints': complaints,
        'category_filter': category_filter,
        'complaint_types': get_active_category_choices(),
        'page_title': 'Solved Problems',
        'city_admin': city_admin,
    }
    return render(request, 'city_admin_solved.html', context)

@login_required
def city_admin_total(request):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')
    
    base_complaints = Complaint.objects.filter(
        city__iexact=city_admin.city_name,
        state__iexact=city_admin.state
    )

    category_filter = request.GET.get('category', '').strip()
    status_filter = request.GET.get('status', '').strip()

    complaints = base_complaints
    if category_filter:
        complaints = complaints.filter(complaint_type=category_filter)
    if status_filter:
        complaints = complaints.filter(work_status=status_filter)
        
    complaints = complaints.order_by('-created_at')
    
    context = {
        'complaints': complaints,
        'category_filter': category_filter,
        'status_filter': status_filter,
        'complaint_types': get_active_category_choices(),
        'page_title': 'Total Problems',
        'city_admin': city_admin,
    }
    return render(request, 'city_admin_total.html', context)

@login_required
def city_admin_departments(request):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')
    
    departments = Department.objects.filter(city_admin=city_admin).order_by('name')
    department_filter = request.GET.get('department', '').strip()
    
    if department_filter:
        departments = departments.filter(department_type=department_filter)

    department_list = []
    total_active = 0
    total_inactive = 0
    overall_total_complaints = 0

    for dept in departments:
        if dept.is_active:
            total_active += 1
        else:
            total_inactive += 1

        dept_complaints = Complaint.objects.filter(assigned_department=dept)
        total = dept_complaints.count()
        overall_total_complaints += total
        solved = dept_complaints.filter(work_status='solved').count()
        pending = dept_complaints.filter(work_status='pending').count()
        process = dept_complaints.filter(work_status='process').count()
        
        avg_rating = dept_complaints.filter(citizen_rating__isnull=False).aggregate(models.Avg('citizen_rating'))['citizen_rating__avg'] or 0
        
        department_list.append({
            'obj': dept,
            'total': total,
            'solved': solved,
            'pending': pending,
            'process': process,
            'avg_rating': round(avg_rating, 1),
            'solve_ratio': round((solved / total * 100), 1) if total > 0 else 0
        })

    context = {
        'departments': department_list,
        'department_filter': department_filter,
        'department_types': Department.DEPARTMENT_TYPES,
        'page_title': 'City Departments',
        'city_admin': city_admin,
        'total_departments': departments.count(),
        'active_departments': total_active,
        'inactive_departments': total_inactive,
        'total_complaints': overall_total_complaints,
    }
    return render(request, 'city_admin_departments.html', context)

@login_required
def city_admin_add_department(request):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')

    valid_department_types = {value for value, _label in Department.DEPARTMENT_TYPES}

    if request.method == 'POST':
        form_data = {
            'name': request.POST.get('name', '').strip(),
            'department_type': request.POST.get('department_type', '').strip(),
            'unique_id': request.POST.get('unique_id', '').strip(),
            'email': request.POST.get('email', '').strip(),
            'phone': request.POST.get('phone', '').strip(),
            'address': request.POST.get('address', '').strip(),
            'sla_hours': request.POST.get('sla_hours', '72').strip() or '72',
            'latitude': request.POST.get('latitude', '').strip() or '20.5937',
            'longitude': request.POST.get('longitude', '').strip() or '78.9629',
            'department_password': request.POST.get('department_password', '').strip(),
            'is_active': request.POST.get('is_active') == 'on',
        }

        # Validate
        if not form_data['name']:
            messages.error(request, 'Department name is required.')
        elif not form_data['department_type'] or form_data['department_type'] not in valid_department_types:
            messages.error(request, 'Valid department category is required.')
        elif not form_data['email']:
            messages.error(request, 'Email is required.')
        elif User.objects.filter(email=form_data['email']).exists():
            messages.error(request, 'A user with this email already exists.')
        elif not form_data['department_password']:
            messages.error(request, 'Password is required.')
        else:
            try:
                with transaction.atomic():
                    # Create Django User first
                    dept_user = User.objects.create_user(
                        username=form_data['email'],
                        email=form_data['email'],
                        password=form_data['department_password'],
                        first_name=form_data['name'][:30],  # Limit to 30 chars for Django User
                        last_name='Department'
                    )

                    # Create Department
                    department = Department.objects.create(
                        city_admin=city_admin,
                        name=form_data['name'],
                        department_type=form_data['department_type'],
                        unique_id=form_data['unique_id'],
                        email=form_data['email'],
                        phone=form_data['phone'],
                        address=form_data['address'],
                        latitude=form_data['latitude'],
                        longitude=form_data['longitude'],
                        sla_hours=form_data['sla_hours'],
                        state=city_admin.state,
                        city=city_admin.city_name,
                        is_active=form_data['is_active']
                    )

                    # Create DepartmentUser linking the User to Department
                    DepartmentUser.objects.create(
                        user=dept_user,
                        department=department,
                        role='Officer'
                    )

                    # Handle Logo
                    if 'department_logo' in request.FILES:
                        department.logo = request.FILES['department_logo']
                        department.save()

                    messages.success(request, f'Department "{department.name}" created successfully.')
                    return redirect('city_admin_departments')
            except Exception as e:
                messages.error(request, f'Error creating department: {str(e)}')

    generated_code = _generate_unique_department_code()
    generated_password = generate_strong_password(12)

    context = {
        'city_admin': city_admin,
        'department_types': Department.DEPARTMENT_TYPES,
        'page_title': 'Add New Department',
        'generated_code': generated_code,
        'generated_password': generated_password,
    }
    return render(request, 'city_admin_add_department.html', context)

@login_required
def city_admin_edit_department(request, department_id):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')

    department = get_object_or_404(Department, id=department_id, city_admin=city_admin)
    valid_department_types = {value for value, _label in Department.DEPARTMENT_TYPES}

    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        department_type = request.POST.get('department_type', '').strip()
        unique_id = request.POST.get('unique_id', '').strip()
        email = request.POST.get('email', '').strip()
        phone = request.POST.get('phone', '').strip()
        address = request.POST.get('address', '').strip()
        sla_hours = request.POST.get('sla_hours', '72').strip() or '72'
        latitude = request.POST.get('latitude', '').strip()
        longitude = request.POST.get('longitude', '').strip()
        is_active = request.POST.get('is_active') == 'on'

        # Validate
        if not name:
            messages.error(request, 'Department name is required.')
        elif not department_type or department_type not in valid_department_types:
            messages.error(request, 'Valid department category is required.')
        elif not email:
            messages.error(request, 'Email is required.')
        elif Department.objects.exclude(id=department.id).filter(unique_id=unique_id).exists():
            messages.error(request, 'Department code already exists. Please choose another.')
        else:
            try:
                with transaction.atomic():
                    # Update Department User email if it changed
                    dept_user = DepartmentUser.objects.filter(department=department).first()
                    if dept_user and dept_user.user.email != email:
                        if User.objects.filter(email=email).exclude(id=dept_user.user.id).exists():
                            messages.error(request, 'A user with this email already exists.')
                            return redirect('city_admin_edit_department', department_id=department.id)
                        dept_user.user.email = email
                        dept_user.user.username = email  # Update username to match email
                        dept_user.user.save()

                    # Update Department
                    department.name = name
                    department.department_type = department_type
                    department.unique_id = unique_id
                    department.email = email
                    department.phone = phone
                    department.address = address
                    if latitude: department.latitude = latitude
                    if longitude: department.longitude = longitude
                    department.sla_hours = sla_hours
                    department.is_active = is_active

                    # Handle Logo
                    if request.POST.get('remove_logo') == '1' and department.logo:
                        department.logo.delete(save=False)
                        department.logo = None

                    if 'department_logo' in request.FILES:
                        if department.logo:
                            department.logo.delete(save=False)
                        department.logo = request.FILES['department_logo']

                    department.save()

                    messages.success(request, f'Department "{department.name}" updated successfully.')
                    return redirect('city_admin_departments')
            except Exception as e:
                messages.error(request, f'Error updating department: {str(e)}')

    context = {
        'city_admin': city_admin,
        'department': department,
        'department_types': Department.DEPARTMENT_TYPES,
        'page_title': f'Edit {department.name}',
    }
    return render(request, 'city_admin_edit_department.html', context)

@login_required
def city_admin_delete_department(request, department_id):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')

    department = get_object_or_404(Department, id=department_id, city_admin=city_admin)
    
    # Check if department has complaints
    if Complaint.objects.filter(assigned_department=department).exists():
        messages.error(request, 'Cannot delete department as it has associated complaints. Try deactivating it instead.')
        return redirect('city_admin_departments')

    try:
        dept_user_obj = DepartmentUser.objects.filter(department=department).first()
        department.delete()
        if dept_user_obj and dept_user_obj.user:
            dept_user_obj.user.delete()  # This will also delete the DepartmentUser due to CASCADE
        messages.success(request, 'Department deleted successfully.')
    except Exception as e:
        messages.error(request, f'Error deleting department: {str(e)}')
    
    return redirect('city_admin_departments')

@login_required
def city_admin_citizens(request):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')
    
    # Filter users who have made complaints in this city OR have a profile in this city
    users_with_complaints = Complaint.objects.filter(
        city__iexact=city_admin.city_name,
        state__iexact=city_admin.state
    ).values_list('user_id', flat=True).distinct()
    
    users = User.objects.filter(
        models.Q(id__in=users_with_complaints) | 
        models.Q(citizenprofile__city__iexact=city_admin.city_name, citizenprofile__state__iexact=city_admin.state)
    ).distinct().order_by('-date_joined')
    
    search_query = request.GET.get('search', '').strip()
    if search_query:
        users = users.filter(
            models.Q(first_name__icontains=search_query) |
            models.Q(last_name__icontains=search_query) |
            models.Q(email__icontains=search_query) |
            models.Q(citizenprofile__mobile_no__icontains=search_query)
        )
    
    context = {
        'users': users,
        'search_query': search_query,
        'page_title': 'City Citizens',
        'city_admin': city_admin,
    }
    return render(request, 'city_admin_citizens.html', context)

@login_required
def city_admin_analytics(request):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')
        
    # Get departments for this city admin
    departments = Department.objects.filter(
        city_admin=city_admin,
        is_active=True
    ).exclude(latitude__isnull=True).exclude(longitude__isnull=True)
    
    # Get complaints for this city admin
    complaints = Complaint.objects.filter(
        city__iexact=city_admin.city_name,
        state__iexact=city_admin.state
    ).exclude(latitude__isnull=True).exclude(longitude__isnull=True)
    
    # Filters
    map_type = request.GET.get('map_type', 'complaints').strip()
    category_filter = request.GET.get('category', '').strip()
    status_filter = request.GET.get('status', '').strip()
    department_filter = request.GET.get('department', '').strip()
    date_from = request.GET.get('date_from', '').strip()
    date_to = request.GET.get('date_to', '').strip()
    
    # Apply filters to departments as well
    filtered_departments = departments
    if department_filter:
        filtered_departments = filtered_departments.filter(id=department_filter)
    
    # Apply filters to complaints
    filtered_complaints = complaints
    if category_filter:
        filtered_complaints = filtered_complaints.filter(complaint_type=category_filter)
    if status_filter:
        filtered_complaints = filtered_complaints.filter(work_status=status_filter)
    if department_filter:
        filtered_complaints = filtered_complaints.filter(assigned_department__id=department_filter)
    
    # Date filters
    if date_from:
        try:
            from_date = datetime.strptime(date_from, '%Y-%m-%d').date()
            filtered_complaints = filtered_complaints.filter(created_at__date__gte=from_date)
        except ValueError:
            pass
    if date_to:
        try:
            to_date = datetime.strptime(date_to, '%Y-%m-%d').date()
            filtered_complaints = filtered_complaints.filter(created_at__date__lte=to_date)
        except ValueError:
            pass

    # Prepare data based on map type
    heat_points = []
    marker_points = []
    department_points = []
    
    if map_type == 'complaints':
        # Complaints heatmap
        intensity_map = {
            'pending': 1.0,
            'reopened': 0.9,
            'confirmed': 0.7,
            'process': 0.6,
            'solved': 0.3,
            'rejected': 0.2,
        }

        for c in filtered_complaints:
            try:
                lat, lng = float(c.latitude), float(c.longitude)
                heat_points.append([lat, lng, intensity_map.get(c.work_status, 0.5)])
                marker_points.append({
                    'lat': lat, 'lng': lng,
                    'number': c.complaint_number,
                    'title': c.title,
                    'status': c.get_work_status_display(),
                    'type': c.get_complaint_type_display(),
                    'department': c.assigned_department.name if c.assigned_department else 'Not Assigned',
                    'created_at': c.created_at.strftime('%Y-%m-%d %H:%M'),
                    'marker_type': 'complaint'
                })
            except: continue
    
    elif map_type == 'departments':
        # Department locations
        for dept in filtered_departments:
            try:
                lat, lng = float(dept.latitude), float(dept.longitude)
                # Count complaints for this department
                dept_complaints = complaints.filter(assigned_department=dept)
                total_complaints = dept_complaints.count()
                pending_complaints = dept_complaints.filter(work_status__in=['pending', 'confirmed', 'process', 'reopened']).count()
                solved_complaints = dept_complaints.filter(work_status='solved').count()
                
                department_points.append({
                    'lat': lat, 'lng': lng,
                    'department_id': dept.id,
                    'name': dept.name,
                    'type': dept.get_department_type_display(),
                    'email': dept.email,
                    'phone': dept.phone,
                    'address': dept.address,
                    'total_complaints': total_complaints,
                    'pending_complaints': pending_complaints,
                    'solved_complaints': solved_complaints,
                    'sla_hours': dept.sla_hours,
                    'marker_type': 'department'
                })
            except: continue
    
    elif map_type == 'combined':
        # Both complaints and departments
        intensity_map = {
            'pending': 1.0,
            'reopened': 0.9,
            'confirmed': 0.7,
            'process': 0.6,
            'solved': 0.3,
            'rejected': 0.2,
        }

        # Add complaints
        for c in filtered_complaints:
            try:
                lat, lng = float(c.latitude), float(c.longitude)
                heat_points.append([lat, lng, intensity_map.get(c.work_status, 0.5)])
                marker_points.append({
                    'lat': lat, 'lng': lng,
                    'number': c.complaint_number,
                    'title': c.title,
                    'status': c.get_work_status_display(),
                    'type': c.get_complaint_type_display(),
                    'department': c.assigned_department.name if c.assigned_department else 'Not Assigned',
                    'created_at': c.created_at.strftime('%Y-%m-%d %H:%M'),
                    'marker_type': 'complaint'
                })
            except: continue
        
        # Add departments
        for dept in filtered_departments:
            try:
                lat, lng = float(dept.latitude), float(dept.longitude)
                dept_complaints = complaints.filter(assigned_department=dept)
                total_complaints = dept_complaints.count()
                pending_complaints = dept_complaints.filter(work_status__in=['pending', 'confirmed', 'process', 'reopened']).count()
                solved_complaints = dept_complaints.filter(work_status='solved').count()
                
                department_points.append({
                    'lat': lat, 'lng': lng,
                    'department_id': dept.id,
                    'name': dept.name,
                    'type': dept.get_department_type_display(),
                    'email': dept.email,
                    'phone': dept.phone,
                    'address': dept.address,
                    'total_complaints': total_complaints,
                    'pending_complaints': pending_complaints,
                    'solved_complaints': solved_complaints,
                    'sla_hours': dept.sla_hours,
                    'marker_type': 'department'
                })
            except: continue
    
    # Statistics
    total_points = len(marker_points) + len(department_points)
    status_counts = {
        row['work_status']: row['total']
        for row in filtered_complaints.values('work_status').annotate(total=Count('id'))
    }

    context = {
        'heat_points_json': json.dumps(heat_points),
        'marker_points_json': json.dumps(marker_points),
        'department_points_json': json.dumps(department_points),
        'total_points': total_points,
        'status_counts': status_counts,
        'map_type': map_type,
        'category_filter': category_filter,
        'status_filter': status_filter,
        'department_filter': department_filter,
        'date_from': date_from,
        'date_to': date_to,
        'complaint_types': Complaint.COMPLAINT_TYPES,
        'departments': departments,
        'page_title': 'City Analytics',
        'city_admin': city_admin,
        'city_name': city_admin.city_name,
        'state_name': city_admin.state,
    }
    return render(request, 'city_admin_analytics.html', context)


@login_required
@require_http_methods(["POST"])
def city_admin_update_password(request):
    """Handle city admin password updates via old password or OTP"""
    try:
        city_admin = CityAdmin.objects.get(user=request.user)
    except CityAdmin.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Access denied'}, status=403)
    
    try:
        data = json.loads(request.body)
        method = data.get('method')
        
        if method == 'old_password':
            current_password = data.get('current_password')
            new_password = data.get('new_password')
            
            if not current_password or not new_password:
                return JsonResponse({'success': False, 'message': 'All fields are required'})
            
            # Verify current password
            if not check_password(current_password, request.user.password):
                return JsonResponse({'success': False, 'message': 'Current password is incorrect'})
            
            # Update password
            request.user.set_password(new_password)
            request.user.save()
            
            return JsonResponse({'success': True, 'message': 'Password updated successfully'})
        
        elif method == 'send_otp':
            # Send OTP to user's email
            otp = generate_otp()
            OTP.objects.filter(email=request.user.email, is_verified=False).delete()
            OTP.objects.create(email=request.user.email, otp=otp)
            
            send_otp_email(request.user.email, otp)
            
            return JsonResponse({'success': True, 'message': 'OTP sent to your email'})
        
        elif method == 'otp_verify':
            otp_code = data.get('otp')
            new_password = data.get('new_password')
            
            if not otp_code or not new_password:
                return JsonResponse({'success': False, 'message': 'All fields are required'})
            
            # Verify OTP
            try:
                otp_obj = OTP.objects.get(
                    email=request.user.email,
                    otp=otp_code,
                    is_verified=False
                )
                
                # Check if OTP is expired (10 minutes)
                if timezone.now() - otp_obj.created_at > timedelta(minutes=10):
                    otp_obj.delete()
                    return JsonResponse({'success': False, 'message': 'OTP expired. Please request a new one'})
                
                # Update password
                request.user.set_password(new_password)
                request.user.save()
                
                # Mark OTP as verified
                otp_obj.is_verified = True
                otp_obj.save()
                
                return JsonResponse({'success': True, 'message': 'Password updated successfully'})
                
            except OTP.DoesNotExist:
                return JsonResponse({'success': False, 'message': 'Invalid OTP'})
        
        else:
            return JsonResponse({'success': False, 'message': 'Invalid method'})
    
    except json.JSONDecodeError:
        return JsonResponse({'success': False, 'message': 'Invalid request data'})
    except Exception as e:
        return JsonResponse({'success': False, 'message': 'An error occurred'})

def translation_test(request):
    """Test view for translations"""
    return render(request, 'translation_test.html')

def dynamic_fields_test(request):
    """Test view for dynamic fields"""
    return render(request, 'dynamic_fields_test.html')

@login_required
def city_admin_department_detail(request, department_id):
    try:
        if request.user.is_superuser:
            city_admin = CityAdmin.objects.first()
        else:
            city_admin = CityAdmin.objects.get(user=request.user)
        
        if not city_admin:
            return redirect('user_dashboard')
    except CityAdmin.DoesNotExist:
        return redirect('user_dashboard')

    # Get department and verify it belongs to this city admin
    department = get_object_or_404(Department, id=department_id, city_admin=city_admin)
    
    # Get department statistics
    dept_complaints = Complaint.objects.filter(assigned_department=department)
    total_complaints = dept_complaints.count()
    pending_complaints = dept_complaints.filter(work_status__in=['pending', 'confirmed', 'process', 'reopened']).count()
    solved_complaints = dept_complaints.filter(work_status='solved').count()
    
    # Calculate average rating
    rated_complaints = dept_complaints.filter(citizen_rating__isnull=False)
    avg_rating = rated_complaints.aggregate(models.Avg('citizen_rating'))['citizen_rating__avg'] or 0
    
    # Get recent complaints (last 10)
    recent_complaints = dept_complaints.order_by('-created_at')[:10]
    
    context = {
        'department': department,
        'city_admin': city_admin,
        'total_complaints': total_complaints,
        'pending_complaints': pending_complaints,
        'solved_complaints': solved_complaints,
        'avg_rating': avg_rating,
        'recent_complaints': recent_complaints,
        'page_title': f'{department.name} - Department Details',
    }
    
    return render(request, 'city_admin_department_detail.html', context)

@login_required
@login_required
def super_admin_delete_user(request, user_id):
    if not request.user.is_superuser:
        messages.error(request, 'Permission denied.')
        return redirect('user_dashboard')
    
    user_to_delete = get_object_or_404(User, id=user_id)
    
    # Don't allow deleting yourself
    if user_to_delete == request.user:
        messages.error(request, 'You cannot delete your own super admin account.')
        return redirect('super_admin_users')
    
    # Safety check: Don't allow deleting other superusers through this view
    if user_to_delete.is_superuser:
        messages.error(request, 'You cannot delete another superuser through this dashboard.')
        return redirect('super_admin_users')
        
    username = user_to_delete.username
    user_to_delete.delete()
    
    messages.success(request, f'User {username} and all their associated data have been deleted.')
    return redirect('super_admin_users')

def user_view_department(request, department_type):
    """View department details page"""
    # Get departments of the specified type
    departments = Department.objects.filter(
        department_type=department_type,
        is_active=True
    ).select_related('city_admin')
    
    # If no departments found, redirect back to dashboard
    if not departments.exists():
        messages.error(request, f'No {department_type} departments found.')
        return redirect('user_dashboard')
    
    # Get the first department for display (you can modify this logic)
    department = departments.first()
    
    # Get complaint statistics for this department type
    dept_complaints = Complaint.objects.filter(assigned_department__in=departments)
    total_complaints = dept_complaints.count()
    pending_complaints = dept_complaints.filter(work_status='pending').count()
    solved_complaints = dept_complaints.filter(work_status='solved').count()
    
    context = {
        'department': department,
        'departments': departments,
        'department_type': department_type,
        'total_complaints': total_complaints,
        'pending_complaints': pending_complaints,
        'solved_complaints': solved_complaints,
    }
    
    return render(request, 'user_view_department.html', context)

def forgot_password(request):
    if request.method == 'POST':
        email = request.POST.get('email', '').strip().lower()
        
        if not email:
            messages.error(request, 'Please enter your email address.')
            return render(request, 'forgot_password.html')
        
        try:
            validate_email(email)
        except ValidationError:
            messages.error(request, 'Please enter a valid email address.')
            return render(request, 'forgot_password.html')
        
        # Always show success message immediately for security (don't reveal if email exists)
        messages.success(request, f'If {email} is registered as a department account, a password reset email will be sent shortly.')
        
        # Send email in background thread
        from threading import Thread
        from django.core.mail import EmailMultiAlternatives
        
        def send_reset_email():
            try:
                # Check if email belongs to a department user
                user = User.objects.get(email__iexact=email)
                dept_user = DepartmentUser.objects.get(user=user)
                department = dept_user.department
                
                # Generate a new password
                new_password = generate_strong_password(12)
                user.set_password(new_password)
                user.save()
                
                # Send email with department details and new password
                subject = 'Smart City Department Password Reset'
                
                # HTML email content with glassmorphism design
                html_content = f"""
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Password Reset</title>
                    <style>
                        body {{
                            margin: 0;
                            padding: 0;
                            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                            background: linear-gradient(135deg, #f39c12 0%, #e67e22 100%);
                            min-height: 100vh;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                        }}
                        .email-container {{
                            max-width: 650px;
                            margin: 20px;
                            background: rgba(255, 255, 255, 0.25);
                            backdrop-filter: blur(20px);
                            -webkit-backdrop-filter: blur(20px);
                            border-radius: 20px;
                            border: 1px solid rgba(255, 255, 255, 0.3);
                            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                            overflow: hidden;
                        }}
                        .header {{
                            background: rgba(255, 255, 255, 0.1);
                            padding: 30px;
                            text-align: center;
                            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
                        }}
                        .logo {{
                            font-size: 48px;
                            color: #ffffff;
                            margin-bottom: 10px;
                        }}
                        .title {{
                            color: #ffffff;
                            font-size: 28px;
                            font-weight: 700;
                            margin: 0;
                            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                        }}
                        .subtitle {{
                            color: rgba(255, 255, 255, 0.9);
                            font-size: 16px;
                            margin: 5px 0 0 0;
                        }}
                        .content {{
                            padding: 30px;
                        }}
                        .alert-message {{
                            background: rgba(239, 68, 68, 0.2);
                            border: 1px solid rgba(239, 68, 68, 0.3);
                            border-radius: 15px;
                            padding: 20px;
                            margin: 20px 0;
                            color: #ffffff;
                            text-align: center;
                            font-size: 16px;
                        }}
                        .info-section {{
                            background: rgba(255, 255, 255, 0.9);
                            border-radius: 15px;
                            padding: 25px;
                            margin: 20px 0;
                            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
                        }}
                        .section-title {{
                            color: #f39c12;
                            font-size: 20px;
                            font-weight: 700;
                            margin-bottom: 15px;
                            display: flex;
                            align-items: center;
                            gap: 10px;
                        }}
                        .info-grid {{
                            display: grid;
                            grid-template-columns: 1fr 1fr;
                            gap: 15px;
                            margin-bottom: 15px;
                        }}
                        .info-item {{
                            display: flex;
                            flex-direction: column;
                        }}
                        .info-label {{
                            color: #64748b;
                            font-size: 12px;
                            font-weight: 600;
                            text-transform: uppercase;
                            letter-spacing: 0.5px;
                            margin-bottom: 5px;
                        }}
                        .info-value {{
                            color: #1e293b;
                            font-size: 16px;
                            font-weight: 600;
                        }}
                        .credentials-box {{
                            background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                            color: #ffffff;
                            border-radius: 15px;
                            padding: 25px;
                            margin: 20px 0;
                            text-align: center;
                            box-shadow: 0 4px 15px rgba(16, 185, 129, 0.3);
                        }}
                        .credentials-title {{
                            font-size: 20px;
                            font-weight: 700;
                            margin-bottom: 15px;
                        }}
                        .credential-item {{
                            background: rgba(255, 255, 255, 0.2);
                            border-radius: 10px;
                            padding: 15px;
                            margin: 10px 0;
                            text-align: left;
                        }}
                        .credential-label {{
                            font-size: 12px;
                            opacity: 0.9;
                            margin-bottom: 5px;
                        }}
                        .credential-value {{
                            font-size: 16px;
                            font-weight: 700;
                            word-break: break-all;
                        }}
                        .security-note {{
                            background: rgba(59, 130, 246, 0.2);
                            border: 1px solid rgba(59, 130, 246, 0.3);
                            border-radius: 10px;
                            padding: 15px;
                            margin: 20px 0;
                            color: #ffffff;
                            font-size: 14px;
                            text-align: center;
                        }}
                        .footer {{
                            background: rgba(0, 0, 0, 0.1);
                            padding: 20px 30px;
                            text-align: center;
                            border-top: 1px solid rgba(255, 255, 255, 0.2);
                        }}
                        .footer-text {{
                            color: rgba(255, 255, 255, 0.8);
                            font-size: 14px;
                            margin: 0;
                        }}
                        @media (max-width: 600px) {{
                            .info-grid {{ grid-template-columns: 1fr; }}
                            .email-container {{ margin: 10px; }}
                            .content {{ padding: 20px; }}
                        }}
                    </style>
                </head>
                <body>
                    <div class="email-container">
                        <div class="header">
                            <div class="logo">🔑</div>
                            <h1 class="title">PASSWORD RESET</h1>
                            <p class="subtitle">Department Account Security</p>
                        </div>
                        <div class="content">
                            <div class="alert-message">
                                ⚠️ <strong>Security Alert:</strong> Your department password has been reset as requested.
                            </div>
                            
                            <div class="info-section">
                                <div class="section-title">
                                    🏢 Department Information
                                </div>
                                <div class="info-grid">
                                    <div class="info-item">
                                        <div class="info-label">Department Name</div>
                                        <div class="info-value">{department.name}</div>
                                    </div>
                                    <div class="info-item">
                                        <div class="info-label">Department Code</div>
                                        <div class="info-value">#{department.unique_id}</div>
                                    </div>
                                    <div class="info-item">
                                        <div class="info-label">Category</div>
                                        <div class="info-value">{department.get_department_type_display()}</div>
                                    </div>
                                    <div class="info-item">
                                        <div class="info-label">Location</div>
                                        <div class="info-value">{department.city}, {department.state}</div>
                                    </div>
                                </div>
                                <div class="info-grid">
                                    <div class="info-item">
                                        <div class="info-label">Phone</div>
                                        <div class="info-value">{department.phone}</div>
                                    </div>
                                    <div class="info-item">
                                        <div class="info-label">Email</div>
                                        <div class="info-value">{department.email}</div>
                                    </div>
                                </div>
                                <div class="info-item" style="grid-column: 1 / -1;">
                                    <div class="info-label">Office Address</div>
                                    <div class="info-value">{department.address}</div>
                                </div>
                            </div>
                            
                            <div class="credentials-box">
                                <div class="credentials-title">🆕 New Login Credentials</div>
                                <div class="credential-item">
                                    <div class="credential-label">Login Email</div>
                                    <div class="credential-value">{email}</div>
                                </div>
                                <div class="credential-item">
                                    <div class="credential-label">New Password</div>
                                    <div class="credential-value">{new_password}</div>
                                </div>
                            </div>
                            
                            <div class="security-note">
                                🔒 <strong>Important Security Steps:</strong><br>
                                1. Log in immediately and change this password<br>
                                2. Use a strong, unique password<br>
                                3. If you didn't request this reset, contact your administrator immediately
                            </div>
                        </div>
                        <div class="footer">
                            <p class="footer-text">
                                © 2024 Smart City Portal | Secure Department Access
                            </p>
                        </div>
                    </div>
                </body>
                </html>
                """
                
                # Plain text fallback
                text_content = f'''
Hello {user.get_full_name() or user.username},

Your password has been reset for your department account.

Department Details:
Department Name: {department.name}
Department Code: {department.unique_id}
Department Type: {department.get_department_type_display()}
State: {department.state}
City: {department.city}
Office Address: {department.address}
Contact Email: {department.email}
Contact Phone: {department.phone}

Login Credentials:
Email: {email}
New Password: {new_password}

Please log in and change your password after first login.

If you did not request this password reset, please contact your administrator immediately.
'''
                
                msg = EmailMultiAlternatives(subject, text_content, 'noreply@smartcity.com', [email])
                msg.attach_alternative(html_content, "text/html")
                msg.send(fail_silently=True)
                
            except (User.DoesNotExist, DepartmentUser.DoesNotExist):
                # Silently fail for security - don't reveal if email exists or not
                pass
            except Exception:
                # Silently fail - don't reveal errors
                pass
        
        # Start background thread
        Thread(target=send_reset_email, daemon=True).start()
        
        # Redirect immediately without waiting for email
        return redirect('login')
    
    return render(request, 'forgot_password.html')
