# Quick Image Upload Guide

## Problem: Images not found in static/images folder

## Solution: 3 Easy Options

### Option 1: Upload Your Own Images (Recommended)

1. **Find your images** on your computer (logo, favicon, backgrounds)

2. **Run the interactive script:**
   ```bash
   python upload_images_interactive.py
   ```

3. **Choose option 1** and enter full paths like:
   ```
   C:\Users\YourName\Pictures\logo.png
   C:\Users\YourName\Pictures\favicon.png
   C:\Users\YourName\Pictures\background-web.jpg
   C:\Users\YourName\Pictures\background-mobile.jpg
   ```

### Option 2: Upload from Internet URLs

1. **Find images online** or use your hosted images

2. **Run the interactive script:**
   ```bash
   python upload_images_interactive.py
   ```

3. **Choose option 2** and paste URLs

### Option 3: Use Placeholder Images (Quick Test)

1. **Run the interactive script:**
   ```bash
   python upload_images_interactive.py
   ```

2. **Choose option 3** - automatically uploads placeholder images

3. **Deploy and test** - replace with real images later

### Option 4: Manual Upload to Cloudinary (Easiest)

1. **Go to:** https://cloudinary.com/console
2. **Login** with your account
3. **Click:** Media Library → Upload
4. **Upload 4 images** and rename them:
   - logo
   - favicon
   - login-bg-web
   - login-bg-mobile
5. **Done!** Images will be at:
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/logo.png
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/favicon.png
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-web.jpg
   - https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-mobile.jpg

## After Upload

Update `templates/login.html` to use Cloudinary URLs:

```html
<!-- Line 9 - Favicon -->
<link rel="icon" type="image/png" href="https://res.cloudinary.com/dk1q50evg/image/upload/v1/favicon.png">

<!-- Around line 360 - Logo -->
<img src="https://res.cloudinary.com/dk1q50evg/image/upload/v1/logo.png" alt="JanHelp Logo" class="logo-img">

<!-- Around line 60-70 - Backgrounds -->
background-image: url("https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-web.jpg");
background-image: url("https://res.cloudinary.com/dk1q50evg/image/upload/v1/login-bg-mobile.jpg");
```

Then deploy:
```bash
git add .
git commit -m "Add images via Cloudinary"
git push
```

## Recommended: Option 4 (Manual Upload)
It's the easiest and most reliable method!
