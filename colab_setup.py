"""
Google Colab LLM Training Setup
Run this in a Colab cell to set up everything
"""

# Step 1: Install dependencies
print("Installing dependencies...")
!pip install -q torch transformers datasets accelerate sentencepiece

# Step 2: Upload files
from google.colab import files
import os

print("\n=== Upload your files ===")
print("Upload the following files one by one:")
print("1. train.py")
print("2. data.txt")
print("3. config.json (optional)")

uploaded = files.upload()

# Step 3: Verify uploads
print("\nUploaded files:")
for filename in uploaded.keys():
    print(f"  ✓ {filename} ({len(uploaded[filename])} bytes)")

# Step 4: Run training
print("\n=== Starting Training ===")
!python train.py

# Step 5: Download trained model
print("\n=== Download Trained Model ===")
!zip -r trained_model.zip trained_model/
files.download('trained_model.zip')
