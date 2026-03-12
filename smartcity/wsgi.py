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

try:
    from django.core.wsgi import get_wsgi_application
    application = get_wsgi_application()
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
