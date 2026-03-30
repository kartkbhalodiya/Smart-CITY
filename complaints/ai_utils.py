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


def _build_model_candidates(preferred_model):
    candidates = []
    for model_name in [
        (preferred_model or "").strip(),
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-2.0-flash-001",
    ]:
        if model_name and model_name not in candidates:
            candidates.append(model_name)
    return candidates


def _is_missing_model_error(exc):
    message = str(exc or "")
    normalized = message.lower()
    return (
        "not_found" in normalized
        or "is not found for api version" in normalized
        or "model" in normalized and "not found" in normalized
    )


def _generate_with_model_fallback(api_key, preferred_model, prompt, image_data, mime_type):
    model_candidates = _build_model_candidates(preferred_model)
    last_error = None

    if google_genai is not None:
        client = google_genai.Client(api_key=api_key)
        image_part = google_genai.types.Part.from_bytes(
            data=image_data,
            mime_type=mime_type,
        )

        for model_name in model_candidates:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=[prompt, image_part],
                    config=google_genai.types.GenerateContentConfig(
                        temperature=0.0,
                    ),
                )
                result_text = (getattr(response, "text", "") or "").strip()
                return result_text, model_name
            except Exception as exc:
                last_error = exc
                if _is_missing_model_error(exc):
                    print(f"Gemini model fallback: {model_name} unavailable, trying next model.")
                    continue
                raise
    else:
        global legacy_genai
        if legacy_genai is None:
            import google.generativeai as legacy_genai  # type: ignore

        legacy_genai.configure(api_key=api_key)

        for model_name in model_candidates:
            try:
                model = legacy_genai.GenerativeModel(model_name)
                response = model.generate_content(
                    [prompt, {"mime_type": mime_type, "data": image_data}],
                    generation_config={"temperature": 0.0},
                )
                result_text = (response.text or "").strip()
                return result_text, model_name
            except Exception as exc:
                last_error = exc
                if _is_missing_model_error(exc):
                    print(f"Gemini model fallback: {model_name} unavailable, trying next model.")
                    continue
                raise

    if last_error is not None:
        raise last_error
    raise RuntimeError("No Gemini model candidates were available.")


def _detect_mime_type(image_path_or_file, image_data=None):
    content_type = (getattr(image_path_or_file, "content_type", None) or "").strip().lower()
    if content_type and content_type not in {
        "application/octet-stream",
        "application/ octet-stream",
        "binary/octet-stream",
        "application/octetstream",
    }:
        return content_type

    file_name = getattr(image_path_or_file, "name", None) or str(image_path_or_file)
    guessed_type, _ = mimetypes.guess_type(file_name)
    if guessed_type and guessed_type.startswith("image/"):
        return guessed_type

    if image_data:
        try:
            with Image.open(BytesIO(image_data)) as image:
                format_name = (image.format or "").upper()
                format_to_mime = {
                    "JPEG": "image/jpeg",
                    "JPG": "image/jpeg",
                    "PNG": "image/png",
                    "WEBP": "image/webp",
                    "GIF": "image/gif",
                    "BMP": "image/bmp",
                    "TIFF": "image/tiff",
                    "HEIC": "image/heic",
                    "HEIF": "image/heif",
                }
                detected_mime = format_to_mime.get(format_name)
                if detected_mime:
                    return detected_mime
        except Exception as exc:
            print(f"MIME detection warning: {str(exc)}")

    return "image/jpeg"


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


