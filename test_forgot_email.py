import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from django.contrib.auth.models import User
from complaints.models import Department, DepartmentUser
from complaints.email_utils import send_password_reset_credentials_email

print("\n" + "="*60)
print("TESTING FORGOT PASSWORD EMAIL")
print("="*60)

# Get all departments
departments = Department.objects.all()
print(f"\nFound {departments.count()} departments:")

for dept in departments:
    print(f"\n--- Department: {dept.name} ---")
    print(f"  Department Email: {dept.email}")
    
    # Find associated user
    dept_user = DepartmentUser.objects.filter(department=dept).select_related('user').first()
    
    if dept_user:
        user = dept_user.user
        print(f"  User Email: {user.email}")
        print(f"  Username: {user.username}")
        
        # Test email sending
        print(f"\n  Testing email to: {dept.email}")
        
        try:
            result = send_password_reset_credentials_email(
                email=dept.email,
                user_name=user.get_full_name() or user.username,
                new_password="TestPassword123!",
                department=dept,
                city_admin_info=None
            )
            
            if result:
                print(f"  ✓ Email sent successfully!")
            else:
                print(f"  ✗ Email sending failed!")
                
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
            import traceback
            traceback.print_exc()
    else:
        print(f"  ✗ No user found for this department")

print("\n" + "="*60)
print("TEST COMPLETE")
print("="*60 + "\n")
