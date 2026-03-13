# 🚀 Quick Deploy - Email URL Update

## What Changed?

All email links now use your live URL: **https://janhelp.vercel.app**

## Files Modified

1. ✅ `smartcity/settings.py` - Added BASE_URL setting
2. ✅ `vercel.json` - Added BASE_URL environment variable
3. ✅ `complaints/email_utils.py` - Already using BASE_URL (no changes needed)

## Deploy Steps (2 minutes)

### 1️⃣ Commit Changes
```bash
git add smartcity/settings.py vercel.json
git commit -m "Configure email URLs for production (janhelp.vercel.app)"
git push
```

### 2️⃣ Wait for Vercel Deploy
- Check: https://vercel.com/dashboard
- Wait for: "Deployment Ready" ✅

### 3️⃣ Test Email Links
Test any email trigger:
- Register new user
- Submit complaint
- Reset password

Check email for links like:
- ✅ https://janhelp.vercel.app/dashboard/
- ✅ https://janhelp.vercel.app/login/
- ✅ https://janhelp.vercel.app/complaint/SC123456/

## Email Links Updated

| Email Type | Links |
|------------|-------|
| OTP | None (just code) |
| Welcome | Dashboard |
| Complaint Status | Complaint detail, Track page |
| Complaint Resolved | Complaint detail, Rating, Dashboard |
| Department Credentials | Login page |
| City Admin Credentials | Login page |
| Password Reset | Login page |

## Verify It Works

### Test 1: Register New User
1. Go to: https://janhelp.vercel.app/register/
2. Register with your email
3. Check email for OTP
4. After verification, check welcome email
5. Click "Access My Dashboard" link
6. Should go to: https://janhelp.vercel.app/dashboard/

### Test 2: Submit Complaint
1. Submit a complaint
2. Check status update email
3. Click "Track Complaint Progress" link
4. Should go to: https://janhelp.vercel.app/complaint/[number]/

### Test 3: Department Login
1. Create department account (as admin)
2. Check credentials email
3. Click "Access Department Dashboard" link
4. Should go to: https://janhelp.vercel.app/login/

## Environment Variables

### Already Set in vercel.json ✅
```json
"BASE_URL": "https://janhelp.vercel.app"
```

### Optional: Set in Vercel Dashboard
If you want to change it later:
1. Go to: https://vercel.com/dashboard
2. Select your project
3. Settings → Environment Variables
4. Add: `BASE_URL` = `https://janhelp.vercel.app`

## Troubleshooting

### Issue: Links still show localhost
**Solution:**
```bash
# Redeploy
git commit --allow-empty -m "Trigger redeploy"
git push
```

### Issue: Emails not sending
**Solution:** Check email configuration in Vercel:
- EMAIL_HOST_USER
- EMAIL_HOST_PASSWORD
- EMAIL_HOST
- EMAIL_PORT

### Issue: 404 on email links
**Solution:** Verify URL patterns in Django:
```python
# Check urls.py
path('dashboard/', views.user_dashboard, name='user_dashboard'),
path('login/', views.login_view, name='login'),
path('complaint/<str:complaint_number>/', views.complaint_detail),
```

## Quick Test Commands

### Test Email Locally
```python
# Django shell
python manage.py shell

from complaints.email_utils import send_otp_email
send_otp_email('your-email@example.com', '123456', 'Test User')
```

### Check BASE_URL
```python
# Django shell
from django.conf import settings
print(settings.BASE_URL)
# Should print: https://janhelp.vercel.app
```

## Summary

✅ **What's Done:**
- BASE_URL configured
- All emails use live URL
- Ready for production

🎯 **Next Steps:**
1. Commit and push
2. Wait for deployment
3. Test email links
4. Verify all work

⏱️ **Time Required:** 2 minutes
📧 **Emails Affected:** All 8 email types
🔗 **Links Updated:** All email links

---

**Your Live Site:** https://janhelp.vercel.app
**Status:** ✅ Ready to Deploy
