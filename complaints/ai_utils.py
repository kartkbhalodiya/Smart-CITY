from django.conf import settings
import os

try:
    from google import genai as google_genai
except Exception:  # pragma: no cover
    google_genai = None

legacy_genai = None

def verify_complaint_proof(image_path_or_file, category_label, category_key=None):
    """
    Analyzes an image using Gemini 1.5 Flash to verify it matches the category.
    """
    print(f"DEBUG: Verifying proof for Category: {category_label} (Key: {category_key})")
    
    # Categories where visual proof is NOT possible (Police, Cyber, etc.)
    # We skip strict AI verification for these.
    skip_keys = ['police', 'cyber', 'other']
    skip_labels = ['Police Complaint', 'Cyber Crime', 'Other Complaint']
    
    if category_key in skip_keys or category_label in skip_labels:
        print(f"DEBUG: Skipping AI verification for {category_key or category_label}")
        return True, "Verification skipped for this category"

    api_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not api_key:
        # If no API key is configured, skip verification to avoid blocking
        return True, "API Key missing"

    try:
        model_name = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")

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
            f"You are a very strict city government inspector. Your job is to reject any image that is NOT a clear photo of the reported issue.\n\n"
            f"REPORT CATEGORY: {category_label}\n\n"
            "RULES FOR ACCEPTANCE (YES):\n"
            f"1. The image must clearly show a real-world, outdoor infrastructure or public service problem belonging to the category '{category_label}'.\n"
            "2. Examples: Potholes, overflowing trash, broken street lights, water leaks, illegal construction on streets.\n\n"
            "RULES FOR REJECTION (NO) - YOU MUST REJECT IF:\n"
            "1. It is a selfie, a person's face, or showing people.\n"
            "2. It is an indoor photo of a home, office, or bedroom.\n"
            "3. it is a screenshot of a phone, website, or social media.\n"
            "4. It is a photo of random objects like food, pets, flowers, or clean cars.\n"
            "5. It is a text-only image, logo, or meme.\n"
            "6. It is black, too dark, or too blurry to identify the problem.\n\n"
            "STRICT INSTRUCTION: If you are even slightly unsure, answer NO. Answer ONLY with 'YES' or 'NO'."
        )

        # Detect mime type roughly
        mime_type = 'image/jpeg'
        if str(image_path_or_file).lower().endswith('.png'):
            mime_type = 'image/png'

        result_text = ""
        if google_genai is not None:
            client = google_genai.Client(api_key=api_key)
            part = google_genai.types.Part.from_bytes(
                data=image_data,
                mime_type=mime_type,
            )
            response = client.models.generate_content(
                model=model_name,
                contents=[prompt, part],
            )
            result_text = (getattr(response, "text", "") or "").strip()
        else:
            global legacy_genai
            if legacy_genai is None:
                import google.generativeai as legacy_genai  # type: ignore
            legacy_genai.configure(api_key=api_key)
            model = legacy_genai.GenerativeModel(model_name)
            response = model.generate_content([
                prompt,
                {'mime_type': mime_type, 'data': image_data}
            ])
            result_text = (response.text or "").strip()

        result = result_text.upper()
        print(f"--- AI LOG START ---")
        print(f"Category: {category_label}")
        print(f"AI Result: {result}")
        print(f"--- AI LOG END ---")
        
        # Strict matching: Result should start with YES or be exactly YES
        is_valid = result.startswith("YES")
        return is_valid, result

    except Exception as e:
        print(f"AI Verification Error: {str(e)}")
        # In case of API error, we allow it (fail-open) to not block users
        return True, str(e)
