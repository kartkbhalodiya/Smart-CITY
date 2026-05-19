# Vercel Deployment

This repository deploys to Vercel as a Django backend through `api/index.py`.
The Flutter app in `smartcity_application/` is a separate client and is excluded from the Vercel Python function bundle.

## Vercel Project Settings

- Root Directory: `./`
- Framework Preset: Other
- Install Command: `pip install -r requirements.txt`
- Build Command: `python manage.py collectstatic --noinput`
- Output Directory: leave empty

These values are also encoded in `vercel.json`.

Large non-backend folders are excluded from the deployment upload through `.vercelignore`.

## Required Environment Variables

Set these in Vercel Project Settings before deploying:

```env
SECRET_KEY=generate-a-new-django-secret-key
DEBUG=False
ALLOWED_HOSTS=janhelp.vercel.app,your-custom-domain.com
CSRF_TRUSTED_ORIGINS=https://janhelp.vercel.app,https://your-custom-domain.com
BASE_URL=https://janhelp.vercel.app
DATABASE_URL=postgres://USER:PASSWORD@HOST:5432/DBNAME
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
GEMINI_API_KEY=your-gemini-key
GEMINI_MODEL=gemini-2.5-flash
```

Optional:

```env
RESEND_API_KEY=your-resend-api-key
DEFAULT_FROM_EMAIL=noreply@your-domain.com
REDIS_URL=redis://USER:PASSWORD@HOST:6379
MAPPLE_API_KEY=your-mappls-key
CITYFIX_LLM_URL=https://kartik1911-cityfix-llm.hf.space
```

## Deploy Commands

```powershell
vercel build
vercel deploy --prebuilt
vercel deploy --prod --prebuilt
```

After the first production deploy, run migrations against the production database from a trusted local shell:

```powershell
$env:DATABASE_URL="postgres://USER:PASSWORD@HOST:5432/DBNAME"
python manage.py migrate
python manage.py createsuperuser
```

## Verification

Use the database-free health endpoint first:

```powershell
curl https://janhelp.vercel.app/api/health/
```

Expected shape:

```json
{"success":true,"status":"ok","service":"smartcity","runtime":"vercel"}
```

Do not use SQLite for production on Vercel. Serverless filesystems are ephemeral and not a durable database.
