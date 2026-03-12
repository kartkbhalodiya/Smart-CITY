# Upload 4 Images to Cloudinary

Both login and register pages use the SAME background images.

## Required Images (Only 4):

1. **logo.png** - JanHelp logo (400x100px, PNG with transparency)
2. **favicon.png** - Browser icon (32x32 or 64x64px)
3. **login-bg-web.jpg** - Desktop background (1920x1080px)
4. **login-bg-mobile.jpg** - Mobile background (1080x1920px)

## Easiest Method - Manual Upload:

1. Go to: https://cloudinary.com/console
2. Login with your account (cloud name: dk1q50evg)
3. Click "Media Library" → "Upload"
4. Upload your 4 images
5. Rename them to:
   - `logo`
   - `favicon`
   - `login-bg-web`
   - `login-bg-mobile`

## Or Use Script:

```bash
python upload_images_interactive.py
```

Choose option 3 for placeholder images (quick test)

## After Upload:

```bash
git add .
git commit -m "Use same backgrounds for login and register"
git push
```

Done! Both pages will use the same beautiful backgrounds.
