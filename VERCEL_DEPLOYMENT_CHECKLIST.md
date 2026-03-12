# Vercel Deployment Checklist for Django

## Pre-Deployment Checklist

### 1. Environment Variables ✅
- [ ] All required environment variables set in Vercel dashboard
- [ ] No sensitive data in vercel.json (move to dashboard)
- [ ] DATABASE_URL configured (if using database)
- [ ] CLOUDINARY credentials (all 3: CLOUD_NAME, API_KEY, API_SECRET)
- [ ] SECRET_KEY is unique and secure
- [ ] DEBUG = False

### 2. Static Files Configuration ✅
- [ ] STATICFILES_DIRS is empty when using Cloudinary
- [ ] STATIC_ROOT is None when using Cloudinary
- [ ] Whitenoise middleware removed when using Cloudinary
- [ ] static/ directory in .vercelignore

### 3. Database Configuration ✅
- [ ] Using PostgreSQL (not SQLite)
- [ ] DATABASE_URL environment variable set
- [ ] Migrations run on database
- [ ] Database accessible from Vercel (firewall rules)

### 4. File Storage ✅
- [ ] Using cloud storage (Cloudinary/S3) for media files
- [ ] MEDIA_ROOT not used on Vercel
- [ ] File uploads go to cloud storage

### 5. Dependencies ✅
- [ ] requirements.txt up to date
- [ ] All dependencies compatible with Python 3.9
- [ ] No local-only dependencies (e.g., sqlite3)

### 6. Vercel Configuration ✅
- [ ] vercel.json properly configured
- [ ] .vercelignore includes unnecessary files
- [ ] Python version specified (.python-version file)
- [ ] maxLambdaSize appropriate for your app

### 7. Django Settings ✅
- [ ] ALLOWED_HOSTS = ['*'] or specific domains
- [ ] CSRF_TRUSTED_ORIGINS includes your domain
- [ ] SECURE_PROXY_SSL_HEADER configured
- [ ] No hardcoded filesystem paths

---

## Common Issues and Solutions

### Issue 1: FUNCTION_INVOCATION_FAILED

**Symptoms:**
- 500 error on all pages
- "This Serverless Function has crashed"

**Causes:**
1. Missing environment variables
2. STATICFILES_DIRS pointing to non-existent directory
3. Database connection failure
4. Import errors

**Solutions:**
1. Check Vercel logs: `vercel logs --follow`
2. Verify environment variables in dashboard
3. Set STATICFILES_DIRS = [] when using Cloudinary
4. Test database connection

---

### Issue 2: Static Files Not Loading

