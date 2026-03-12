# Vercel Deployment Troubleshooting Guide

## Common Error: FUNCTION_INVOCATION_FAILED

### Quick Diagnosis Checklist

When you see `500: INTERNAL_SERVER_ERROR` with `FUNCTION_INVOCATION_FAILED`:

1. **Check Environment Variables**
   - [ ] All required variables are set in Vercel
   - [ ] No typos in variable names
   - [ ] Values are complete (not empty strings)

2. **Check Third-Party Services**
   - [ ] Cloudinary: CLOUD_NAME + API_KEY + API_SECRET (all 3 required)
   - [ ] Database: Complete connection string with password
   - [ ] Email: SMTP credentials if using email backend

3. **Check Django Configuration**
   - [ ] INSTALLED_APPS don't have missing dependencies
   - [ ] DATABASES configuration is valid
   - [ ] STATIC_ROOT and STATICFILES_DIRS exist

4. **Check Vercel Logs**
   ```bash
   vercel logs --follow
   ```

---

## Environment Variables Setup

### Method 1: Vercel Dashboard (Recommended for Production)

1. Go to: https://vercel.com/[your-username]/[project-name]/settings/environment-variables
2. Add each variable:
   - Name: `CLOUDINARY_API_KEY`
   - Value: `your-api-key`
   - Environment: Production, Preview, Development
3. Redeploy: `git commit --allow-empty -m "Trigger redeploy" && git push`

**Pros:** Secure, not in Git, different values per environment
**Cons:** Manual setup, not version controlled

---

### Method 2: vercel.json (Quick Fix)

```json
{
  "env": {
    "VARIABLE_NAME": "value"
  }
}
```

**Pros:** Quick, version controlled
**Cons:** Credentials visible in Git (security risk)

**⚠️ WARNING:** Never commit sensitive credentials to Git in production!

---

### Method 3: Vercel CLI

```bash
# Pull environment variables from Vercel
vercel env pull .env.local

# Add new variable
vercel env add VARIABLE_NAME

# Deploy
vercel --prod
```

**Pros:** Developer-friendly, syncs with dashboard
**Cons:** Requires CLI setup

---

## Validation Best Practices

### ✅ DO: Validate all required credentials

```python
# settings.py
CLOUDINARY_ENABLED = all([
    os.getenv('CLOUDINARY_CLOUD_NAME'),
    os.getenv('CLOUDINARY_API_KEY'),
    os.getenv('CLOUDINARY_API_SECRET')
])

if CLOUDINARY_ENABLED:
    INSTALLED_APPS += ['cloudinary']
else:
    # Fallback to local storage
    pass
```

### ❌ DON'T: Check only one credential

```python
# BAD - Can crash if other credentials missing
if os.getenv('CLOUDINARY_CLOUD_NAME'):
    INSTALLED_APPS += ['cloudinary']
```

---

## Debugging Steps

### 1. Check Vercel Build Logs

```bash
vercel logs --follow
```

Look for:
- Import errors
- Missing module errors
- Configuration errors
- Database connection errors

### 2. Test Locally with Production Settings

```bash
# Create .env.production
DEBUG=False
SECRET_KEY=your-production-key
CLOUDINARY_CLOUD_NAME=your-cloud-name
# ... other variables

# Test locally
python manage.py check --deploy
python manage.py runserver
```

### 3. Verify Environment Variables

```python
# Add to wsgi.py temporarily for debugging
import os
print("Environment variables:")
print(f"CLOUDINARY_CLOUD_NAME: {os.getenv('CLOUDINARY_CLOUD_NAME')}")
print(f"CLOUDINARY_API_KEY: {os.getenv('CLOUDINARY_API_KEY')[:5]}...")
print(f"DATABASE_URL: {os.getenv('DATABASE_URL')[:20]}...")
```

### 4. Check Function Size

```bash
# Vercel has a 50MB limit (configurable to 250MB)
du -sh .vercel/output/functions/
```

If too large:
- Remove unused dependencies from requirements.txt
- Use `.vercelignore` to exclude unnecessary files
- Increase `maxLambdaSize` in vercel.json

---

## Common Pitfalls

### 1. Partial Credentials
**Problem:** Only some credentials provided
**Solution:** Validate all required credentials together

### 2. .env File Ignored
**Problem:** .env in .vercelignore
**Solution:** Use Vercel dashboard or vercel.json for environment variables

### 3. Database Connection Timeout
**Problem:** IPv6 issues with some databases
**Solution:** Use IPv4 hostname or add socket patching (already in settings.py)

### 4. Static Files Not Found
**Problem:** STATIC_ROOT not collected
**Solution:** Ensure `python manage.py collectstatic` runs in build

### 5. Import Errors
**Problem:** Missing dependencies in requirements.txt
**Solution:** Run `pip freeze > requirements.txt` locally

---

## Security Checklist

- [ ] SECRET_KEY is unique and not default
- [ ] DEBUG = False in production
- [ ] ALLOWED_HOSTS configured properly
- [ ] CSRF_TRUSTED_ORIGINS includes your domain
- [ ] Database credentials not in Git
- [ ] API keys not in Git
- [ ] SECURE_SSL_REDIRECT = True (if using HTTPS)
- [ ] SESSION_COOKIE_SECURE = True
- [ ] CSRF_COOKIE_SECURE = True

---

## Quick Reference: Required Environment Variables

### Minimal (Django only)
```
SECRET_KEY=your-secret-key
DEBUG=False
```

### With Cloudinary
```
SECRET_KEY=your-secret-key
DEBUG=False
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
```

### With Database (Supabase/PostgreSQL)
```
SECRET_KEY=your-secret-key
DEBUG=False
DATABASE_URL=postgres://user:password@host:5432/dbname
```

### Full Production Setup
```
SECRET_KEY=your-secret-key
DEBUG=False
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
DATABASE_URL=postgres://user:password@host:5432/dbname
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
EMAIL_USE_TLS=True
```

---

## Testing Before Deployment

```bash
# 1. Check for errors
python manage.py check --deploy

# 2. Test with production settings
DEBUG=False python manage.py runserver

# 3. Collect static files
python manage.py collectstatic --noinput

# 4. Run migrations
python manage.py migrate

# 5. Test imports
python -c "import django; django.setup()"
```

---

## Emergency Rollback

If deployment fails:

```bash
# Rollback to previous deployment
vercel rollback

# Or redeploy specific commit
git revert HEAD
git push
```

---

## Getting Help

1. **Check Vercel Logs:** `vercel logs --follow`
2. **Check Django Logs:** Add logging to settings.py
3. **Vercel Support:** https://vercel.com/support
4. **Django Deployment Docs:** https://docs.djangoproject.com/en/stable/howto/deployment/

---

## Summary

**Most common causes of FUNCTION_INVOCATION_FAILED:**
1. ❌ Missing environment variables (80% of cases)
2. ❌ Incomplete third-party credentials (15% of cases)
3. ❌ Import/dependency errors (3% of cases)
4. ❌ Database connection issues (2% of cases)

**Always validate:**
- All required credentials are present
- Third-party services are properly configured
- Local testing with production settings works
- Environment variables are set in Vercel dashboard
