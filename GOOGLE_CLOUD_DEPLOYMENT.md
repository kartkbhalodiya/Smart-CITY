# 🚀 GOOGLE CLOUD DEPLOYMENT GUIDE - JANHELP
# Deploy Django Backend on Cloud Run (FREE TIER)

## 📋 PREREQUISITES

1. ✅ Google Account (Gmail)
2. ✅ Credit/Debit card (for verification - won't be charged)
3. ✅ Your project files (already have ✓)

---

## STEP 1: CREATE GOOGLE CLOUD ACCOUNT

### 1. Go to: https://console.cloud.google.com

### 2. Sign in with your Gmail account

### 3. Click "Activate Free Trial" or "Get Started for Free"
   - Enter your billing information (for verification only)
   - You get **$300 free credits** for 90 days
   - Your card **WON'T be charged** automatically

### 4. Complete the setup wizard

---

## STEP 2: INSTALL GOOGLE CLOUD CLI

### For Windows:

1. Download Google Cloud SDK installer:
   https://cloud.google.com/sdk/docs/install#windows

2. Run the installer (GoogleCloudSDKInstaller.exe)

3. Follow the installation wizard:
   - ✅ Check "Install Git for Windows"
   - ✅ Check "Run 'gcloud init'"

4. Restart your terminal/PowerShell after installation

5. Verify installation:
```powershell
gcloud --version
```

You should see:
```
Google Cloud SDK xxx.x.x
...
```

---

## STEP 3: INITIALIZE GCLOUD

### 1. Login to Google Cloud:
```powershell
gcloud auth login
```
- Browser will open
- Select your Google account
- Click "Allow"

### 2. Set your project:
```powershell
# Create a new project
gcloud projects create janhelp-smart-city --name="JanHelp Smart City"

# Set as default project
gcloud config set project janhelp-smart-city
```

### 3. Enable required APIs:
```powershell
# Enable Cloud Run API
gcloud services enable run.googleapis.com

# Enable Cloud Build API
gcloud services enable cloudbuild.googleapis.com

# Enable Container Registry API
gcloud services enable containerregistry.googleapis.com

# Enable Artifact Registry API
gcloud services enable artifactregistry.googleapis.com
```

This will take 2-3 minutes. Wait for confirmation!

---

## STEP 4: PREPARE YOUR PROJECT

### 1. Navigate to your project folder:
```powershell
cd "c:\Users\bhalo\Documents\GitHub\Smart CITY"
```

### 2. Create `.gcloudignore` file:
```powershell
# Create .gcloudignore
@"
.git
.github
.venv
.env
__pycache__
*.pyc
*.pyo
*.pyd
.Python
pip-log.txt
pip-delete-this-directory.txt
.tox/
.coverage
.pytest_cache/
node_modules/
*.log
db.sqlite3
"@ | Out-File -FilePath .gcloudignore -Encoding utf8
```

### 3. Update Dockerfile (already good, but let's verify):
```powershell
# Your Dockerfile is already perfect! ✓
```

### 4. Create `app.yaml` for Cloud Run settings (OPTIONAL):
```powershell
@"
runtime: python313
env: flex

# Cloud Run automatically handles this
"@ | Out-File -FilePath app.yaml -Encoding utf8
```

---

## STEP 5: SET ENVIRONMENT VARIABLES

### Create `.env.yaml` for Cloud Run secrets:
```powershell
@"
env_variables:
  DEBUG: 'False'
  ALLOWED_HOSTS: '*'
  SECRET_KEY: 'your-secret-key-change-this-in-production'
  DATABASE_URL: 'your-database-url-here'
  CLOUDINARY_URL: 'cloudinary://your-cloudinary-url'
  GEMINI_API_KEY: 'your-new-gemini-key-here'
"@ | Out-File -FilePath .env.yaml -Encoding utf8
```

**⚠️ IMPORTANT:** 
- Replace all placeholder values with your actual keys
- Get new API keys (old ones are exposed!)
- Never commit `.env.yaml` to Git

---

## STEP 6: DEPLOY TO CLOUD RUN! 🚀

### Method A: Automatic Deploy (EASIEST)

```powershell
# Navigate to project
cd "c:\Users\bhalo\Documents\GitHub\Smart CITY"

# Deploy to Cloud Run
gcloud run deploy janhelp-backend `
  --source . `
  --platform managed `
  --region us-central1 `
  --allow-unauthenticated `
  --port 8000 `
  --memory 512Mi `
  --cpu 1 `
  --min-instances 0 `
  --max-instances 10 `
  --env-vars-file .env.yaml
```

### What this does:
- ✅ Builds your Docker image automatically
- ✅ Uploads to Google Container Registry
- ✅ Deploys to Cloud Run
- ✅ Gives you a public HTTPS URL
- ✅ Auto-scales from 0 to 10 instances
- ✅ FREE for 2 million requests/month

### Expected output:
```
Building using Dockerfile and deploying container to Cloud Run service [janhelp-backend]...
✓ Building and deploying... Done.
✓ Uploading sources
✓ Building Container
✓ Creating Revision
✓ Routing traffic
Done.
Service [janhelp-backend] revision [janhelp-backend-00001-abc] has been deployed
and is serving 100 percent of traffic.
Service URL: https://janhelp-backend-xxxxx-uc.a.run.app
```

### 🎉 **YOUR APP IS LIVE!**

---

## STEP 7: SET UP DATABASE (FREE OPTIONS)

### Option A: Supabase (FREE - Recommended)

1. Go to: https://supabase.com
2. Sign up with GitHub
3. Create new project: "janhelp-db"
4. Get connection string from Settings → Database
5. Update `.env.yaml` with DATABASE_URL

### Option B: Google Cloud SQL (Costs $7/month)

```powershell
# Create PostgreSQL instance
gcloud sql instances create janhelp-db `
  --database-version=POSTGRES_15 `
  --tier=db-f1-micro `
  --region=us-central1

# Create database
gcloud sql databases create janhelp `
  --instance=janhelp-db

# Get connection name
gcloud sql instances describe janhelp-db --format="value(connectionName)"
```

---

## STEP 8: RUN MIGRATIONS

### Connect to your deployed app:

```powershell
# Get your Cloud Run URL
gcloud run services describe janhelp-backend --region us-central1 --format="value(status.url)"

# Run migrations (one-time job)
gcloud run jobs create janhelp-migrate `
  --image gcr.io/janhelp-smart-city/janhelp-backend `
  --region us-central1 `
  --command python `
  --args "manage.py,migrate"

# Execute migration
gcloud run jobs execute janhelp-migrate --region us-central1
```

---

## STEP 9: VERIFY DEPLOYMENT ✅

### 1. Test your API:
```powershell
# Get service URL
$SERVICE_URL = gcloud run services describe janhelp-backend --region us-central1 --format="value(status.url)"

# Test endpoint
curl "$SERVICE_URL/api/"
```

### 2. Check logs:
```powershell
gcloud run services logs read janhelp-backend --region us-central1 --limit 50
```

### 3. Visit in browser:
```
https://janhelp-backend-xxxxx-uc.a.run.app
```

---

## STEP 10: DEPLOY FLUTTER MOBILE APP (OPTIONAL)

### For Flutter Web on Firebase Hosting (FREE):

```powershell
# Navigate to Flutter project
cd smartcity_application

# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase
firebase init hosting

# Build Flutter web
flutter build web

# Deploy
firebase deploy
```

---

## 🎯 COST BREAKDOWN (FREE TIER)

| Service | Free Tier | Your Usage | Monthly Cost |
|---------|-----------|------------|--------------|
| **Cloud Run** | 2M requests | ~10K | **$0** ✓ |
| **Cloud Build** | 120 min/day | ~10 min | **$0** ✓ |
| **Container Registry** | 0.5 GB storage | ~200 MB | **$0** ✓ |
| **Cloud Storage** | 5 GB | ~2 GB | **$0** ✓ |
| **Gemini API** | Pay-per-use | ~1000 calls | **~$2-5** |
| **Supabase DB** | FREE tier | 500 MB | **$0** ✓ |

**TOTAL: $2-5/month** (within $300 free credits!) 🎉

---

## 🔧 TROUBLESHOOTING

### Error: "Permission denied"
```powershell
gcloud auth login
gcloud config set project janhelp-smart-city
```

### Error: "Port already in use"
- Dockerfile uses PORT from environment (Cloud Run sets this automatically)
- No action needed!

### Error: "Build failed"
```powershell
# Check logs
gcloud builds list --limit=5
gcloud builds log [BUILD_ID]
```

### Error: "Service Unavailable"
```powershell
# Check service status
gcloud run services describe janhelp-backend --region us-central1

# View logs
gcloud run services logs read janhelp-backend --region us-central1
```

---

## 📊 MONITOR YOUR APP

### View metrics:
```powershell
# Open Cloud Console
gcloud run services describe janhelp-backend --region us-central1 --format="value(status.url)"
```

### Set up alerts:
1. Go to: https://console.cloud.google.com/monitoring
2. Create alerting policy for:
   - Request latency > 5s
   - Error rate > 5%
   - Memory usage > 80%

---

## 🔄 UPDATE YOUR DEPLOYMENT

### When you make code changes:

```powershell
# 1. Commit changes to Git
git add .
git commit -m "Update feature"

# 2. Redeploy to Cloud Run (same command as before)
gcloud run deploy janhelp-backend `
  --source . `
  --platform managed `
  --region us-central1 `
  --allow-unauthenticated

# Cloud Run will automatically:
# - Rebuild your container
# - Create new revision
# - Route traffic to new version
# - Keep old version as backup
```

### Rollback if needed:
```powershell
# List revisions
gcloud run revisions list --service janhelp-backend --region us-central1

# Route traffic to previous revision
gcloud run services update-traffic janhelp-backend `
  --region us-central1 `
  --to-revisions janhelp-backend-00001=100
```

---

## 🎓 NEXT STEPS

1. **Custom Domain** (Optional):
   ```powershell
   gcloud run domain-mappings create --service janhelp-backend --domain janhelps.in
   ```

2. **CI/CD with GitHub Actions**:
   - Auto-deploy on git push
   - See: https://cloud.google.com/run/docs/continuous-deployment-with-github-actions

3. **Add Cloud CDN**:
   - Speed up static files
   - Reduce costs

4. **Set up monitoring**:
   - Cloud Monitoring
   - Error reporting
   - Performance insights

---

## 📞 SUPPORT

**Google Cloud Support:**
- Free tier: Community support only
- Docs: https://cloud.google.com/run/docs
- Discord: https://discord.gg/google-cloud

**Issues?**
- Check logs: `gcloud run services logs read janhelp-backend --region us-central1`
- Stack Overflow: Tag `google-cloud-run`

---

## ✅ FINAL CHECKLIST

Before submitting to hackathon:

- [ ] Deployed on Cloud Run
- [ ] API is accessible via HTTPS
- [ ] Database connected (Supabase/Cloud SQL)
- [ ] Environment variables set
- [ ] Migrations run successfully
- [ ] Test API endpoints work
- [ ] Get deployment URL for submission
- [ ] Screenshot Cloud Console dashboard
- [ ] Update HACKATHON_SUBMISSION.md with URL

---

**🎉 CONGRATULATIONS! YOUR APP IS ON GOOGLE CLOUD!**

Your deployment URL will be like:
```
https://janhelp-backend-xxxxx-uc.a.run.app
```

Use this URL in your hackathon submission! 🚀

