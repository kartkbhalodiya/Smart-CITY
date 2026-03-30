# Cloudinary Upload Fix - Final Solution

## Problem
Getting 401/403 errors when uploading images to Cloudinary from Flutter app.

## Root Cause
The app was trying to use an unsigned upload preset that doesn't exist in your Cloudinary account.

## Solution Implemented

### Immediate Fix (Current)
Updated Flutter code to use unsigned upload with proper configuration:
- Cloud Name: `dk1q50evg` (from your .env)
- Upload Preset: `smartcity_complaints`
- Folder: `complaints`

### What You Need to Do

**IMPORTANT: Create the Upload Preset in Cloudinary**

1. Go to https://cloudinary.com/console
2. Login to your account
3. Click **Settings** (gear icon) → **Upload** tab
4. Scroll to **Upload presets** section
5. Click **Add upload preset**
6. Configure:
   ```
   Preset name: smartcity_complaints
   Signing Mode: Unsigned
   Folder: complaints
   Access mode: Public
   Unique filename: Yes
   ```
7. Click **Save**

### Files Modified

1. **smartcity_application/lib/screens/ai_assistant/ai_chat_screen.dart**
   - Updated `_uploadToCloudinary()` method
   - Now uses unsigned upload (simpler, works immediately)
   - Better error messages and logging

2. **complaints/api_views.py** (Backend - for future use)
   - Added `get_cloudinary_signature()` endpoint
   - Generates secure signatures using SHA-1
   - Ready for signed uploads when you deploy

3. **complaints/api_urls.py** (Backend - for future use)
   - Added route: `/api/cloudinary/signature/`

## Testing

After creating the upload preset:

1. Run your Flutter app
2. Go to AI Assistant
3. Take or select a photo
4. You should see:
   - "☁️ Uploading image..."
   - "✅ Image uploaded successfully!"

Check console logs for detailed upload information.

## Future Enhancement (Optional)

Once you deploy the backend changes to Vercel, you can switch to signed uploads for better security:

```bash
git add .
git commit -m "Add Cloudinary signature endpoint"
git push
```

Then update Flutter to use `ApiConfig.cloudinarySignature` endpoint.

## Troubleshooting

**If upload still fails:**

1. Check console logs for exact error
2. Verify upload preset exists in Cloudinary dashboard
3. Ensure preset name matches exactly: `smartcity_complaints`
4. Check internet connection
5. Verify Cloudinary cloud name: `dk1q50evg`

**Common Errors:**

- `Invalid upload preset` → Preset not created or wrong name
- `Timeout` → Network issue or file too large
- `401/403` → Preset signing mode is not "Unsigned"

## Security Note

Unsigned uploads are safe when:
- You control the preset settings (folder, file types, size limits)
- You validate uploads on your backend
- You use Cloudinary's moderation features

For production, consider switching to signed uploads (backend endpoint is ready).
