import cloudinary
import cloudinary.uploader
import os

# Configure Cloudinary
cloudinary.config(
    cloud_name="dk1q50evg",
    api_key="284539188155248",
    api_secret="C1RW6ViwtH4RZspIlRi6LSa-wBw"
)

def upload_image(file_path, public_id):
    """Upload image to Cloudinary"""
    try:
        if os.path.exists(file_path):
            result = cloudinary.uploader.upload(
                file_path,
                public_id=public_id,
                overwrite=True,
                resource_type="image"
            )
            print(f"✓ Uploaded {public_id}: {result['secure_url']}")
            return result['secure_url']
        else:
            print(f"✗ File not found: {file_path}")
            return None
    except Exception as e:
        print(f"✗ Error uploading {public_id}: {str(e)}")
        return None

if __name__ == "__main__":
    print("=" * 60)
    print("CLOUDINARY IMAGE UPLOADER")
    print("=" * 60)
    
    # Define images to upload
    images = {
        "logo": "static/images/logo.png",
        "favicon": "static/images/favicon.png",
        "login-bg-web": "static/images/login-bg-web.jpg",
        "login-bg-mobile": "static/images/login-bg-mobile.jpg"
    }
    
    print("\nUploading images to Cloudinary...")
    print("-" * 60)
    
    uploaded_urls = {}
    for public_id, file_path in images.items():
        url = upload_image(file_path, public_id)
        if url:
            uploaded_urls[public_id] = url
    
    print("\n" + "=" * 60)
    print("UPLOAD COMPLETE")
    print("=" * 60)
    
    if uploaded_urls:
        print("\nUploaded URLs:")
        for name, url in uploaded_urls.items():
            print(f"  {name}: {url}")
    
    print("\nNext steps:")
    print("1. Verify images at: https://cloudinary.com/console/media_library")
    print("2. Commit and push changes to deploy")
    print("=" * 60)
