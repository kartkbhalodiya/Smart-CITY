# How to Add Logo, Favicon, and Background Images

## Current Status
✅ Site is working with gradient background and emoji logo
⚠️ To add custom images, follow steps below

## Option 1: Upload to Cloudinary (Recommended for Vercel)

### Step 1: Prepare Your Images
Place these 4 images in `static/images/` folder:
- `logo.png` - Your logo (transparent PNG, ~400x100px)
- `favicon.png` - Browser icon (32x32px or 64x64px PNG)
- `login-bg-web.jpg` - Desktop background (1920x1080px)
- `login-bg-mobile.jpg` - Mobile background (1080x1920px)

### Step 2: Upload Using Script
```bash
# Install cloudinary if not installed
pip install cloudinary

# Run upload script
python upload_to_cloudinary.py
```

### Step 3: Update login.html
After successful upload, replace in `templates/login.html`:

**For Favicon (line 9):**
```html
<link rel="icon" type="image/png" href="https://res.cloudinary.com/dk1q50evg/image/upload/v1/favicon.png">
```

**For Logo (around line 360):**
```html
<div class="logo-container">
    <img src="https://res.cloudinary.com/dk1q50evg/image/upload/v1/logo.png" alt="JanHelp Logo" class="logo-img">
    <p class="brand-subtitle">Complaint Management System</p>
    <h2 class="heading">Login to Your Account</h2>
</div>
```

**For Backgrounds (around line 60-70):**
```css
/* Desktop Background */
@media (min-width: 1025px) {
    .bg-container {
        background-image: url("https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-web.jpg");
    }
}

/* Mobile Background */
@media (max-width: 1024px) {
    .bg-container {
        background-image: url("https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-mobile.jpg");
    }
}
```

### Step 4: Deploy
```bash
git add .
git commit -m "Add custom images via Cloudinary"
git push
```

## Option 2: Manual Upload to Cloudinary

1. Go to https://cloudinary.com/console
2. Login with account: dk1q50evg
3. Click "Media Library"
4. Click "Upload" button
5. Upload your 4 images
6. Copy the URLs from Cloudinary
7. Update `templates/login.html` with the URLs
8. Commit and push

## Option 3: Use Base64 Embedded Images (Small images only)

For favicon and small logo, you can embed directly:

```html
<!-- Favicon as base64 -->
<link rel="icon" href="data:image/png;base64,iVBORw0KG...">

<!-- Logo as base64 -->
<img src="data:image/png;base64,iVBORw0KG..." alt="Logo">
```

Convert image to base64: https://www.base64-image.de/

## Recommended Image Specs

### Logo
- Format: PNG with transparency
- Size: 400x100px (or similar ratio)
- Max file size: 50KB
- Style: Clean, professional, readable

### Favicon
- Format: PNG
- Size: 32x32px or 64x64px
- Max file size: 10KB
- Style: Simple icon that represents your brand

### Desktop Background
- Format: JPG
- Size: 1920x1080px (16:9 ratio)
- Max file size: 500KB
- Style: Professional, not too busy
- Ensure text is readable on top

### Mobile Background
- Format: JPG
- Size: 1080x1920px (9:16 ratio)
- Max file size: 500KB
- Style: Portrait orientation
- Keep important elements centered

## Troubleshooting

**Images not loading?**
1. Check Cloudinary URLs in browser
2. Verify images are public in Cloudinary
3. Check browser console for errors
4. Clear browser cache (Ctrl+Shift+R)

**Images too large?**
- Compress at https://tinypng.com/
- Use JPG for photos, PNG for logos
- Cloudinary auto-optimizes images

**Wrong aspect ratio?**
- Use https://www.iloveimg.com/resize-image
- Maintain aspect ratio for best quality
