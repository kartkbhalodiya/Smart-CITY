"""
WSGI config for smartcity project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/wsgi/
"""

import os
import sys
import traceback

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "smartcity.settings")

# Debug prints for Vercel logs
print(f"Python Version: {sys.version}", file=sys.stderr)
print(f"Working Directory: {os.getcwd()}", file=sys.stderr)
print(f"Settings Module: {os.environ.get('DJANGO_SETTINGS_MODULE')}", file=sys.stderr)

try:
    from django.core.wsgi import get_wsgi_application
    print("Attempting to get WSGI application...", file=sys.stderr)
    application = get_wsgi_application()
    print("WSGI application loaded successfully.", file=sys.stderr)
    app = application
except Exception as e:
    # Print full error to Vercel logs
    print("="*80, file=sys.stderr)
    print("WSGI INITIALIZATION ERROR:", file=sys.stderr)
    print("="*80, file=sys.stderr)
    print(f"Error: {e}", file=sys.stderr)
    print("\nFull traceback:", file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    print("="*80, file=sys.stderr)
    raise