**Symptoms:**
- Pages load but no CSS/JS
- 404 errors for /static/* files

**Causes:**
1. Cloudinary not configured
2. Static files not uploaded to Cloudinary
3. STATIC_URL incorrect

**Solutions:**
1. Verify Cloudinary credentials
2. Run `python manage.py collectstatic` locally
3. Check STATIC_URL = "static/" (no leading slash)

---

### Issue 3: Database Connection Timeout

**Symptoms:**
- Slow page loads
- Timeout errors
- "could not connect to server"

**Causes:**
1. IPv6 connection issues
2. Database firewall blocking Vercel
3. Wrong DATABASE_URL

**Solutions:**
1. Use IPv4 hostname (already patched in settings.py)
2. Add Vercel IPs to database firewall
3. Verify DATABASE_URL format

---

### Issue 4: Import Errors

**Symptoms:**
- "ModuleNotFoundError"
- "No module named 'X'"

**Causes:**
1. Missing dependency in requirements.txt
2. Local-only package
3. Wrong Python version

**Solutions:**
1. Run `pip freeze > requirements.txt`
2. Remove local-only packages
3. Verify Python version in vercel.json

---

## Testing Before Deployment

### Local Testing with Production Settings

```bash
# 1. Create .env.production
cp .env .env.production

# 2. Set production values
# Edit .env.production:
DEBUG=False
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
DATABASE_URL=your-database-url

# 3. Test with production settings
export $(cat .env.production | xargs)
python manage.py check --deploy
python manage.py runserver

# 4. Check for errors
# - Static files loading?
# - Database connected?
# - No warnings?
```

### Vercel Preview Deployment

```bash
# Deploy to preview environment
vercel

# Test preview URL
# Check logs
vercel logs --follow

# If successful, deploy to production
vercel --prod
```

---

## Deployment Commands

### Initial Deployment
```bash
# 1. Install Vercel CLI
npm i -g vercel

# 2. Login
vercel login

# 3. Link project
vercel link

# 4. Set environment variables
vercel env add SECRET_KEY
vercel env add CLOUDINARY_CLOUD_NAME
vercel env add CLOUDINARY_API_KEY
vercel env add CLOUDINARY_API_SECRET
vercel env add DATABASE_URL

# 5. Deploy
vercel --prod
```

### Update Deployment
```bash
# Commit changes
git add .
git commit -m "Your changes"
git push

# Vercel auto-deploys from Git
# Or manually deploy:
vercel --prod
```

---

## Monitoring and Debugging

### View Logs
```bash
# Real-time logs
vercel logs --follow

# Recent logs
vercel logs

# Specific deployment
vercel logs [deployment-url]
```

### Check Deployment Status
```bash
# List deployments
vercel ls

# Inspect specific deployment
vercel inspect [deployment-url]
```

### Rollback
```bash
# Rollback to previous deployment
vercel rollback

# Or promote specific deployment
vercel promote [deployment-url]
```

---

## Performance Optimization

### 1. Reduce Lambda Size
- Remove unused dependencies
- Use .vercelignore aggressively
- Increase maxLambdaSize if needed

### 2. Database Connection Pooling
```python
# settings.py
DATABASES = {
    'default': {
        'CONN_MAX_AGE': 600,  # Keep connections for 10 minutes
    }
}
```

### 3. Caching
```python
# Use in-memory cache (not filesystem)
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}
```

### 4. Static Files on CDN
- Use Cloudinary for all static files
- Enable Cloudinary CDN
- Set long cache headers

---

## Security Checklist

- [ ] SECRET_KEY is unique and not in Git
- [ ] DEBUG = False in production
- [ ] ALLOWED_HOSTS configured
- [ ] CSRF_TRUSTED_ORIGINS includes your domain
- [ ] SECURE_SSL_REDIRECT = False (Vercel handles SSL)
- [ ] SESSION_COOKIE_SECURE = True
- [ ] CSRF_COOKIE_SECURE = True
- [ ] Database credentials not in Git
- [ ] API keys not in Git
- [ ] Environment variables in Vercel dashboard (not vercel.json)

---

## Troubleshooting Decision Tree

```
Deployment fails?
├─ Build fails?
│  ├─ Check requirements.txt
│  ├─ Check Python version
│  └─ Check vercel.json syntax
│
├─ Function invocation fails?
│  ├─ Check environment variables
│  ├─ Check STATICFILES_DIRS
│  ├─ Check database connection
│  └─ Check Vercel logs
│
├─ Static files not loading?
│  ├─ Check Cloudinary credentials
│  ├─ Check STATIC_URL
│  └─ Run collectstatic
│
└─ Slow/timeout?
   ├─ Check database connection
   ├─ Check CONN_MAX_AGE
   └─ Check Lambda size
```

---

## Quick Reference

### Required Environment Variables
```
SECRET_KEY=your-secret-key
DEBUG=False
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
DATABASE_URL=postgres://user:pass@host:5432/db
```

### Required Files
- `vercel.json` - Vercel configuration
- `.vercelignore` - Files to ignore
- `.python-version` - Python version
- `requirements.txt` - Dependencies
- `smartcity/wsgi.py` - WSGI application

### Important Settings
```python
# When using Cloudinary on Vercel
CLOUDINARY_ENABLED = True
STATICFILES_DIRS = []
STATIC_ROOT = None
MIDDLEWARE = [...]  # No Whitenoise
```

---

## Getting Help

1. **Vercel Logs**: `vercel logs --follow`
2. **Vercel Docs**: https://vercel.com/docs
3. **Django Deployment**: https://docs.djangoproject.com/en/stable/howto/deployment/
4. **Cloudinary Docs**: https://cloudinary.com/documentation/django_integration

---

## Summary

**Most common Vercel deployment issues:**
1. ❌ Missing environment variables (60%)
2. ❌ STATICFILES_DIRS pointing to non-existent directory (20%)
3. ❌ Database connection issues (10%)
4. ❌ Import/dependency errors (10%)

**Always remember:**
- Vercel = serverless = no persistent filesystem
- Use cloud storage for everything (static, media, database)
- Test with production settings locally first
- Check logs when things go wrong
