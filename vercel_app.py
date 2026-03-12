import os
import sys

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "smartcity.settings")

from django.core.wsgi import get_wsgi_application

try:
    application = get_wsgi_application()
    app = application
except Exception as e:
    import traceback
    traceback.print_exc()
    raise e
