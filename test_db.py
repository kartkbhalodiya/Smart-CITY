import os
import psycopg2
from urllib.parse import urlparse
from dotenv import load_dotenv

load_dotenv()

db_url = os.getenv('DATABASE_URL')
print(f"Testing connection to: {urlparse(db_url).hostname}")

try:
    conn = psycopg2.connect(db_url)
    print("Successfully connected to the database!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
