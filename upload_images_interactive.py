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
    print("CLOUDINARY IMAGE UPLOADER - TRACKING PAGES")
    print("=" * 60)
    print("\nChoose upload method:")
    print("1. Upload from local files")
    print("2. Upload from URLs")
    print("3. Upload placeholder images (for testing)")
    
    choice = input("\nEnter choice (1/2/3): ").strip()
    
    if choice == "1":
        print("\nEnter full paths to your tracking images:")
        track_web_path = input("Track desktop background path (JPG): ").strip()
        track_mobile_path = input("Track mobile background path (JPG): ").strip()
        
        print("\nUploading...")
        upload_from_file(track_web_path, "tracking-web")
        upload_from_file(track_mobile_path, "tracking-mobile")
    
    elif choice == "2":
        print("\nEnter URLs to your tracking images:")
        track_web_url = input("Track desktop background URL: ").strip()
        track_mobile_url = input("Track mobile background URL: ").strip()
        
        print("\nUploading...")
        upload_from_url(track_web_url, "tracking-web")
        upload_from_url(track_mobile_url, "tracking-mobile")
    
    elif choice == "3":
        print("\nUploading placeholder images...")
        placeholders = {
            "tracking-web": "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=1920&h=1080&fit=crop",
            "tracking-mobile": "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=1080&h=1920&fit=crop"
        }
        
        for public_id, url in placeholders.items():
            upload_from_url(url, public_id)
    
    else:
        print("Invalid choice!")
    
    print("\n" + "=" * 60)
    print("Check your images at:")
    print("https://console.cloudinary.com/console/c-f8d0c8e8e8e8e8e8e8e8e8/media_library")
    print("=" * 60)
