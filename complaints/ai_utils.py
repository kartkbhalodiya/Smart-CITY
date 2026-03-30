import json
import mimetypes
from io import BytesIO
from django.conf import settings
from PIL import Image, ImageOps, ImageStat

try:
    from google import genai as google_genai
except Exception:  # pragma: no cover
    google_genai = None

legacy_genai = None


def _detect_mime_type(image_path_or_file):
    content_type = getattr(image_path_or_file, "content_type", None)
    if content_type:
        return content_type

    file_name = getattr(image_path_or_file, "name", None) or str(image_path_or_file)
    guessed_type, _ = mimetypes.guess_type(file_name)
    return guessed_type or "image/jpeg"


def _extract_json_payload(raw_text):
    text = (raw_text or "").strip()
    if not text:
        return None

    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return None

    try:
        return json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None


def _parse_verification_result(raw_text):
    payload = _extract_json_payload(raw_text)
    if payload:
        verdict = str(
            payload.get("match")
            or payload.get("verdict")
            or payload.get("is_match")
            or ""
        ).strip().lower()
        reason = str(payload.get("reason") or payload.get("details") or "").strip()
        is_valid = verdict in {"yes", "true", "match", "valid"}
        if not reason:
            reason = "Proof matches the selected complaint." if is_valid else "Proof does not match the selected complaint."
        return is_valid, reason

    normalized = (raw_text or "").strip()
    upper_text = normalized.upper()
    if upper_text.startswith("YES"):
        return True, normalized or "Proof matches the selected complaint."
    return False, normalized or "Proof does not match the selected complaint."


def _run_basic_image_quality_checks(image_data):
    """
    Reject obviously invalid proof images before spending a Gemini request.
    """
    try:
        with Image.open(BytesIO(image_data)) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            width, height = image.size

            if width < 64 or height < 64:
                return "The uploaded image is too small to verify. Please upload a clearer photo."

            gray = ImageOps.grayscale(image)
            stat = ImageStat.Stat(gray)
            mean_brightness = stat.mean[0]
            stddev_brightness = stat.stddev[0]
            histogram = gray.histogram()
            total_pixels = sum(histogram) or 1

            very_dark_ratio = sum(histogram[:16]) / total_pixels
            dark_ratio = sum(histogram[:32]) / total_pixels
            very_bright_ratio = sum(histogram[240:]) / total_pixels

            if very_dark_ratio >= 0.98 or mean_brightness < 12:
                return "The uploaded image is almost completely black or too dark to verify."

            if dark_ratio >= 0.995:
                return "The uploaded image is too dark to identify the issue. Please upload a brighter photo."

            if very_bright_ratio >= 0.98 and stddev_brightness < 6:
                return "The uploaded image appears blank or overexposed and cannot be verified."

            if stddev_brightness < 5:
                return "The uploaded image appears blank or nearly single-color and cannot be verified."

    except Exception as exc:
        print(f"Basic image quality check warning: {str(exc)}")

    return None


def verify_complaint_proof(
    image_path_or_file,
    category_label,
    category_key=None,
    subcategory=None,
    complaint_description=None,
):
    """
    Analyze uploaded proof with Gemini and verify it matches the selected complaint.
    """
    print(
        f"DEBUG: Verifying proof for Category: {category_label} "
        f"(Key: {category_key}, Subcategory: {subcategory})"
    )

    try:
        if hasattr(image_path_or_file, "read"):
            image_data = image_path_or_file.read()
            if hasattr(image_path_or_file, "seek"):
                image_path_or_file.seek(0)
        else:
            from django.core.files.storage import default_storage

            with default_storage.open(image_path_or_file, "rb") as image_file:
                image_data = image_file.read()

        quality_issue = _run_basic_image_quality_checks(image_data)
        if quality_issue:
            return False, quality_issue

        api_key = getattr(settings, "GEMINI_API_KEY", "")
        if not api_key:
            return False, "Gemini API key is not configured on the server."

        model_name = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")
        mime_type = _detect_mime_type(image_path_or_file)
        selected_issue = subcategory or category_label
        complaint_description = (complaint_description or "").strip() or "Not provided"

        prompt = f"""
You are a strict municipal complaint proof verifier.

Your task is to decide whether the uploaded image clearly matches the selected complaint.

Selected complaint:
- Category: {category_label}
- Category key: {category_key or "unknown"}
- Subcategory / issue: {selected_issue}
- Citizen description: {complaint_description}

Validation rules:
1. Accept only if the image clearly shows visible real-world evidence of the selected complaint.
2. Reject if the image is unrelated to the selected category or subcategory.
3. Reject if it is a selfie, portrait, document, screenshot, text-only image, logo, meme, indoor scene, random object, pet, food, or vehicle with no visible civic issue.
4. Reject if the proof is too dark, too blurry, blank, or unclear.
5. If the selected complaint is about potholes, garbage, drainage, water leakage, broken streetlight, construction, or road damage, the image must visibly show that exact type of issue.
6. If you are unsure, reject it.

Return ONLY valid JSON in this exact format:
{{"match":"YES" or "NO","reason":"short reason","detected_issue":"what the image most likely shows"}}
""".strip()

        if google_genai is not None:
            client = google_genai.Client(api_key=api_key)
            image_part = google_genai.types.Part.from_bytes(
                data=image_data,
                mime_type=mime_type,
            )
            response = client.models.generate_content(
                model=model_name,
                contents=[prompt, image_part],
                config=google_genai.types.GenerateContentConfig(
                    temperature=0.0,
                ),
            )
            result_text = (getattr(response, "text", "") or "").strip()
        else:
            global legacy_genai
            if legacy_genai is None:
                import google.generativeai as legacy_genai  # type: ignore

            legacy_genai.configure(api_key=api_key)
            model = legacy_genai.GenerativeModel(model_name)
            response = model.generate_content(
                [prompt, {"mime_type": mime_type, "data": image_data}],
                generation_config={"temperature": 0.0},
            )
            result_text = (response.text or "").strip()

        is_valid, reason = _parse_verification_result(result_text)

        print("--- AI LOG START ---")
        print(f"Category: {category_label}")
        print(f"Subcategory: {subcategory}")
        print(f"AI Raw Result: {result_text}")
        print(f"AI Parsed Verdict: {is_valid}")
        print(f"AI Parsed Reason: {reason}")
        print("--- AI LOG END ---")

        return is_valid, reason

    except Exception as exc:
        print(f"AI Verification Error: {str(exc)}")
        return False, f"Gemini verification failed: {str(exc)}"
