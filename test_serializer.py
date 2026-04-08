import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from complaints.serializers import ComplaintCreateSerializer

data = {
    'complaint_type': 'Electricity',
    'subcategory': 'Power Outage',
    'title': 'No power in area',
    'description': 'It has been dark for 2 days',
    'address': 'Rajkot',
    'latitude': '22.303900',
    'longitude': '70.802200',
    'language': 'en',
    'guest_name': 'Test User',
    'guest_phone': '9876543210',
    'uploaded_only_verification': 'true',
    'source': 'voice_call'
}

serializer = ComplaintCreateSerializer(data=data)
if serializer.is_valid():
    print("VALID!")
else:
    print("INVALID:", serializer.errors)
