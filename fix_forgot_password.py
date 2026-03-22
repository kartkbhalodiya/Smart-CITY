import re

# Read the file
with open(r'c:\Users\bhalo\Documents\GitHub\Smart CITY\complaints\views.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Add department email lookup
old_pattern1 = r'(# Check if email belongs to a department user or city admin\s+user = User\.objects\.filter\(email__iexact=email\)\.first\(\))'
new_text1 = '''# Check if email belongs to a department user or city admin
                # First try to find user by email
                user = User.objects.filter(email__iexact=email).first()
                
                # If not found, check if it's a department email
                if not user:
                    dept = Department.objects.filter(email__iexact=email).first()
                    if dept:
                        dept_user = DepartmentUser.objects.filter(department=dept).select_related('user').first()
                        if dept_user:
                            user = dept_user.user
                            print(f"[Forgot Password] Found user via department email: {dept.name}")'''

content = re.sub(old_pattern1, new_text1, content)

# Fix 2: Update department email sending logic
old_pattern2 = r'(print\(f"  - User Email: \{user\.email\}"\)\s+print\(f"\[Forgot Password\] Sending department reset email\.\.\."\)\s+# IMPORTANT: Send to user\'s email, not department email\s+try:\s+# DIRECT TEST:.*?traceback\.print_exc\(\))'

new_text2 = '''print(f"  - User Email: {user.email}")
                    print(f"[Forgot Password] Sending department reset email...")
                    
                    # Determine which email to send to
                    recipient_email = user.email
                    
                    # If user email is not set or is a placeholder, use department email
                    if not recipient_email or '@' not in recipient_email:
                        recipient_email = dept_user.department.email
                        print(f"[Forgot Password] Using department email as recipient: {recipient_email}")
                    else:
                        print(f"[Forgot Password] Using user email as recipient: {recipient_email}")
                    
                    # Send the password reset email
                    try:
                        email_result = send_password_reset_credentials_email(
                            email=recipient_email,
                            user_name=user_name,
                            new_password=new_password,
                            department=dept_user.department,
                            city_admin_info=None
                        )
                        print(f"[Forgot Password] Email function returned: {email_result}")
                    except Exception as email_error:
                        print(f"[Forgot Password] Email function exception: {str(email_error)}")
                        import traceback
                        traceback.print_exc()'''

content = re.sub(old_pattern2, new_text2, content, flags=re.DOTALL)

# Fix 3: Update city admin email sending logic
old_pattern3 = r'(elif city_admin:.*?# IMPORTANT: Send to user\'s email\s+try:\s+email_result = send_password_reset_credentials_email\(\s+email=)user\.email(,  # Use user\'s email)'

new_text3 = r'''elif city_admin:
                    print(f"  - City: {city_admin.city_name}, State: {city_admin.state}")
                    print(f"  - User Email: {user.email}")
                    print(f"[Forgot Password] Sending city admin reset email...")
                    
                    city_admin_info = {
                        'full_name': user_name,
                        'city': city_admin.city_name,
                        'state': city_admin.state,
                        'pincode': city_admin.pincode,
                        'contact_address': city_admin.contact_address
                    }
                    
                    # Determine recipient email
                    recipient_email = user.email if user.email and '@' in user.email else email
                    print(f"[Forgot Password] Sending to: {recipient_email}")
                    
                    # Send to user's email
                    try:
                        email_result = send_password_reset_credentials_email(
                            email=recipient_email\2'''

content = re.sub(old_pattern3, new_text3, content, flags=re.DOTALL)

# Write the file back
with open(r'c:\Users\bhalo\Documents\GitHub\Smart CITY\complaints\views.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed forgot password function successfully!")
