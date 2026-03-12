# Upload Images to Cloudinary

## Required Images:
1. **logo.png** - Your JanHelp logo
2. **favicon.png** - Browser tab icon (16x16 or 32x32 px)
3. **login-bg-web.jpg** - Desktop background (1920x1080 recommended)
4. **login-bg-mobile.jpg** - Mobile background (1080x1920 recommended, 9:16 ratio)

## Steps to Upload:

### Option 1: Cloudinary Dashboard (Easiest)
1. Go to https://cloudinary.com/console
2. Login with your account (dk1q50evg)
3. Click "Media Library" in the top menu
4. Click "Upload" button
5. Upload these 4 images:
   - logo.png
   - favicon.png
   - login-bg-web.jpg
   - login-bg-mobile.jpg
6. After upload, the URLs will be automatically available at:
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/logo.png
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/favicon.png
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-web.jpg
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-mobile.jpg

### Option 2: Using Python Script
Create a file `upload_images.py`:

```python
import cloudinary
import cloudinary.uploader

cloudinary.config(
    cloud_name="dk1q50evg",
    api_key="284539188155248",
    api_secret="C1RW6ViwtH4RZspIlRi6LSa-wBw"
)

# Upload images
images = [
    'logo.png',
    'favicon.png',
    'login-bg-web.jpg',
    'login-bg-mobile.jpg'
]

for img in images:
    result = cloudinary.uploader.upload(f"path/to/{img}", public_id=img.split('.')[0])
    print(f"Uploaded {img}: {result['secure_url']}")
```

Run: `python upload_images.py`

## Image Recommendations:

### Logo (logo.png)
- Transparent background (PNG)
- Size: 400x100 px or similar
- Clear, readable text

### Favicon (favicon.png)
- Size: 32x32 px or 64x64 px
- PNG format with transparency
- Simple, recognizable icon

### Desktop Background (login-bg-web.jpg)
- Size: 1920x1080 px (16:9 ratio)
- High quality JPG
- Warm, professional look
- Not too busy (text needs to be readable on top)

### Mobile Background (login-bg-mobile.jpg)
- Size: 1080x1920 px (9:16 ratio)
- Portrait orientation
- Same style as desktop but optimized for vertical view
- Keep important elements in center

## After Upload:
1. Commit and push changes:
   ```bash
   git add .
   git commit -m "Use Cloudinary for images"
   git push
   ```

2. Vercel will auto-deploy and images will load from Cloudinary

## Verify Images:
Visit these URLs in browser to confirm upload:
- https://res.cloudinary.com/dk1q50evg/image/upload/v1/logo.png
- https://res.cloudinary.com/dk1q50evg/image/upload/v1/favicon.png
- https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-web.jpg
- https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-mobile.jpg
