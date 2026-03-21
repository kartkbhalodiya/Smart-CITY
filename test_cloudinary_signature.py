import requests
import json

# Test the Cloudinary signature endpoint
url = "https://janhelp.vercel.app/api/cloudinary/signature/"

print(f"Testing endpoint: {url}")
print("-" * 50)

try:
    response = requests.post(url, headers={'Content-Type': 'application/json'}, timeout=10)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        data = response.json()
        if data.get('success'):
            print("\n✅ SUCCESS! Signature endpoint is working")
            print(f"Cloud Name: {data.get('cloud_name')}")
            print(f"API Key: {data.get('api_key')}")
            print(f"Signature: {data.get('signature')[:20]}...")
            print(f"Timestamp: {data.get('timestamp')}")
        else:
            print(f"\n❌ FAILED: {data.get('message')}")
    else:
        print(f"\n❌ HTTP Error: {response.status_code}")
        
except Exception as e:
    print(f"\n❌ ERROR: {str(e)}")
