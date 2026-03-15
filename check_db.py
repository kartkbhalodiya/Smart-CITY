import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from complaints.models import ComplaintCategory, ComplaintSubcategory

cats = ComplaintCategory.objects.all()
print(f"Total Categories: {cats.count()}")

for cat in cats:
    subs = cat.subcategories.all()
    print(f"Category: {cat.name} ({cat.key}) - {subs.count()} subcategories")
    for sub in subs:
        fields = sub.dynamic_fields.all()
        print(f"  - Subcategory: {sub.name} ({fields.count()} fields)")
