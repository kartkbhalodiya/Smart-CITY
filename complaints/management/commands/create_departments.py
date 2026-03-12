from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from complaints.models import Department

class Command(BaseCommand):
    help = 'Create sample department users for testing'

    def handle(self, *args, **kwargs):
        departments = [
            ('police@dept.com', 'police'),
            ('traffic@dept.com', 'traffic'),
            ('construction@dept.com', 'construction'),
        ]
        
        for email, dept_type in departments:
            user, created = User.objects.get_or_create(
                username=email,
                email=email
            )
            Department.objects.get_or_create(
                user=user,
                department_type=dept_type
            )
            if created:
                self.stdout.write(self.style.SUCCESS(f'Created {dept_type} department user: {email}'))
            else:
                self.stdout.write(self.style.WARNING(f'{dept_type} department user already exists: {email}'))
        
        self.stdout.write(self.style.SUCCESS('\nDepartment users ready!'))
        self.stdout.write('Login with these emails to access department dashboards:')
        self.stdout.write('- police@dept.com (Police Department)')
        self.stdout.write('- traffic@dept.com (Traffic Department)')
        self.stdout.write('- construction@dept.com (Construction Department)')
