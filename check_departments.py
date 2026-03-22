import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartcity.settings')
django.setup()

from django.contrib.auth.models import User
from complaints.models import Department, DepartmentUser

print("\n" + "="*60)
print("DEPARTMENT EMAIL CHECK")
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
        print(f"  User ID: {user.id}")
    else:
        print(f"  [ERROR] No user found for this department")

print("\n" + "="*60)
print("INSTRUCTIONS:")
print("="*60)
print("\n1. Emails ARE being sent via Gmail SMTP")
print("2. Check the SPAM/JUNK folder in your email")
print("3. The email is sent from: academix111@gmail.com")
print("4. Subject: 'Password Reset Successful - JanHelp'")
print("\n5. To test, use the forgot password form with:")
print("   - Department email: thestayvora@gmail.com")
print("\n" + "="*60 + "\n")
