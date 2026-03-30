# FORGOT PASSWORD EMAIL FIX - COMPLETE SOLUTION

## Problem
Department users not receiving password reset emails after using forgot password feature.

## Root Causes Found & Fixed

### 1. ✅ Wrong Email Address (FIXED)
- **Issue**: Email was sent to form input `email` instead of `user.email`
- **Fix**: Changed to always use `user.email` from database
- **File**: `complaints/views.py` - `forgot_password()` function

### 2. ✅ Department Object Serialization (FIXED)
- **Issue**: Django template can't render model objects directly
- **Fix**: Serialize department to dictionary before passing to template
- **Files**: 
  - `complaints/email_utils.py` - `send_password_reset_credentials_email()`
  - `complaints/email_utils.py` - `send_department_credentials_email()`

### 3. ✅ Resend Domain Not Verified (FIXED)
- **Issue**: Custom domain `noreply@janhelps.in` not verified in Resend
- **Fix**: Changed to Resend test domain `onboarding@resend.dev`
- **Files**: 
  - `.env` - `DEFAULT_FROM_EMAIL=onboarding@resend.dev`
  - `complaints/email_utils.py` - Updated default

### 4. ✅ Email Template Updated (FIXED)
- **Issue**: Template expected model object, got dictionary
- **Fix**: Updated template to use dictionary keys
- **File**: `templates/emails/password_reset_credentials.html`

## Files Changed

1. **complaints/views.py**
   - Added comprehensive logging
   - Fixed email address to use `user.email`
   - Added try-catch for email sending

2. **complaints/email_utils.py**
   - Serialized department objects in both functions
   - Added detailed logging
   - Changed default from email to test domain

3. **templates/emails/password_reset_credentials.html**
   - Updated to display department info from dictionary
   - Added conditional display for department/city admin

4. **.env**
   - Changed `DEFAULT_FROM_EMAIL` to `onboarding@resend.dev`

## Deployment Steps

### On Render Dashboard:
1. Go to your service → **Environment** tab
2. Update/Add these variables:
   ```
   RESEND_API_KEY=re_dcPXW18d_9WjpDnmYLKCKn2xDzFAWNW2d
   DEFAULT_FROM_EMAIL=onboarding@resend.dev
   ```
3. Click **Save Changes** (auto-redeploys)

### Test the Fix:
1. Go to forgot password page
2. Enter department user email
3. Email should arrive in **1-3 seconds**
4. Check server logs for debug output

## Expected Log Output (Success)

```
[Forgot Password] Starting password reset for: dept@example.com
[Forgot Password] ✓ User found: dept_user (ID: 123)
[Forgot Password] ✓ User type: Department User
[Forgot Password] ✓ Generated new password (length: 12)
[Forgot Password] ✓ Password saved to database
[Forgot Password] ✓ Database transaction committed
[Forgot Password] ✓ Password verified successfully
[Forgot Password] ✓ Invalidated 2 existing sessions
[Forgot Password] Preparing email...
  - Recipient: dept@example.com
  - User Email (actual): dept@example.com
  - User Name: Department Name
  - New Password Length: 12
  - Department: Water Department
  - Department Email: water@city.gov
  - User Email: dept@example.com
[Forgot Password] Sending department reset email...
[send_password_reset_credentials_email] Called with:
  - email: dept@example.com
  - user_name: Department Name
  - new_password length: 12
  - department: Water Department
  - city_admin_info: False
  - Serializing department object...
  - Department serialized: Water Department
  - Calling send_email_template...
[Email] Attempting to send via Resend API to dept@example.com
[Email] DEBUG: Resend API Key present: True
[Email] DEBUG: API Key starts with: re_dcPXW18d...
[Email] ✓ Resend API: Email sent successfully to dept@example.com
  - send_email_template returned: True
[Forgot Password] Email function returned: True
[Forgot Password] ✓ Email sent successfully!
[Forgot Password] Process completed for dept@example.com
```

## If Still Not Working

1. **Check Render Logs**:
   - Look for `[Forgot Password]` and `[Email]` lines
   - Check for any error messages

2. **Verify Resend Dashboard**:
   - Go to https://resend.com/emails
   - Check if emails are being sent
   - Check delivery status

3. **Check Spam Folder**:
   - Emails from `onboarding@resend.dev` might go to spam initially

4. **Verify Environment Variables**:
   - Render dashboard → Environment tab
   - Confirm both variables are set correctly

## Future: Use Custom Domain

To use `noreply@janhelps.in` later:

1. Go to https://resend.com/domains
2. Click "Add Domain"
3. Enter `janhelps.in`
4. Add DNS records (provided by Resend):
   - SPF record
   - DKIM record
   - DMARC record (optional)
5. Wait for verification (usually 24-48 hours)
6. Update `DEFAULT_FROM_EMAIL` back to `noreply@janhelps.in`

## Summary

All fixes are complete. The issue was a combination of:
- Wrong email address being used
- Department object not serialized
- Unverified custom domain

Using Resend test domain `onboarding@resend.dev` will work immediately!
