# Vercel Deployment Fix Guide

## Issues Fixed:
1. DEBUG mode configuration
2. Cloudinary conditional loading
3. Static files handling
4. Python runtime compatibility

## Required Steps:

### 1. Set Environment Variables in Vercel Dashboard

Go to your Vercel project settings → Environment Variables and add:

**Required:**
```
SECRET_KEY=p!v^7+h!j= e0#u%7_@1-n*6&z(5)s#4f$j_r!m2%v@9#k8&l5)s1$f4
DEBUG=False
ALLOWED_HOSTS=janhelp.vercel.app,*.vercel.app
```

**Database (Supabase):**
```
DATABASE_URL=postgres://postgres:Kartik%409089361130@db.aaywhmjmsdkjzabtzfpg.supabase.co:5432/postgres
DB_PASSWORD=Kartik@9089361130
DB_HOST=db.aaywhmjmsdkjzabtzfpg.supabase.co
DB_PORT=5432
DB_USER=postgres
DB_NAME=postgres
```

**Email:**
```
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=academix111@gmail.com
EMAIL_HOST_PASSWORD=gpxw wkdy odsz czav
EMAIL_USE_TLS=True
```

**Cloudinary (Optional - for media uploads):**
```
CLOUDINARY_CLOUD_NAME=dk1q50evg
CLOUDINARY_API_KEY=284539188155248
CLOUDINARY_API_SECRET=C1RW6ViwtH4RZspIlRi6LSa-wBw
```

**CSRF:**
```
CSRF_TRUSTED_ORIGINS=https://janhelp.vercel.app,https://*.vercel.app
```

### 2. Deploy to Vercel

After setting environment variables:

```bash
# Commit changes
git add .
git commit -m "Fix Vercel deployment configuration"
git push origin main
```

Vercel will automatically redeploy.

### 3. Check Deployment Logs

If still getting errors:
1. Go to Vercel Dashboard → Your Project → Deployments
2. Click on the latest deployment
3. Check "Build Logs" and "Function Logs" for specific errors

### 4. Common Issues:

**If database connection fails:**
- Ensure Supabase allows connections from Vercel IPs
- Check if DATABASE_URL is correctly formatted
- Verify database credentials

**If static files don't load:**
- Run `python manage.py collectstatic` locally first
- Commit the staticfiles directory
- Or use Cloudinary for static files

**If still getting 500 errors:**
- Set `DEBUG=True` temporarily in Vercel env vars to see detailed error
- Check Function Logs in Vercel dashboard
- Ensure all migrations are applied

### 5. Test Locally with Production Settings:

```bash
# Set environment variables
set DEBUG=False
set DATABASE_URL=your_database_url

# Collect static files
python manage.py collectstatic --noinput

# Run server
python manage.py runserver
```

## Quick Fix for Immediate Testing:

Set these minimal environment variables in Vercel:
```
DEBUG=True
SECRET_KEY=p!v^7+h!j= e0#u%7_@1-n*6&z(5)s#4f$j_r!m2%v@9#k8&l5)s1$f4
ALLOWED_HOSTS=*
```

This will show you the actual error message.
