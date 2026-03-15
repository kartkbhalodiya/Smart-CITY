import os
import django

# Set up Django environment
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "smartcity.settings")
django.setup()

from complaints.models import ComplaintCategory, ComplaintSubcategory

def list_subcategories():
    categories = ComplaintCategory.objects.all().order_by('name')
    
    print("=" * 50)
    print(f"{'Category Name':<25} | {'Subcategory Name'}")
    print("-" * 50)
    
    total_count = 0
    for cat in categories:
        subcategories = ComplaintSubcategory.objects.filter(category=cat).order_by('name')
        for sub in subcategories:
            print(f"{cat.name:<25} | {sub.name}")
            total_count += 1
    
    print("-" * 50)
    print(f"Total Subcategories: {total_count}")
    print("=" * 50)

if __name__ == "__main__":
    list_subcategories()
