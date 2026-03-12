import os
import psycopg2
import socket

# Apply the same patch as in settings.py
orig_getaddrinfo = socket.getaddrinfo
def patched_getaddrinfo(host, port, family=0, type=0, proto=0, flags=0):
    return orig_getaddrinfo(host, port, socket.AF_INET, type, proto, flags)
socket.getaddrinfo = patched_getaddrinfo

db_url = "postgres://postgres:Kartik%409089361130@db.aaywhmjmsdkjzabtzfpg.supabase.co:5432/postgres"
print(f"Testing original connection with IPv4 patch...")
try:
    conn = psycopg2.connect(db_url)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
