import socket
host = 'db.aaywhmjmsdkjzabtzfpg.supabase.co'
print(f"Checking resolution for: {host}")

try:
    info = socket.getaddrinfo(host, 5432)
    print(f"Default resolution: {info}")
except Exception as e:
    print(f"Default resolution failed: {e}")

try:
    info = socket.getaddrinfo(host, 5432, socket.AF_INET)
    print(f"IPv4 (AF_INET) resolution: {info}")
except Exception as e:
    print(f"IPv4 (AF_INET) resolution failed: {e}")
