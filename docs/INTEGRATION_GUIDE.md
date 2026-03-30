# Connect CityFix LLM to Your Django Application

## Your Hugging Face Space
**URL:** https://kartik1911-cityfix-llm-demo.hf.space

## Integration Methods

### Method 1: Using Gradio Client (Recommended)

Install Gradio client:
```bash
pip install gradio-client
```

Update your Django code:

```python
from gradio_client import Client

# In your AI assistant view
def chat_with_ai(request):
    client = Client("kartik1911/cityfix-llm-demo")
    
    user_message = request.POST.get('message')
    
    # Call your Space
    result = client.predict(
        text=user_message,
        api_name="/predict"
    )
    
    return JsonResponse(result)
```

### Method 2: Direct HTTP API Call

Already configured in `complaints/cityfix_client.py`:

```python
from complaints.cityfix_client import cityfix_llm

# In your view
def analyze_complaint(request):
    message = request.POST.get('message')
    
    # Call your Space
    result = cityfix_llm.predict(message)
    
    return JsonResponse(result)
```

### Method 3: Update Settings

Add to `smartcity/settings.py`:

```python
# CityFix LLM Configuration
CITYFIX_LLM_URL = 'https://kartik1911-cityfix-llm-demo.hf.space'
```

## Test Your Integration

### Test from Python:
```python
from gradio_client import Client

client = Client("kartik1911/cityfix-llm-demo")
result = client.predict("Street light not working", api_name="/predict")
print(result)
```

### Test from cURL:
```bash
curl -X POST https://kartik1911-cityfix-llm-demo.hf.space/api/predict \
  -H "Content-Type: application/json" \
  -d '{"data": ["Street light not working"]}'
```

## Update Your AI Views

Find your AI chat views (likely in `complaints/views.py` or `complaints/enhanced_ai_views.py`) and update them to use:

```python
from gradio_client import Client

client = Client("kartik1911/cityfix-llm-demo")

def process_complaint(text):
    result = client.predict(text, api_name="/predict")
    return result
```

## Response Format

Your Space returns:
```json
{
  "category": "Street Lighting",
  "subcategory": "Light Not Working",
  "urgency": "medium",
  "emotion": "frustrated",
  "language": "english",
  "is_emergency": false,
  "is_critical": false,
  "severity_score": 0.45,
  "risk_score": 0.32,
  "confidence": 0.95,
  "sentiment_intensity": -0.3,
  "location": "yes",
  "time": "no",
  "alternatives": ["Road Maintenance", "Public Safety"]
}
```

## Next Steps

1. Install gradio-client: `pip install gradio-client`
2. Test the connection
3. Update your AI views to use the Space
4. Deploy your Django app with the new integration
