import sys

# Read the file
with open(r'c:\Users\bhalo\Documents\GitHub\Smart CITY\complaints\views.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove all literal `r`n sequences
content = content.replace('`r`n', '\n')
content = content.replace('`r', '')
content = content.replace('`n', '')

# Write the file back
with open(r'c:\Users\bhalo\Documents\GitHub\Smart CITY\complaints\views.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed literal escape sequences successfully!")
