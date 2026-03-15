import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from complaints.models import ComplaintCategory

cats = ComplaintCategory.objects.all()
print([(c.key, c.name) for c in cats])