def _category_specific_evidence_guidance(category_key, category_label, subcategory):
    key = (category_key or "").strip().lower()
    selected_issue = (subcategory or category_label or "").strip() or "the selected complaint"

    if key == "police":
        return f"""
Category-specific evidence guidance for police complaints:
- For theft, robbery, burglary, or chain snatching, ACCEPT supporting proof such as a bill, invoice, product box, IMEI label, ownership receipt, broken lock/door/window photo, theft-location photo, CCTV still, or related threat/chat screenshot.
- For missing person, ACCEPT a recent person photo, poster, ID proof, last-seen location photo, or CCTV still.
- For harassment, assault, domestic violence, or suspicious activity, ACCEPT injury photos, damage photos, chat/call screenshots, medical note photos, suspect vehicle/person images, or incident-location proof.
- Do NOT require the exact crime moment to be visible. Supporting evidence that clearly matches {selected_issue} is valid.
""".strip()

    if key == "cyber":
        return f"""
Category-specific evidence guidance for cyber complaints:
- ACCEPT screenshots of chats, emails, fake websites/apps, product/order pages, OTP requests, transaction receipts, UPI/bank statements, profile pages, complaint references, or scam messages.
- ACCEPT documentary proof even if it is a screenshot or text-heavy image.
- The image does not need to show a physical scene; it should support the cyber issue described as {selected_issue}.
""".strip()

    if key == "other":
        return f"""
Category-specific evidence guidance for other complaints:
- ACCEPT any supporting evidence that is reasonably connected to the complaint, including screenshots, bills, receipts, product photos, notices, damaged-item photos, or location photos.
- If the image clearly supports {selected_issue} or the citizen description, it can be accepted even when the issue itself is not directly visible.
""".strip()

    if key == "electricity":
        return f"""
Category-specific evidence guidance for electricity complaints:
- ACCEPT direct proof such as exposed wires, dark streetlights, poles, transformers, sparks, or damaged electrical infrastructure.
- For meter or billing-related electrical issues, ACCEPT meter photos, bills, connection labels, or relevant screenshots if they support {selected_issue}.
""".strip()

    if key == "water":
        return f"""
Category-specific evidence guidance for water complaints:
- ACCEPT direct proof such as leakage, dirty water, pipe bursts, tanker/non-supply scene, or affected area photos.
- For meter/connection-related issues, ACCEPT meter photos, bills, connection photos, or relevant screenshots if they support {selected_issue}.
""".strip()

    if key in {"illegal", "transportation"}:
        return f"""
Category-specific evidence guidance:
- ACCEPT direct scene photos, vehicle photos, location photos, screenshots, listings, notices, or other supporting proof if they clearly support {selected_issue}.
""".strip()

    return f"""
Category-specific evidence guidance for civic infrastructure complaints:
- Prefer direct visual proof of the issue itself.
- ACCEPT only when the image clearly shows the real-world issue related to {selected_issue}, such as pothole, garbage, drainage, leakage, broken light, or construction damage.
""".strip()


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

        model_name = getattr(settings, "GEMINI_MODEL", "gemini-2.5-flash")
        mime_type = _detect_mime_type(image_path_or_file, image_data=image_data)
        selected_issue = subcategory or category_label
        complaint_description = (complaint_description or "").strip() or "Not provided"
        evidence_guidance = _category_specific_evidence_guidance(
            category_key=category_key,
            category_label=category_label,
            subcategory=subcategory,
        )

        prompt = f"""
You are a municipal complaint proof verifier.

Your task is to decide whether the uploaded image is valid proof for the selected complaint.

Selected complaint:
- Category: {category_label}
- Category key: {category_key or "unknown"}
- Subcategory / issue: {selected_issue}
- Citizen description: {complaint_description}

General validation rules:
1. Accept if the image is direct proof OR category-appropriate supporting proof for the selected complaint.
2. Reject if the image is clearly unrelated to the category, subcategory, or citizen description.
3. Reject if the proof is too dark, too blurry, blank, or unreadable.
4. For screenshots, bills, receipts, or documents, read the visible text/UI clues and accept them when they reasonably support the selected complaint.
5. For infrastructure complaints like potholes, garbage, drainage, road damage, construction, broken streetlights, or water leakage, the image should usually show the real-world issue itself.
6. For police, cyber, or other complaints, supporting evidence does NOT need to show the exact incident itself; related bills, screenshots, damaged-scene photos, location photos, CCTV stills, or product/ownership proof may be valid.
7. Be practical, not over-strict. If the proof is reasonably connected to the selected complaint, accept it. Reject only when it is clearly unrelated or too weak to support the complaint.

{evidence_guidance}

Return ONLY valid JSON in this exact format:
{{"match":"YES" or "NO","reason":"short reason","detected_issue":"what the image most likely shows"}}
""".strip()

        result_text, used_model = _generate_with_model_fallback(
            api_key=api_key,
            preferred_model=model_name,
            prompt=prompt,
            image_data=image_data,
            mime_type=mime_type,
        )

        is_valid, reason = _parse_verification_result(result_text)

        print("--- AI LOG START ---")
        print(f"Category: {category_label}")
        print(f"Subcategory: {subcategory}")
        print(f"Gemini Model Used: {used_model}")
        print(f"AI Raw Result: {result_text}")
        print(f"AI Parsed Verdict: {is_valid}")
        print(f"AI Parsed Reason: {reason}")
        print("--- AI LOG END ---")

        return is_valid, reason

    except Exception as exc:
        print(f"AI Verification Error: {str(exc)}")
        return False, f"Gemini verification failed: {str(exc)}"
