from django.core.management.base import BaseCommand
from complaints.models import ComplaintCategory


class Command(BaseCommand):
    help = 'Display all categories and their subcategories from database'

    def handle(self, *args, **options):
        categories = ComplaintCategory.objects.filter(is_active=True).prefetch_related('subcategories')
        
        if not categories.exists():
            self.stdout.write(self.style.ERROR('No categories found in database!'))
            return
        
        self.stdout.write(self.style.SUCCESS(f'\n{"="*80}'))
        self.stdout.write(self.style.SUCCESS(f'TOTAL CATEGORIES: {categories.count()}'))
        self.stdout.write(self.style.SUCCESS(f'{"="*80}\n'))
        
        for category in categories:
            subcategories = category.subcategories.filter(is_active=True)
            self.stdout.write(self.style.WARNING(f'\n[{category.name}] (key: "{category.key}")'))
            self.stdout.write(self.style.WARNING(f'   Subcategories: {subcategories.count()}'))
            self.stdout.write(self.style.SUCCESS('   ' + '-' * 70))
            
            for idx, sub in enumerate(subcategories, 1):
                self.stdout.write(f'   {idx}. {sub.name}')
        
        self.stdout.write(self.style.SUCCESS(f'\n{"="*80}\n'))
