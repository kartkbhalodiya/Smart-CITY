# Vercel Deployment

This repository deploys to Vercel as a Django backend through `api/index.py`.
The Flutter app in `smartcity_application/` is a separate client and is excluded from the Vercel Python function bundle.

## Vercel Project Settings

- Root Directory: `./`
- Framework Preset: Other
- Install Command: leave empty
- Build Command: `python scripts/vercel_build.py`
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
DATABASE_URL=postgres://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres
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

`DATABASE_URL` must be available to Vercel for both build and runtime. For Supabase on Vercel, do not use a placeholder such as `host`, and do not use the direct `db.PROJECT_REF.supabase.co:5432` URL. Supabase direct database hosts resolve to IPv6, while Vercel serverless needs an IPv4-compatible Supavisor pooler URL. Use the Supabase dashboard: Project -> Connect -> Connection string -> Transaction pooler.

The build script runs `python manage.py migrate --noinput`; without a valid pooler `DATABASE_URL`, Vercel now fails the build instead of deploying pages that crash with `Server Error (500)`.

Leave `REDIS_URL` unset unless `django-redis` is added back to `requirements.txt`.

## Deploy Commands

```powershell
vercel build
vercel deploy --prebuilt
vercel deploy --prod --prebuilt
```

If you need to repair an already-deployed database manually, run migrations against the production database from a trusted local shell:

```powershell
$env:DATABASE_URL="postgres://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres"
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
