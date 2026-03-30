# Cloudinary Image Upload Security Fix

## Problem
The Flutter app was getting 401 errors when uploading images to Cloudinary because it was using an unsigned upload preset that doesn't exist or is not configured properly. The app was exposing Cloudinary credentials in the client code.

## Solution
Implemented secure server-side signed uploads using backend API:

### Backend Changes

1. **New API Endpoint** (`complaints/api_views.py`):
   - Added `get_cloudinary_signature()` endpoint
   - Generates secure upload signatures using server-side secrets
   - Returns: signature, timestamp, cloud_name, api_key, folder

2. **API URL Configuration** (`complaints/api_urls.py`):
   - Added route: `POST /api/cloudinary/signature/`
   - Public endpoint (AllowAny) for image uploads

### Frontend Changes

1. **API Config** (`lib/config/api_config.dart`):
   - Added `cloudinarySignature` endpoint constant
   - Added `uploadTimeout` duration (60 seconds)

2. **AI Chat Screen** (`lib/screens/ai_assistant/ai_chat_screen.dart`):
   - Updated `_uploadToCloudinary()` method
   - Now fetches signature from backend before upload
   - Uses signed upload instead of unsigned preset
   - Better error handling and timeout management

## How It Works

1. **Client requests signature**:
   ```dart
   POST /api/cloudinary/signature/
   ```

2. **Backend generates signature**:
   ```python
   signature = sha256(f"folder={folder}&timestamp={timestamp}{api_secret}")
   ```

3. **Client uploads with signature**:
   ```dart
   POST https://api.cloudinary.com/v1_1/{cloud_name}/image/upload
   Fields: api_key, timestamp, signature, folder, file
   ```

## Security Benefits

- ✅ No credentials exposed in client code
- ✅ Server controls upload parameters (folder, etc.)
- ✅ Signature prevents unauthorized uploads
- ✅ Backend secrets remain secure in environment variables

## Environment Variables Required

Backend `.env` file must have:
```
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

## Testing

1. Start backend server
2. Run Flutter app
3. Go to AI Assistant
4. Take/select a photo
5. Image should upload successfully with "✅ Image uploaded successfully!" message

## Error Handling

- Backend signature generation errors → 500 response
- Network timeout → "Upload timeout - check your connection"
- Upload failure → Shows error message in chat
- User can retry or submit without image
