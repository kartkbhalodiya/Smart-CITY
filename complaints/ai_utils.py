import google.generativeai as genai
from django.conf import settings
import os

def verify_complaint_proof(image_path_or_file, category_label):
    """
    Analyzes an image using Gemini 1.5 Flash to verify it matches the category.
    """
    api_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not api_key:
        # If no API key is configured, skip verification to avoid blocking
        return True, "API Key missing"

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-1.5-flash')

        # Read image data
        if hasattr(image_path_or_file, 'read'):
            image_data = image_path_or_file.read()
            # Reset pointer if it's a file object
            if hasattr(image_path_or_file, 'seek'):
                image_path_or_file.seek(0)
        else:
            # If it's a path from default_storage
            from django.core.files.storage import default_storage
            with default_storage.open(image_path_or_file, 'rb') as f:
                image_data = f.read()

        prompt = (
            f"Analyze this image carefully. Does it show a real-world issue related to '{category_label}'? "
            "Examples: If category is 'Garbage', it should show trash. If 'Road', it should show potholes or broken roads. "
            "If it shows a random person, a selfie, a black screen, a room interior without the issue, or something unrelated, answer NO. "
            "Answer ONLY with 'YES' or 'NO'."
        )

        # Detect mime type roughly
        mime_type = 'image/jpeg'
        if str(image_path_or_file).lower().endswith('.png'):
            mime_type = 'image/png'

        response = model.generate_content([
            prompt,
            {'mime_type': mime_type, 'data': image_data}
        ])

        result = response.text.strip().upper()
        return "YES" in result, result

    except Exception as e:
        print(f"AI Verification Error: {str(e)}")
        # In case of API error, we allow it (fail-open) to not block users
        return True, str(e)
