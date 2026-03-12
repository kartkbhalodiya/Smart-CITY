import cloudinary
import cloudinary.uploader
import os

# Configure Cloudinary
cloudinary.config(
    cloud_name="dk1q50evg",
    api_key="284539188155248",
    api_secret="C1RW6ViwtH4RZspIlRi6LSa-wBw"
)

def upload_from_url(url, public_id):
    """Upload image from URL to Cloudinary"""
    try:
        result = cloudinary.uploader.upload(
            url,
            public_id=public_id,
            overwrite=True,
            resource_type="image"
        )
        print(f"✓ Uploaded {public_id}: {result['secure_url']}")
        return result['secure_url']
    except Exception as e:
        print(f"✗ Error uploading {public_id}: {str(e)}")
        return None

def upload_from_file(file_path, public_id):
    """Upload image from local file to Cloudinary"""
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
    print("\nChoose upload method:")
    print("1. Upload from local files")
    print("2. Upload from URLs")
    print("3. Upload placeholder images (for testing)")
    
    choice = input("\nEnter choice (1/2/3): ").strip()
    
    if choice == "1":
        print("\nEnter full paths to your images:")
        logo_path = input("Logo path (PNG): ").strip()
        favicon_path = input("Favicon path (PNG): ").strip()
        bg_web_path = input("Desktop background path (JPG): ").strip()
        bg_mobile_path = input("Mobile background path (JPG): ").strip()
        
        print("\nUploading...")
        upload_from_file(logo_path, "logo")
        upload_from_file(favicon_path, "favicon")
        upload_from_file(bg_web_path, "login-bg-web")
        upload_from_file(bg_mobile_path, "login-bg-mobile")
    
    elif choice == "2":
        print("\nEnter URLs to your images:")
        logo_url = input("Logo URL: ").strip()
        favicon_url = input("Favicon URL: ").strip()
        bg_web_url = input("Desktop background URL: ").strip()
        bg_mobile_url = input("Mobile background URL: ").strip()
        
        print("\nUploading...")
        upload_from_url(logo_url, "logo")
        upload_from_url(favicon_url, "favicon")
        upload_from_url(bg_web_url, "login-bg-web")
        upload_from_url(bg_mobile_url, "login-bg-mobile")
    
    elif choice == "3":
        print("\nUploading placeholder images...")
        # Using placeholder image service
        placeholders = {
            "logo": "https://via.placeholder.com/400x100/1E66F5/FFFFFF?text=JanHelp",
            "favicon": "https://via.placeholder.com/64x64/1E66F5/FFFFFF?text=J",
            "login-bg-web": "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=1920&h=1080&fit=crop",
            "login-bg-mobile": "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=1080&h=1920&fit=crop"
        }
        
        for public_id, url in placeholders.items():
            upload_from_url(url, public_id)
    
    else:
        print("Invalid choice!")
    
    print("\n" + "=" * 60)
    print("Check your images at:")
    print("https://console.cloudinary.com/console/c-f8d0c8e8e8e8e8e8e8e8e8/media_library")
    print("=" * 60)
