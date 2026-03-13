# Email URL Configuration - JanHelp

## Overview
All email templates now use your live URL: **https://janhelp.vercel.app**

## Changes Made

### 1. Settings Configuration
**File:** `smartcity/settings.py`

Added BASE_URL setting:
```python
# Base URL for emails and links
BASE_URL = os.getenv('BASE_URL', 'https://janhelp.vercel.app')
```

### 2. Vercel Environment Variable
**File:** `vercel.json`

Added to environment variables:
```json
"BASE_URL": "https://janhelp.vercel.app"
```

### 3. Email Utility Functions
**File:** `complaints/email_utils.py`

All email functions now use `settings.BASE_URL`:
- ✅ `send_otp_email()` - OTP verification
- ✅ `send_welcome_email()` - Welcome emails
- ✅ `send_complaint_status_email()` - Status updates
- ✅ `send_complaint_resolved_email()` - Resolution notifications
- ✅ `send_department_assignment_email()` - Department access
- ✅ `send_department_credentials_email()` - Department login
- ✅ `send_city_admin_credentials_email()` - City admin login
- ✅ `send_password_reset_credentials_email()` - Password reset

## Email Links Generated

### 1. OTP Email
- **Purpose:** User verification
- **Links:** None (just OTP code)

### 2. Welcome Email
- **Purpose:** New user registration
- **Links:**
  - Dashboard: `https://janhelp.vercel.app/dashboard/`

### 3. Complaint Status Email
- **Purpose:** Complaint updates
- **Links:**
  - Complaint Detail: `https://janhelp.vercel.app/complaint/{complaint_number}/`
  - Track Page: `https://janhelp.vercel.app/track/`

### 4. Complaint Resolved Email
- **Purpose:** Complaint resolution
- **Links:**
  - Complaint Detail: `https://janhelp.vercel.app/complaint/{complaint_number}/`
  - Rating Page: `https://janhelp.vercel.app/complaint/{complaint_number}/rate/`
  - Dashboard: `https://janhelp.vercel.app/dashboard/`

### 5. Department Credentials Email
- **Purpose:** Department account creation
- **Links:**
  - Login Page: `https://janhelp.vercel.app/login/`

### 6. City Admin Credentials Email
- **Purpose:** City admin account creation
- **Links:**
  - Login Page: `https://janhelp.vercel.app/login/`

### 7. Department Assignment Email
- **Purpose:** Department access notification
- **Links:**
  - Login Page: `https://janhelp.vercel.app/login/`

### 8. Password Reset Email
- **Purpose:** Password reset confirmation
- **Links:**
  - Login Page: `https://janhelp.vercel.app/login/`

## Email Templates

All templates are located in: `templates/emails/`

### Template Structure
```
templates/emails/
├── base_email.html                    # Base template
├── otp_email.html                     # OTP verification
├── welcome_email.html                 # Welcome message
├── complaint_status_email.html        # Status updates
├── complaint_resolved_email.html      # Resolution notification
├── department_credentials.html        # Department login
├── city_admin_credentials.html        # City admin login
├── department_assignment_email.html   # Department access
└── password_reset_credentials.html    # Password reset
```

### Base Template Features
- Professional design
- Responsive layout
- JanHelp branding
- Consistent styling
- Mobile-friendly

## Testing Emails

### Local Testing
```python
# In Django shell
from complaints.email_utils import send_otp_email

# Test OTP email
send_otp_email('test@example.com', '123456', 'Test User')

# Check console output for email content
```

### Production Testing
```bash
# After deployment
# Register a new user or trigger any email action
# Check your email inbox
```

## Email Service Configuration

### Current Setup
**File:** `smartcity/settings.py`

```python
EMAIL_BACKEND = os.getenv('EMAIL_BACKEND', 'django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST = os.getenv('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.getenv('EMAIL_PORT', 587))
EMAIL_USE_TLS = os.getenv('EMAIL_USE_TLS', 'True') == 'True'
EMAIL_HOST_USER = os.getenv('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER
```

### Environment Variables Needed
Add these to Vercel environment variables:
```
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
```

## URL Patterns in Emails

### Pattern 1: Dashboard
```
https://janhelp.vercel.app/dashboard/
```
**Used in:**
- Welcome email
- Complaint resolved email

### Pattern 2: Login
```
https://janhelp.vercel.app/login/
```
**Used in:**
- Department credentials
- City admin credentials
- Department assignment
- Password reset

