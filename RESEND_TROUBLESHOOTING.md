# RESEND EMAIL NOT WORKING - TROUBLESHOOTING GUIDE

## Issue: Department users not receiving password reset emails

## Most Likely Causes:

### 1. **Resend Domain Not Verified** (MOST COMMON)
   - Go to: https://resend.com/domains
   - Check if `janhelps.in` domain is verified
   - If not verified, you need to add DNS records:
     - SPF record
     - DKIM record
     - DMARC record (optional)
   
   **Quick Fix**: Use Resend's test domain instead
   - Change `DEFAULT_FROM_EMAIL` in .env to: `onboarding@resend.dev`
   - This will work immediately without domain verification

### 2. **Environment Variable Not Set on Server**
   - Check Render dashboard → Environment tab
   - Verify `RESEND_API_KEY` is set: `re_dcPXW18d_9WjpDnmYLKCKn2xDzFAWNW2d`
   - Verify `DEFAULT_FROM_EMAIL` is set: `noreply@janhelps.in`

### 3. **Server Not Restarted After .env Changes**
   - Render auto-restarts on git push
   - Manual restart: Render dashboard → Manual Deploy → Deploy latest commit

## Testing Steps:

1. **Test with Resend test domain first**:
   ```
   # In .env file (both local and Render):
   DEFAULT_FROM_EMAIL=onboarding@resend.dev
   ```

2. **Push changes and test**:
   ```bash
   git add .
   git commit -m "Use Resend test domain for emails"
   git push
   ```

3. **Check server logs**:
   - Render dashboard → Logs tab
   - Look for lines starting with `[Email]` or `[Forgot Password]`

4. **If still not working, check Resend dashboard**:
   - Go to: https://resend.com/emails
   - Check if emails are being sent
   - Check delivery status

## Quick Fix (Use This Now):

Update your .env file on Render:
```
RESEND_API_KEY=re_dcPXW18d_9WjpDnmYLKCKn2xDzFAWNW2d
DEFAULT_FROM_EMAIL=onboarding@resend.dev
```

This will work immediately without domain verification!
