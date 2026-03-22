# Resend Email Setup Guide - FREE & FAST

## Why Resend?
- ✅ **100% FREE** - 3,000 emails/month free forever
- ✅ **Super Fast** - Delivers in seconds
- ✅ **No Credit Card** - Sign up without payment info
- ✅ **Easy Setup** - Just 2 minutes
- ✅ **Reliable** - 99.9% uptime

## Setup Steps (2 Minutes)

### Step 1: Create Resend Account
1. Go to: https://resend.com/signup
2. Sign up with your email (FREE, no credit card needed)
3. Verify your email

### Step 2: Get API Key
1. After login, go to: https://resend.com/api-keys
2. Click "Create API Key"
3. Name it: "Smart City App"
4. Copy the API key (starts with `re_`)

### Step 3: Add to .env File
Open your `.env` file and add:

```env
# Resend Email Configuration (FREE & FAST)
RESEND_API_KEY=re_your_api_key_here
DEFAULT_FROM_EMAIL=noreply@janhelps.in
```

Replace `re_your_api_key_here` with your actual API key from Step 2.

### Step 4: Verify Domain (Optional but Recommended)
1. Go to: https://resend.com/domains
2. Click "Add Domain"
3. Enter your domain: `janhelps.in`
4. Add the DNS records shown to your domain provider
5. Wait for verification (usually 5-10 minutes)

**Note:** Without domain verification, emails will be sent from `onboarding@resend.dev` but will still work!

### Step 5: Test It!
1. Restart your Django server
2. Go to Forgot Password page
3. Enter a department/admin email
4. Check your inbox - email should arrive in seconds!

## How It Works

The system now uses **Resend API** which is:
- Much faster than Gmail SMTP
- More reliable
- No daily limits (3,000 emails/month free)
- No "less secure app" issues

If Resend fails for any reason, it automatically falls back to Gmail SMTP.

## Troubleshooting

### Email Not Received?
1. Check console logs for error messages
2. Verify API key is correct in .env
3. Check spam folder
4. Make sure you restarted Django server after adding API key

### Still Using Gmail?
If you see "Sending via SMTP" in logs, it means:
- RESEND_API_KEY is not set in .env, OR
- API key is invalid

### Check Status
Look at console output when sending email:
```
[Email] Attempting to send via Resend API to user@example.com
[Email] ✓ Resend API: Email sent successfully to user@example.com
```

## Free Tier Limits
- 3,000 emails per month
- 100 emails per day
- Perfect for small to medium apps

## Need More?
Resend paid plans start at $20/month for 50,000 emails.
But 3,000 free emails should be enough for most use cases!

## Support
- Resend Docs: https://resend.com/docs
- Resend Status: https://status.resend.com
