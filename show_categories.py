"""
Script to display all categories and subcategories from database
Run: python show_categories.py
"""

import os
import sys
import django

# Setup Django environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from complaints.models import ComplaintCategory


def main():
    print("\n" + "="*80)
    print("SMART CITY - CATEGORIES AND SUBCATEGORIES")
    print("="*80 + "\n")
    
    categories = ComplaintCategory.objects.filter(is_active=True).prefetch_related('subcategories')
    
    if not categories.exists():
        print("❌ No categories found in database!")
        return
    
    print(f"TOTAL CATEGORIES: {categories.count()}\n")
    
    total_subcategories = 0
    
    for idx, category in enumerate(categories, 1):
        subcategories = category.subcategories.filter(is_active=True).order_by('display_order', 'name')
        total_subcategories += subcategories.count()
        
        print(f"\n{idx}. [{category.name}]")
        print(f"   Key: '{category.key}'")
        print(f"   Subcategories: {subcategories.count()}")
        print("   " + "-"*70)
        
        for sub_idx, sub in enumerate(subcategories, 1):
            print(f"   {sub_idx:2d}. {sub.name}")
    
    print("\n" + "="*80)
    print(f"SUMMARY:")
    print(f"   Total Categories: {categories.count()}")
    print(f"   Total Subcategories: {total_subcategories}")
    print(f"   Average Subcategories per Category: {total_subcategories / categories.count():.1f}")
    print("="*80 + "\n")


if __name__ == '__main__':
    main()
