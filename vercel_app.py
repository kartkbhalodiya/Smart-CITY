import os
import sys
import traceback

# Print debug info to Vercel logs
print(f"Python Version: {sys.version}", file=sys.stderr)
print(f"Current working directory: {os.getcwd()}", file=sys.stderr)

# Add current directory to path
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)
print(f"Added to path: {current_dir}", file=sys.stderr)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "smartcity.settings")

# Try to load application
try:
    print("Initializing Django...", file=sys.stderr)
    import django
    django.setup()
    
    print("Getting WSGI application...", file=sys.stderr)
    from django.core.wsgi import get_wsgi_application
    application = get_wsgi_application()
    app = application
    print("WSGI application initialized successfully.", file=sys.stderr)
except Exception as e:
    print("CRITICAL: Failed to initialize WSGI application!", file=sys.stderr)
    print("="*40, file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    print("="*40, file=sys.stderr)
    
    # Fallback to show error in browser for debugging
    def app(environ, start_response):
        status = '500 Internal Server Error'
        # TEMPORARILY show traceback even in production to find the cause
        output = f"<h1>Application Error (Diagnostic Mode)</h1><pre>{traceback.format_exc()}</pre>".encode('utf-8')
        response_headers = [('Content-type', 'text/html'), ('Content-Length', str(len(output)))]
        start_response(status, response_headers)
        return [output]
    application = app
