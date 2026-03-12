import socket

# Get IPv4 address for Supabase host
host = "db.aaywhmjmsdkjzabtzfpg.supabase.co"

try:
    # Force IPv4 resolution
    ipv4_addresses = socket.getaddrinfo(host, None, socket.AF_INET)
    ipv4 = ipv4_addresses[0][4][0]
    print(f"\nIPv4 address for {host}: {ipv4}")
    print("\n" + "="*80)
    print("COPY THIS URL TO VERCEL ENVIRONMENT VARIABLES:")
    print("="*80)
    print(f"\npostgresql://postgres.aaywhmjmsdkjzabtzfpg:Kartik%409089361130@{ipv4}:6543/postgres?sslmode=require")
    print("\n" + "="*80)
except Exception as e:
    print(f"Error: {e}")
    print("\nAlternative: Use Supabase connection pooler with pgbouncer mode")
    print("="*80)
    print("COPY THIS URL TO VERCEL ENVIRONMENT VARIABLES:")
    print("="*80)
    print(f"\npostgresql://postgres.aaywhmjmsdkjzabtzfpg:Kartik%409089361130@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?sslmode=require")
    print("\n" + "="*80)
