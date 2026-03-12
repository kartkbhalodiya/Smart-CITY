#!/bin/bash
# Vercel build script for Django

echo "Starting Django build process..."

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Collect static files (only if not using Cloudinary)
if [ -z "$CLOUDINARY_CLOUD_NAME" ]; then
    echo "Collecting static files with Whitenoise..."
    python manage.py collectstatic --noinput
else
    echo "Skipping collectstatic (using Cloudinary)..."
fi

echo "Build completed successfully!"
