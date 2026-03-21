from google.colab import files
import os

def upload_files():
    """Upload all necessary files to Colab"""
    print("=== LLM Training Files Upload ===\n")
    
    print("Step 1: Upload train.py")
    uploaded = files.upload()
    print("✓ train.py uploaded\n")
    
    print("Step 2: Upload requirements.txt")
    uploaded = files.upload()
    print("✓ requirements.txt uploaded\n")
    
    print("Step 3: Upload data.txt (your training data)")
    uploaded = files.upload()
    print("✓ data.txt uploaded\n")
    
    print("Step 4: Upload config.json")
    uploaded = files.upload()
    print("✓ config.json uploaded\n")
    
    print("All files uploaded successfully!")
    print("\nNext steps:")
    print("1. Install dependencies: !pip install -r requirements.txt")
    print("2. Run training: !python train.py")

if __name__ == "__main__":
    upload_files()