### Pattern 3: Complaint Detail
```
https://janhelp.vercel.app/complaint/{complaint_number}/
```
**Used in:**
- Complaint status email
- Complaint resolved email

### Pattern 4: Track Complaints
```
https://janhelp.vercel.app/track/
```
**Used in:**
- Complaint status email

### Pattern 5: Rate Complaint
```
https://janhelp.vercel.app/complaint/{complaint_number}/rate/
```
**Used in:**
- Complaint resolved email

## Deployment Checklist

### ✅ Before Deployment
- [x] BASE_URL added to settings.py
- [x] BASE_URL added to vercel.json
- [x] Email templates use base_url variable
- [x] Email utility functions updated

### ✅ After Deployment
- [ ] Test OTP email
- [ ] Test welcome email
- [ ] Test complaint status email
- [ ] Test department credentials email
- [ ] Verify all links work
- [ ] Check email formatting
- [ ] Test on mobile devices

## Troubleshooting

### Issue: Links show localhost
**Solution:** Ensure BASE_URL is set in Vercel environment variables

### Issue: Emails not sending
**Solution:** Check EMAIL_HOST_USER and EMAIL_HOST_PASSWORD in Vercel

### Issue: Links broken
**Solution:** Verify URL patterns match your Django URLs

### Issue: Email formatting broken
**Solution:** Check email client (Gmail, Outlook, etc.)

## Email Preview

### Sample OTP Email
```
Subject: Your OTP Code: 123456 - JanHelp

Dear User,

For security purposes, please use the following one-time password (OTP):

┌─────────────────┐
│   1 2 3 4 5 6   │
└─────────────────┘

This code will expire in 10 minutes.

Security Notice: Do not share this code with anyone.
```

### Sample Welcome Email
```
Subject: Welcome to JanHelp! 🎉

Dear John Doe,

Welcome to the JanHelp Smart City Portal!

Registered Email: john@example.com
Registration Date: 2024-01-15

[Access My Dashboard]
→ https://janhelp.vercel.app/dashboard/
```

### Sample Complaint Status Email
```
Subject: Complaint #SC123456 Status Update - JanHelp

Dear John Doe,

Your complaint has been updated:

Complaint ID: #SC123456
Status: In Progress
Department: Traffic Department
Updated: 2024-01-15

[Track Complaint Progress]
→ https://janhelp.vercel.app/complaint/SC123456/
```

## Security Considerations

### 1. HTTPS Only
- ✅ All links use HTTPS
- ✅ Secure connection for user data

### 2. Email Verification
- ✅ OTP expires in 10 minutes
- ✅ One-time use only

### 3. Password Security
- ✅ Passwords never shown in plain text (except initial setup)
- ✅ Strong password requirements

### 4. Link Validation
- ✅ All links point to official domain
- ✅ No external redirects

## Monitoring

### Email Delivery
Check Vercel logs for email sending:
```bash
vercel logs --follow
```

Look for:
```
[Email] Successfully sent 'OTP Code' to user@example.com
[Email] Successfully sent 'Welcome' to user@example.com
```

### Failed Emails
```
[Email] Error sending email to user@example.com: [error message]
```

## Future Enhancements

### Possible Additions
1. **Email Templates**
   - Add more templates for different scenarios
   - Multilingual support
   - Custom branding per city

2. **Email Tracking**
   - Track email opens
   - Track link clicks
   - Delivery reports

3. **Email Queue**
   - Background email sending
   - Retry failed emails
   - Bulk email support

4. **Email Preferences**
   - User email preferences
   - Notification settings
   - Unsubscribe options

## Support

### Common Questions

**Q: Can I change the BASE_URL?**
A: Yes, update it in Vercel environment variables

**Q: How to test emails locally?**
A: Use console backend or configure SMTP

**Q: Are emails mobile-friendly?**
A: Yes, all templates are responsive

**Q: Can I customize email templates?**
A: Yes, edit files in `templates/emails/`

## Summary

✅ **Configuration Complete**
- BASE_URL set to https://janhelp.vercel.app
- All email templates updated
- All links point to live site
- Ready for production use

🎉 **Ready to Deploy**
- Commit changes
- Push to Vercel
- Test email functionality
- Monitor delivery

---

**Live URL:** https://janhelp.vercel.app
**Email Templates:** `templates/emails/`
**Configuration:** `smartcity/settings.py`
**Status:** ✅ Production Ready
