import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from complaints.models import ComplaintSubcategory, ComplaintCategoryField

inactive_subs = ComplaintSubcategory.objects.filter(is_active=False)
inactive_fields = ComplaintCategoryField.objects.filter(is_active=False)

print(f"Inactive subcategories: {inactive_subs.count()}")
print(f"Inactive fields: {inactive_fields.count()}")

active_subs = ComplaintSubcategory.objects.filter(is_active=True)
active_fields = ComplaintCategoryField.objects.filter(is_active=True)

print(f"Active subcategories: {active_subs.count()}")
print(f"Active fields: {active_fields.count()}")
